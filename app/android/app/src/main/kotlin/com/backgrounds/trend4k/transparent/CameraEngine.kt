package com.backgrounds.trend4k.transparent

import android.content.Context
import android.hardware.camera2.CaptureRequest
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.Range
import android.util.Size
import android.view.Surface
import androidx.annotation.OptIn
import androidx.camera.camera2.interop.Camera2Interop
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.AspectRatio
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import java.util.concurrent.Executor

/**
 * Wraps CameraX to stream the rear camera onto an arbitrary [Surface] — here,
 * the live-wallpaper engine's surface. Because a `WallpaperService.Engine` is
 * not a `LifecycleOwner`, this class supplies its own [LifecycleRegistry] and
 * drives it manually as the wallpaper becomes visible / hidden.
 *
 * ## Reverted: no GL/EGL compositing stage
 *
 * A previous version of this class routed frames through a hand-written
 * EGL/OpenGL renderer ([CameraSurfaceRenderer], now removed) to center-crop
 * the sensor buffer before handing it to the wallpaper surface - fixing the
 * stretch, but its EGL setup failed silently on some devices, leaving the
 * wallpaper on a disconnected dummy surface (a fully BLACK screen, reported
 * as streaming/RUNNING the whole time). A hard failure is strictly worse
 * than the original stretch it was fixing, so this reverts to feeding the
 * camera straight to the wallpaper's real [Surface] - the simple,
 * previously-working path with no extra pipeline stage that can fail
 * invisibly. [AspectRatioStrategy] below still asks the sensor for whichever
 * coarse ratio (4:3 or 16:9) is closer to the actual screen, which reduces -
 * without fully eliminating - the stretch, at zero additional failure risk.
 *
 * Errors (camera busy, disconnected, unavailable) are surfaced via [onError]
 * with a coarse code the controller maps to a user-facing state; the caller is
 * responsible for retry/recovery policy.
 */
