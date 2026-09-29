package com.backgrounds.trend4k

import android.graphics.Color
import android.graphics.Paint
import android.os.Handler
import android.os.Looper
import android.service.wallpaper.WallpaperService
import android.util.Log
import android.view.Surface
import android.view.SurfaceHolder
import com.backgrounds.trend4k.transparent.CameraEngine
import com.backgrounds.trend4k.transparent.CompatibilityChecker
import com.backgrounds.trend4k.transparent.TransparentWallpaperManager

/**
 * Live wallpaper that renders the rear camera feed onto its surface, producing
 * the "transparent phone" effect (icons float over the live camera).
 *
 * ## Preview engines are not real engines
 *
 * The system wallpaper picker creates and destroys **preview** engines
 * constantly while the user browses and confirms - that is normal, and it is
 * the single most important distinction in this class. Only a real
 * (`!isPreview`) engine represents the wallpaper actually being set, so only
 * real engines are registered with [TransparentWallpaperManager], and only
 * their destruction can ever lead to the feature being disabled.
 *
 * Even then the manager does not disable anything directly: it schedules a
 * check and confirms against `WallpaperManager.getWallpaperInfo()`, because an
 * engine is destroyed for many benign reasons (rotation, configuration change,
 * surface recreation, launcher restart, re-applying the same wallpaper).
 *
 * ## Lifecycle contract
 *  - the camera is bound only while the wallpaper is **visible**, never while
 *    hidden, to respect battery and background policy;
 *  - CameraX owns the surface while streaming; otherwise a neutral placeholder
 *    is drawn, so the home screen is never mistakenly black;
 *  - every camera error becomes observable state on the manager; the engine
 *    never crashes the wallpaper host.
 */
class CameraWallpaperService : WallpaperService() {

    override fun onCreateEngine(): Engine = CameraWallpaperEngine()

