package com.creative.backgrounds.transparent

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
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
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
     * one of the `Surface.ROTATION_*` constants. No-op if already streaming.
     */
    @OptIn(ExperimentalCamera2Interop::class)
    fun start(surface: Surface, targetRotation: Int) {
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
                // Always clear any binding left by a previous session/engine
                // before we rebind — the provider is a process-wide singleton.
                provider.unbindAll()

                // Battery/perf: cap resolution (~720p is plenty behind icons) and
                // frame rate. Both keep GPU + camera power draw down for an
                // always-on wallpaper. FPS is user-tunable via prefs (Phase 16).
                val fps = readTargetFps()
                // Resolution scales with the chosen quality/FPS preset to keep
                // battery use proportional: Saver→480p, Balanced→720p, Smooth→1080p.
                val targetSize = when {
                    fps >= 30 -> Size(1920, 1080)
                    fps >= 24 -> Size(1280, 720)
                    else -> Size(854, 480)
                }
                val resolutionSelector = ResolutionSelector.Builder()
                    .setResolutionStrategy(
                        ResolutionStrategy(
                            targetSize,
                            ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER,
                        ),
                    )
                    .build()

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
                preview = previewUseCase

                provider.unbindAll()
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

    private fun readTargetFps(): Int {
        val prefs = context.getSharedPreferences("transparent_prefs", Context.MODE_PRIVATE)
        return prefs.getInt("tw_fps", DEFAULT_FPS).coerceIn(15, 30)
    }

    /** Unbinds the camera but keeps the engine reusable (e.g. wallpaper hidden). */
    fun stop() {
        started = false
        // Always unbind — the ProcessCameraProvider is a process-wide singleton;
        // skipping this (even when not "started") can leave a stale binding that
        // breaks the next Enable. Runs regardless of prior state.
        runCatching { cameraProvider?.unbindAll() }
            .onFailure { Log.w(TAG, "unbindAll on stop failed: ${it.message}") }
        preview = null
        if (lifecycleRegistry.currentState != Lifecycle.State.DESTROYED) {
            lifecycleRegistry.currentState = Lifecycle.State.CREATED
        }
        Log.d(TAG, "stop() — camera unbound")
    }

    /** Permanent teardown; the instance must not be reused after this. */
    fun release() {
        started = false
        runCatching { cameraProvider?.unbindAll() }
            .onFailure { Log.w(TAG, "unbindAll on release failed: ${it.message}") }
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