class CameraEngine(
    private val context: Context,
    private val onError: (code: String, message: String) -> Unit,
    private val onStreaming: () -> Unit,
) : LifecycleOwner {

    private val lifecycleRegistry = LifecycleRegistry(this)
    private val mainExecutor: Executor =
        Executor { r -> Handler(Looper.getMainLooper()).post(r) }

    private var cameraProvider: ProcessCameraProvider? = null
    private var preview: Preview? = null
    private var started = false

    override val lifecycle: Lifecycle get() = lifecycleRegistry

    init {
        lifecycleRegistry.currentState = Lifecycle.State.INITIALIZED
    }

    /**
     * Binds the rear camera and renders frames to [surface]. [targetRotation] is
     * one of the `Surface.ROTATION_*` constants. [surfaceWidth]/[surfaceHeight]
     * are the wallpaper surface's own pixel dimensions (the full device
     * screen), used only to pick the closer of the two coarse aspect-ratio
     * buckets CameraX allows requesting (see [buildResolutionSelector]). No-op
     * if already streaming.
     */
    @OptIn(ExperimentalCamera2Interop::class)
    fun start(surface: Surface, targetRotation: Int, surfaceWidth: Int, surfaceHeight: Int) {
        if (started) {
            Log.d(TAG, "start() ignored — already started")
            return
        }
        // A released engine must never be reused (LifecycleRegistry cannot leave
        // DESTROYED). The service always creates a fresh engine per bind, but
        // guard defensively so a stale instance fails loudly instead of silently.
        if (lifecycleRegistry.currentState == Lifecycle.State.DESTROYED) {
            Log.e(TAG, "start() on a released engine — refusing")
            onError(ERROR_CAMERA_GENERIC, "camera engine already released")
            return
        }
        started = true
        lifecycleRegistry.currentState = Lifecycle.State.RESUMED
        Log.d(TAG, "start() — requesting ProcessCameraProvider")

        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            // The provider resolves asynchronously; if the engine was stopped or
            // released in the meantime (e.g. wallpaper hidden), abort — binding to
            // a destroyed lifecycle throws.
            if (!started || lifecycleRegistry.currentState == Lifecycle.State.DESTROYED) {
                Log.d(TAG, "provider ready but engine no longer active — skipping bind")
                return@addListener
            }
            try {
                val provider = future.get()
                cameraProvider = provider

                // Battery/perf: cap resolution (~720p is plenty behind icons) and
                // frame rate. Both keep GPU + camera power draw down for an
                // always-on wallpaper. FPS is user-tunable via prefs (Phase 16).
                val fps = readTargetFps()
                val resolutionSelector =
                    buildResolutionSelector(fps, surfaceWidth, surfaceHeight)

                val builder = Preview.Builder()
                    .setTargetRotation(targetRotation)
                    .setResolutionSelector(resolutionSelector)
                Camera2Interop.Extender(builder).setCaptureRequestOption(
                    CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE,
                    Range(fps, fps),
                )

                val previewUseCase = builder.build().also { p ->
                    p.setSurfaceProvider(mainExecutor) { request ->
                        // Feed camera frames straight to the wallpaper surface.
                        request.provideSurface(surface, mainExecutor) { /* released */ }
                    }
                }
                // Release only OUR previous use case, never `unbindAll()`:
                // the provider is a process-wide singleton shared with the
                // in-app preview PlatformView, and unbinding everything is what
                // used to leave one of the two consumers with a dead camera.
                preview?.let { stale -> runCatching { provider.unbind(stale) } }
                preview = previewUseCase

                provider.bindToLifecycle(
                    this,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    previewUseCase,
                )
                Log.d(TAG, "bindToLifecycle OK — camera streaming (fps=$fps)")
                onStreaming()
            } catch (e: Exception) {
                started = false
                Log.e(TAG, "camera bind failed: ${e.message}", e)
                onError(classify(e), e.message ?: "Camera error")
            }
        }, mainExecutor)
    }

    /**
     * Battery/perf resolution cap (~720p is plenty behind icons), scaled with
     * the chosen quality/FPS preset: Saver→480p, Balanced→720p, Smooth→1080p.
     *
     * [AspectRatioStrategy] only accepts the coarse [AspectRatio.RATIO_4_3] /
     * [AspectRatio.RATIO_16_9] buckets - never an arbitrary ratio like a
     * phone's actual ~9:19.5 screen - so this cannot make the feed match the
     * wallpaper surface exactly. Picking whichever bucket is numerically
     * closer to the surface's own ratio is still a real, zero-risk
     * improvement over always requesting 16:9 regardless of the device.
     */
    private fun buildResolutionSelector(
        fps: Int,
        surfaceWidth: Int,
        surfaceHeight: Int,
    ): ResolutionSelector {
        val targetHeight = when {
            fps >= 30 -> 1920
            fps >= 24 -> 1280
            else -> 854
        }
        val aspectRatio = closestCoarseAspectRatio(surfaceWidth, surfaceHeight)
        // CameraX resolution targets are conventionally expressed in
        // landscape (matching the original Size(1920, 1080)-style targets
        // this replaces) - targetHeight here is that primary/longer
        // dimension, same as before, just relabeled for this method's own
        // aspect-ratio math above.
        val targetShortEdge = if (aspectRatio == AspectRatio.RATIO_4_3) {
            (targetHeight * 3) / 4
        } else {
            (targetHeight * 9) / 16
        }
        return ResolutionSelector.Builder()
            .setAspectRatioStrategy(
                AspectRatioStrategy(aspectRatio, AspectRatioStrategy.FALLBACK_RULE_AUTO),
            )
            .setResolutionStrategy(
                ResolutionStrategy(
                    Size(targetHeight, targetShortEdge),
                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER,
                ),
            )
            .build()
    }

    /**
     * Whichever of 4:3 (1.333) or 16:9 (1.778) is numerically closer to the
     * surface's own long-edge-to-short-edge ratio. Falls back to 16:9 (the
     * previous fixed behavior) when dimensions are not yet known.
     */
    private fun closestCoarseAspectRatio(surfaceWidth: Int, surfaceHeight: Int): Int {
        if (surfaceWidth <= 0 || surfaceHeight <= 0) return AspectRatio.RATIO_16_9
        val long = maxOf(surfaceWidth, surfaceHeight).toFloat()
        val short = minOf(surfaceWidth, surfaceHeight).toFloat()
        val surfaceRatio = long / short
        val distanceTo43 = kotlin.math.abs(surfaceRatio - 4f / 3f)
        val distanceTo169 = kotlin.math.abs(surfaceRatio - 16f / 9f)
        return if (distanceTo43 < distanceTo169) AspectRatio.RATIO_4_3 else AspectRatio.RATIO_16_9
    }

    private fun readTargetFps(): Int {
        val prefs = context.getSharedPreferences("transparent_prefs", Context.MODE_PRIVATE)
        return prefs.getInt("tw_fps", DEFAULT_FPS).coerceIn(15, 30)
    }

    /** Unbinds the camera but keeps the engine reusable (e.g. wallpaper hidden). */
    fun stop() {
        started = false
        unbindOwnUseCase()
        preview = null
        if (lifecycleRegistry.currentState != Lifecycle.State.DESTROYED) {
            lifecycleRegistry.currentState = Lifecycle.State.CREATED
        }
        Log.d(TAG, "stop() — camera unbound")
    }

    /**
     * Releases only this engine's own camera binding, leaving any other consumer
     * of the process-wide provider (the in-app preview) untouched.
     */
    private fun unbindOwnUseCase() {
        val provider = cameraProvider ?: return
        val case = preview ?: return
        runCatching { provider.unbind(case) }
            .onFailure { Log.w(TAG, "unbind failed: ${it.message}") }
    }

    /** Permanent teardown; the instance must not be reused after this. */
    fun release() {
        started = false
        unbindOwnUseCase()
        preview = null
        cameraProvider = null // drop the singleton reference
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        Log.d(TAG, "release() — engine destroyed")
    }

    private fun classify(e: Exception): String {
        val msg = (e.message ?: "").lowercase()
        return when {
            msg.contains("in use") || msg.contains("camera_in_use") ||
                msg.contains("max_cameras_in_use") -> ERROR_CAMERA_BUSY
            msg.contains("disconnect") -> ERROR_CAMERA_LOST
            else -> ERROR_CAMERA_GENERIC
        }
    }

    companion object {
        const val ERROR_CAMERA_BUSY = "camera_busy"
        const val ERROR_CAMERA_LOST = "camera_lost"
        const val ERROR_CAMERA_GENERIC = "camera_error"
        private const val DEFAULT_FPS = 24
        private const val TAG = "TransparentCam"
    }
}