    inner class CameraWallpaperEngine : Engine() {

        private var cameraEngine: CameraEngine? = null
        private var visible = false
        private var streaming = false
        private var surfaceWidth = 0
        private var surfaceHeight = 0

        /// Whether this engine registered itself as a real one. Captured at
        /// creation because `isPreview` must be read consistently for the
        /// create/destroy pair - registering on one and not the other would
        /// corrupt the live-engine count.
        private var registeredAsReal = false

        // Recovery: bounded exponential backoff for transient camera failures
        // (busy / lost / crash). Reset on success or when the user returns.
        private val retryHandler = Handler(Looper.getMainLooper())
        private var retryCount = 0
        private val retryRunnable = Runnable { startIfReady() }

        override fun onCreate(surfaceHolder: SurfaceHolder?) {
            super.onCreate(surfaceHolder)
            registeredAsReal = !isPreview
            Log.d(TAG, "engine onCreate (isPreview=$isPreview)")
            if (registeredAsReal) {
                TransparentWallpaperManager.onRealEngineCreated(applicationContext)
            }
        }

        override fun onVisibilityChanged(visible: Boolean) {
            this.visible = visible
            Log.d(TAG, "onVisibilityChanged=$visible isPreview=$isPreview")
            if (visible) {
                retryCount = 0 // fresh attempt each time the home screen appears
                startIfReady()
            } else {
                stopCamera()
                // Hidden is not stopped: the wallpaper is still ours, it just
                // is not on screen. Report PAUSED so the UI does not claim the
                // feature died every time the screen turns off.
                if (registeredAsReal && streaming) {
                    TransparentWallpaperManager.pause()
                }
            }
        }

        override fun onSurfaceCreated(holder: SurfaceHolder?) {
            super.onSurfaceCreated(holder)
            // onSurfaceChanged is guaranteed to follow before the surface is
            // actually usable, but read the holder's current frame defensively
            // so a same-tick startIfReady() below never binds the camera with
            // stale 0x0 dimensions (see buildResolutionSelector's zero-guard).
            holder?.surfaceFrame?.let {
                if (it.width() > 0 && it.height() > 0) {
                    surfaceWidth = it.width()
                    surfaceHeight = it.height()
                }
            }
            // A surface can arrive after the visibility callback; without this
            // the very first bind can be missed and the wallpaper stays blank.
            if (visible) startIfReady()
        }

        override fun onSurfaceChanged(
            holder: SurfaceHolder?,
            format: Int,
            width: Int,
            height: Int,
        ) {
            super.onSurfaceChanged(holder, format, width, height)
            surfaceWidth = width
            surfaceHeight = height
            if (visible) startIfReady()
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder?) {
            super.onSurfaceDestroyed(holder)
            stopCamera()
        }

        private fun startIfReady() {
            // `shouldRunCamera` is true for the pending-apply window too, so the
            // picker's preview shows a live feed - that is what the user is
            // being asked to approve.
            if (!TransparentWallpaperManager.shouldRunCamera(applicationContext)) {
                Log.d(TAG, "startIfReady - feature not active, drawing placeholder")
                drawPlaceholder()
                return
            }
            val surface: Surface? = surfaceHolder?.surface
            if (surface == null || !surface.isValid) {
                Log.d(TAG, "startIfReady - surface not ready")
                return
            }
            if (cameraEngine != null && streaming) return

            // Ensure the camera foreground service is running before binding.
            // The Activity starts it during Apply, but if the process was killed
            // and the engine recreated (common on aggressive OEMs) it must be
            // re-established here or background camera access is denied.
            // Starting an FGS from the background throws on Android 12+, which
            // is why this is guarded rather than assumed.
            val fgs = runCatching { CameraForegroundService.start(applicationContext) }
            if (fgs.isFailure) {
                Log.w(TAG, "FGS start failed: ${fgs.exceptionOrNull()?.message}")
            }

            // Always bind through a FRESH engine - never reuse one across a
            // hide/show or a disable/enable cycle, so the second Enable follows
            // exactly the same path as the first. stopCamera() releases + nulls it.
            val engine = cameraEngine ?: CameraEngine(
                context = applicationContext,
                onError = { code, message -> handleCameraError(code, message) },
                onStreaming = {
                    streaming = true
                    retryCount = 0 // recovered / succeeded
                    retryHandler.removeCallbacks(retryRunnable)
                    Log.d(TAG, "onStreaming - RUNNING")
                    // Frames flowing from a REAL engine is proof this device
                    // allows the camera behind the launcher - the one
                    // compatibility question no API can answer up front.
                    if (registeredAsReal) {
                        CompatibilityChecker.recordRuntimeOutcome(
                            applicationContext, true,
                        )
                    }
                    TransparentWallpaperManager.updateState(
                        TransparentWallpaperManager.State.RUNNING,
                    )
                },
            ).also { cameraEngine = it }

            Log.d(TAG, "startIfReady - binding camera")
            engine.start(surface, Surface.ROTATION_0, surfaceWidth, surfaceHeight)
        }

        private fun stopCamera() {
            streaming = false
            retryHandler.removeCallbacks(retryRunnable)
            // Fully release + drop the engine so the next start is a clean, fresh
            // initialization (no reused CameraX lifecycle/provider binding).
            cameraEngine?.release()
            cameraEngine = null
            Log.d(TAG, "stopCamera - engine released")
        }

        private fun handleCameraError(code: String, message: String) {
            streaming = false
            val state = when (code) {
                CameraEngine.ERROR_CAMERA_BUSY ->
                    TransparentWallpaperManager.State.CAMERA_BUSY
                CameraEngine.ERROR_CAMERA_LOST ->
                    TransparentWallpaperManager.State.CAMERA_LOST
                else -> TransparentWallpaperManager.State.ERROR
            }
            TransparentWallpaperManager.updateState(state, message)
            drawPlaceholder()
            scheduleRetry()
        }

        /**
         * Retries binding the camera with exponential backoff (2s, 4s, 8s...),
         * capped, while still visible and active. Recovers from transient
         * failures - another app briefly held the camera, a disconnect - without
         * user intervention and without spinning the CPU.
         *
         * When the budget is exhausted the feature settles in ERROR rather than
         * retrying forever, so the UI always reaches a state the user can act on.
         */
        private fun scheduleRetry() {
            if (!visible ||
                !TransparentWallpaperManager.shouldRunCamera(applicationContext)
            ) {
                return
            }
            if (retryCount >= MAX_RETRIES) {
                // Exhausted every retry while we were the live wallpaper: this
                // device does block background camera access. Record it so the
                // compatibility report stops guessing and states the fact.
                if (registeredAsReal) {
                    CompatibilityChecker.recordRuntimeOutcome(
                        applicationContext, false,
                    )
                }
                TransparentWallpaperManager.updateState(
                    TransparentWallpaperManager.State.ERROR,
                    "The camera could not be started after several attempts. " +
                        "Close any other app using the camera and try again.",
                )
                return
            }
            val delay = RETRY_BASE_MS shl retryCount // 2s, 4s, 8s, 16s
            retryCount++
            TransparentWallpaperManager.updateState(
                TransparentWallpaperManager.State.RECOVERING,
            )
            retryHandler.removeCallbacks(retryRunnable)
            retryHandler.postDelayed(retryRunnable, delay)
        }

        /** Draws a neutral fill when the camera is not (yet) streaming. */
        private fun drawPlaceholder() {
            if (streaming) return
            val holder = surfaceHolder ?: return
            var canvas: android.graphics.Canvas? = null
            try {
                canvas = holder.lockCanvas() ?: return
                canvas.drawColor(Color.BLACK)
                val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.DKGRAY
                }
                // Subtle centred dot, so a black home screen is not mistaken
                // for a crash.
                canvas.drawCircle(canvas.width / 2f, canvas.height / 2f, 8f, paint)
            } catch (e: Exception) {
                // Ignore - the surface may be transitioning.
            } finally {
                if (canvas != null) {
                    runCatching { holder.unlockCanvasAndPost(canvas) }
                }
            }
        }

        override fun onDestroy() {
            Log.d(TAG, "engine onDestroy (isPreview=$isPreview real=$registeredAsReal)")
            retryHandler.removeCallbacks(retryRunnable)
            cameraEngine?.release()
            cameraEngine = null
            streaming = false

            // Only a real engine's death is even a candidate for "the wallpaper
            // was removed" - and the manager still verifies against the system
            // before acting. The picker destroys preview engines as a matter of
            // course while applying; treating that as removal is exactly the bug
            // that broke Enable -> Disable -> Enable.
            if (registeredAsReal) {
                TransparentWallpaperManager.onRealEngineDestroyed(applicationContext)
            }
            super.onDestroy()
        }
    }

    companion object {
        private const val MAX_RETRIES = 4
        private const val RETRY_BASE_MS = 2000L // 2s, 4s, 8s, 16s
        private const val TAG = "TransparentCam"
    }
}
