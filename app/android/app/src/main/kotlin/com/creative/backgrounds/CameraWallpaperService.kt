package com.creative.backgrounds

import android.graphics.Color
import android.graphics.Paint
import android.os.Handler
import android.os.Looper
import android.service.wallpaper.WallpaperService
import android.util.Log
import android.view.Surface
import android.view.SurfaceHolder
import com.creative.backgrounds.transparent.CameraEngine
import com.creative.backgrounds.transparent.TransparentWallpaperManager

/**
 * Live wallpaper that renders the rear camera feed onto its surface, producing
 * the "transparent phone" effect (icons float over the live camera).
 *
 * Lifecycle contract:
 *  - Camera is bound only while the wallpaper is **visible** and the feature is
 *    enabled — never while hidden — to respect battery and background policy.
 *  - CameraX owns the surface while streaming; when stopped/disabled we draw a
 *    neutral placeholder ourselves.
 *  - All camera errors flow to [TransparentWallpaperManager] as observable state
 *    (Phase 13 adds retry policy); the engine never crashes the wallpaper host.
 */
class CameraWallpaperService : WallpaperService() {

    override fun onCreateEngine(): Engine = CameraWallpaperEngine()

    inner class CameraWallpaperEngine : Engine() {

        private var cameraEngine: CameraEngine? = null
        private var visible = false
        private var streaming = false

        // Recovery: bounded exponential backoff for transient camera failures
        // (busy / lost / crash). Reset on success or when the user returns.
        private val retryHandler = Handler(Looper.getMainLooper())
        private var retryCount = 0
        private val retryRunnable = Runnable { startIfReady() }

        override fun onVisibilityChanged(visible: Boolean) {
            this.visible = visible
            Log.d(TAG, "onVisibilityChanged=$visible isPreview=$isPreview")
            if (visible) {
                retryCount = 0 // fresh attempt each time the home screen appears
                startIfReady()
            } else {
                stopCamera()
            }
        }

        override fun onSurfaceChanged(
            holder: SurfaceHolder?,
            format: Int,
            width: Int,
            height: Int,
        ) {
            super.onSurfaceChanged(holder, format, width, height)
            if (visible) startIfReady()
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder?) {
            super.onSurfaceDestroyed(holder)
            stopCamera()
        }

        private fun startIfReady() {
            if (!TransparentWallpaperManager.isEnabled(applicationContext)) {
                Log.d(TAG, "startIfReady — feature disabled, drawing placeholder")
                drawPlaceholder()
                return
            }
            val surface: Surface? = surfaceHolder?.surface
            if (surface == null || !surface.isValid) {
                Log.d(TAG, "startIfReady — surface not ready")
                return
            }

            // Ensure the camera foreground service is running before we bind the
            // camera. The Activity starts it during Apply, but if the process was
            // killed and the wallpaper engine recreated (common on aggressive
            // OEMs), it must be re-established here or background camera access is
            // denied. Guarded: starting an FGS from the background throws on
            // Android 12+, which is a no-op fallback here.
            val fgs = runCatching { CameraForegroundService.start(applicationContext) }
            Log.d(TAG, "startIfReady — FGS start ${if (fgs.isSuccess) "ok" else "FAILED: ${fgs.exceptionOrNull()?.message}"}")

            // Always bind through a FRESH engine — never reuse one across a
            // hide/show or a disable/enable cycle, so the second Enable follows
            // exactly the same path as the first. stopCamera() releases + nulls it.
            val engine = cameraEngine ?: CameraEngine(
                context = applicationContext,
                onError = { code, message -> handleCameraError(code, message) },
                onStreaming = {
                    streaming = true
                    retryCount = 0 // recovered / succeeded
                    retryHandler.removeCallbacks(retryRunnable)
                    Log.d(TAG, "onStreaming — RUNNING")
                    TransparentWallpaperManager.updateState(
                        TransparentWallpaperManager.State.RUNNING,
                    )
                },
            ).also { cameraEngine = it }

            Log.d(TAG, "startIfReady — binding camera")
            engine.start(surface, Surface.ROTATION_0)
        }

        private fun stopCamera() {
            streaming = false
            retryHandler.removeCallbacks(retryRunnable)
            // Fully release + drop the engine so the next start is a clean, fresh
            // initialization (no reused CameraX lifecycle/provider binding).
            cameraEngine?.release()
            cameraEngine = null
            Log.d(TAG, "stopCamera — engine released")
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
         * Retries binding the camera with exponential backoff (2s, 4s, 8s…),
         * capped, while still visible + enabled. Recovers from transient
         * failures (another app briefly held the camera, a disconnect, etc.)
         * without user intervention and without spinning the CPU/battery.
         */
        private fun scheduleRetry() {
            if (!visible || !TransparentWallpaperManager.isEnabled(applicationContext)) {
                return
            }
            if (retryCount >= MAX_RETRIES) return
            val delay = RETRY_BASE_MS shl retryCount // 2s, 4s, 8s, 16s
            retryCount++
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
                // subtle centered dot so a black home screen isn't mistaken for a crash
                canvas.drawCircle(
                    canvas.width / 2f,
                    canvas.height / 2f,
                    8f,
                    paint,
                )
            } catch (e: Exception) {
                // ignore — surface may be transitioning
            } finally {
                if (canvas != null) {
                    runCatching { holder.unlockCanvasAndPost(canvas) }
                }
            }
        }

        override fun onDestroy() {
            Log.d(TAG, "engine onDestroy (isPreview=$isPreview enabled=${TransparentWallpaperManager.isEnabled(applicationContext)})")
            retryHandler.removeCallbacks(retryRunnable)
            cameraEngine?.release()
            cameraEngine = null
            // Only the REAL wallpaper engine (not the picker's preview engine)
            // being destroyed while still enabled means the wallpaper was replaced
            // from outside the app. The picker constantly creates/destroys PREVIEW
            // engines as a normal part of applying — treating those as "removed"
            // would wrongly disable the feature right before the real engine binds.
            if (!isPreview && TransparentWallpaperManager.isEnabled(applicationContext)) {
                TransparentWallpaperManager.handleWallpaperRemoved(applicationContext)
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
