package com.backgrounds.trend4k

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.service.wallpaper.WallpaperService
import android.util.Log
import android.view.Surface
import android.view.SurfaceHolder
import java.io.File

/**
 * Renders a looping video wallpaper (the backend's `video` type) by feeding a
 * [MediaPlayer] onto the wallpaper engine's surface.
 *
 * Two paths, chosen once per [startPlayback] by whether a clock is
 * configured:
 *  - **no clock** (the common case): `MediaPlayer.setSurface()` targets the
 *    wallpaper's real [Surface] directly - the simplest, cheapest possible
 *    path, unchanged from before clock support existed on this engine.
 *  - **clock configured**: `MediaPlayer.setSurface()` targets an offscreen
 *    [android.graphics.SurfaceTexture] instead, and [GLVideoClockCompositor]
 *    composites the decoded video frame plus a clock/date overlay (drawn by
 *    the shared [ClockRenderer], the exact same renderer the static/depth
 *    engine uses) onto the real wallpaper surface. Same single decode either
 *    way - the decoder never knows which Surface it's writing to.
 *
 * Uses only platform APIs - no extra dependency - and keeps the whole
 * pipeline native: Flutter downloads the file and hands over a path, and
 * never touches a frame.
 *
 * Lifecycle contract:
 *  - playback runs only while the wallpaper is **visible**, so a video
 *    wallpaper costs nothing while the screen is off or another app is
 *    foreground;
 *  - the player (and, when active, the compositor) is fully released on hide
 *    and rebuilt on show, because a MediaPlayer bound to a destroyed surface
 *    cannot be reused;
 *  - if the file is missing or undecodable the engine paints the poster (or a
 *    neutral fill) instead of leaving a black screen.
 */
class VideoWallpaperService : WallpaperService() {

    override fun onCreateEngine(): Engine = VideoEngine()

    inner class VideoEngine : Engine() {

        private var player: MediaPlayer? = null
        private var compositor: GLVideoClockCompositor? = null
        private val clockTickHandler = Handler(Looper.getMainLooper())
        private val clockTickRunnable = Runnable { onClockTick() }
        private var visible = false
        private var surfaceWidth = 0
        private var surfaceHeight = 0

        /** Identifies the video+clock config the CURRENTLY RUNNING [player]
         * was actually built from, so a later apply to a DIFFERENT wallpaper
         * - which only changes SharedPreferences, never recreates this
         * Engine instance or restarts this process - is detected and picked
         * up rather than left showing whatever was already playing. Android
         * reuses an already-alive Engine for the same wallpaper component
         * across most visibility transitions (going home, screen on/off,
         * launcher restart); without this check, [startPlayback] used to
         * bail out via a bare `if (player != null) return` and never
         * re-read prefs at all once any video was already playing - the
         * exact bug behind "apply a different live wallpaper and the OLD
         * one keeps showing until you leave and reopen the app." Mirrors
         * `LiveWallpaperService.loadAssets()`'s own `loadedSignature` guard
         * for the same reason on the static/depth engine. */
        private var loadedSignature: String? = null

        /** True from the moment [startPlayback] commits to (re)building a
         * player for [loadedSignature] until that attempt actually settles
         * (`player` gets set, or it falls back to the poster) - guards
         * against a SECOND `startPlayback()` call for the SAME signature
         * arriving before the first one has finished. This happens in
         * practice: the system picker can fire `onVisibilityChanged(true)`
         * twice in quick succession for one engine while the first call's
         * async GL-compositor handoff is still pending. Without this guard,
         * the second call sees `player == null` (not yet assigned - it is
         * only set inside the async callback) despite the signature already
         * matching, concludes a rebuild is needed, and calls
         * `stopPlayback()` - releasing the FIRST call's compositor/Surface
         * out from under its still-in-flight callback (confirmed via logcat:
         * "IllegalArgumentException: The surface has been released"). */
        private var startInProgress = false

        /// Observes the battery only while a video wallpaper that actually
        /// draws a ring is visible. Pushes the level straight into the
        /// compositor, which invalidates its overlay texture on a real change.
        private val battery =
            BatteryLevelObserver(this@VideoWallpaperService) { level ->
                compositor?.setBatteryLevel(level)
            }

        override fun onVisibilityChanged(visible: Boolean) {
            this.visible = visible
            if (visible) {
                startPlayback()
                syncBatteryObserver()
            } else {
                stopPlayback()
                // An off-screen wallpaper does no battery work at all.
                battery.stop()
            }
        }

        /**
         * Registers the battery receiver only when this wallpaper actually
         * draws a ring, and only while it is visible.
         */
        private fun syncBatteryObserver() {
            val needed = visible && currentWidgets().any {
                it is StudioWidgetConfig.BatteryRing
            }
            if (needed) {
                battery.start()
                compositor?.setBatteryLevel(battery.level)
            } else {
                battery.stop()
            }
        }

        private fun currentWidgets(): List<StudioWidgetConfig> =
            StudioWidgetConfig.listFromJson(prefs().getString(KEY_WIDGETS_JSON, null))

        private fun currentDateWidget(): StudioDateConfig? =
            StudioDateConfig.fromJson(prefs().getString(KEY_DATE_WIDGET_JSON, null))

        override fun onSurfaceCreated(holder: SurfaceHolder?) {
            super.onSurfaceCreated(holder)
            if (visible) startPlayback()
        }

        override fun onSurfaceChanged(holder: SurfaceHolder?, format: Int, w: Int, h: Int) {
            super.onSurfaceChanged(holder, format, w, h)
            surfaceWidth = w
            surfaceHeight = h
            compositor?.onOutputSizeChanged(w, h)
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder?) {
            // The player holds the surface; it must go before the surface does.
            stopPlayback()
            super.onSurfaceDestroyed(holder)
        }

        private fun prefs() = getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        private fun currentClockConfigJson(): String? = prefs().getString(KEY_CLOCK_CONFIG_JSON, null)

        private fun startPlayback() {
            val holder = surfaceHolder ?: return
            val surface = holder.surface
            if (surface == null || !surface.isValid) return

            val path = prefs().getString(KEY_VIDEO_PATH, null)
            val clockConfigJson = currentClockConfigJson()
            // Identifies exactly what should be playing right now - if this
            // still matches what [player] was actually built from, there is
            // nothing to do (this fires on every visibility-true/surface
            // event, not just a genuine wallpaper change). If it differs -
            // including "was playing wallpaper A, should now play wallpaper
            // B" - the current player (if any) must be torn down and a new
            // one started from the NEW path/config, never just left alone.
            val signature = "$path|$clockConfigJson"
            // Either nothing changed and a start already succeeded
            // (`player != null`), or nothing changed and a start for this
            // exact signature is already under way (`startInProgress`) - a
            // second concurrent attempt must not tear down the first one's
            // still-in-flight compositor/player.
            if (signature == loadedSignature && (player != null || startInProgress)) return
            loadedSignature = signature

            if (path.isNullOrEmpty() || !File(path).exists()) {
                Log.w(TAG, "no video file at $path - drawing poster")
                stopPlayback()
                drawPoster()
                return
            }

            // A genuinely different wallpaper (or a config change like
            // enabling/disabling the clock) needs a fresh player against
            // the new path - reusing the old one is not an option, and
            // `stopPlayback()` also tears down any active compositor so
            // `startWithClockOverlay` below starts from a clean state.
            stopPlayback()
            startInProgress = true

            val clockConfig = ClockConfig.fromJson(clockConfigJson)
            val hasClock = clockConfig.enabled && clockConfig.opacity > 0f

            var pendingMp: MediaPlayer? = null
            try {
                if (hasClock) {
                    startWithClockOverlay(surface, clockConfig, path)
                } else {
                    pendingMp = MediaPlayer()
                    pendingMp.setSurface(surface)
                    preparePlayer(pendingMp, path)
                    player = pendingMp
                    startInProgress = false
                }
            } catch (e: Exception) {
                Log.e(TAG, "failed to start video wallpaper: ${e.message}", e)
                startInProgress = false
                // `stopPlayback()` only releases `player` if this instance
                // ever got assigned to it - guarantee it either way, so a
                // MediaPlayer that fails before that assignment doesn't
                // leak its native decoder to non-deterministic GC
                // finalization (see the matching comment elsewhere in this
                // file for why that matters on this codec-memory-
                // constrained device).
                if (pendingMp != null && player !== pendingMp) {
                    runCatching { pendingMp.release() }
                }
                stopPlayback()
                drawPoster()
            }
        }

        /** Redirects decode output through [GLVideoClockCompositor] instead
         * of the real surface, so the clock can be composited on top - see
         * the class doc for why a direct `setSurface` cannot also carry an
         * overlay.
         *
         * Some GPU backends reject the compositor's offscreen Surface when
         * MediaPlayer actually attaches to it (confirmed on at least one
         * Android emulator's virtualized GL path); [GLVideoClockCompositor]
         * reports that failure via its `onFailed` callback rather than
         * leaving a MediaPlayer half-configured, so this falls back to the
         * plain direct-surface path - the video still plays, just without
         * the clock, rather than not playing at all.
         *
         * A MediaPlayer whose `setSurface()` call has already thrown once is
         * left in a broken internal state and cannot be reused for the
         * fallback attempt - [onFailed] therefore constructs a genuinely new
         * MediaPlayer rather than retrying the one [onVideoSurfaceReady] may
         * have already touched. Both callbacks are invoked BY the
         * compositor on its own GL thread, but immediately re-post their
         * real work onto [clockTickHandler] (this engine's main thread) -
         * so the actual MediaPlayer/surface handling below never runs on
         * the GL thread itself, and any exception it throws is caught here
         * explicitly rather than crashing this engine's main thread.
         *
         * A [fallbackWatchdog] backs the exception-based recovery above: on
         * this same emulator's GL backend, `MediaPlayer.setSurface()` has
         * been observed not just throwing quickly but genuinely HANGING
         * (confirmed via logcat: EGL/GL setup completed, but neither
         * [onVideoSurfaceReady] nor [onFailed] ever ran to completion,
         * leaving the wallpaper permanently black - most likely GPU-driver
         * contention with a just-torn-down compositor from the PREVIOUSLY
         * applied wallpaper on the same virtualized GL context). Since a
         * genuine hang cannot be caught by any try/catch, the watchdog is
         * the only thing that can recover from it: if neither callback has
         * fired within [fallbackWatchdogMs], it forces the same direct-
         * surface fallback [onFailed] would have used.
         */
        private fun startWithClockOverlay(
            outputSurface: Surface,
            clockConfig: ClockConfig,
            path: String,
        ) {
            val comp = GLVideoClockCompositor(this@VideoWallpaperService)
            compositor = comp
            comp.setClockConfig(clockConfig)
            comp.setWidgets(currentWidgets())
            comp.setDateWidget(currentDateWidget())
            comp.setBatteryLevel(battery.level)

            var settled = false
            val fallbackWatchdog = Runnable {
                // `compositor !== comp` means an external teardown (surface
                // destroyed, engine destroyed) already released this
                // attempt's compositor - possibly already starting its own
                // recovery - so this must not ALSO fall back and start a
                // second, competing player.
                if (settled || compositor !== comp) return@Runnable
                settled = true
                startInProgress = false
                Log.w(TAG, "GL clock compositor timed out - falling back to plain video, no clock overlay")
                comp.release()
                compositor = null
                fallBackToPlainVideo(path)
            }
            clockTickHandler.postDelayed(fallbackWatchdog, GL_COMPOSITOR_TIMEOUT_MS)

            comp.start(
                outputSurface,
                surfaceWidth,
                surfaceHeight,
                onVideoSurfaceReady = { videoInputSurface ->
                    clockTickHandler.post {
                        // Bail out entirely (not just skip bookkeeping) if
                        // either: the watchdog already fired (this callback
                        // arrived late, after a hang it gave up on), or
                        // `compositor` no longer IS this call's `comp` at
                        // all (an external teardown - e.g. the surface being
                        // destroyed - already released it and possibly
                        // started a different attempt). Either way, `comp`
                        // is no longer the current attempt, and touching
                        // `videoInputSurface`/`player` now would race or
                        // corrupt whatever IS current.
                        if (settled || compositor !== comp) return@post
                        settled = true
                        startInProgress = false
                        clockTickHandler.removeCallbacks(fallbackWatchdog)
                        var mp: MediaPlayer? = null
                        try {
                            mp = MediaPlayer()
                            mp.setSurface(videoInputSurface)
                            mp.setOnVideoSizeChangedListener { _, w, h -> comp.setVideoAspect(w, h) }
                            preparePlayer(mp, path)
                            player = mp
                        } catch (e: Exception) {
                            Log.e(TAG, "failed to start MediaPlayer onto GL compositor surface: ${e.message}", e)
                            // A MediaPlayer left to GC finalization (rather
                            // than an explicit release()) does not free its
                            // native decoder resources deterministically -
                            // confirmed via logcat on this exact emulator:
                            // repeated leaked instances exhausted the
                            // software decoder's memory pool, causing later
                            // playback attempts to fail with NO_MEMORY and
                            // silently retry-loop (visible as one frame
                            // rendering, then a permanently frozen video).
                            runCatching { mp?.release() }
                            compositor?.release()
                            compositor = null
                            drawPoster()
                        }
                    }
                },
                onFailed = {
                    clockTickHandler.post {
                        if (settled || compositor !== comp) return@post
                        settled = true
                        startInProgress = false
                        clockTickHandler.removeCallbacks(fallbackWatchdog)
                        Log.w(TAG, "GL clock compositor failed - falling back to plain video, no clock overlay")
                        compositor = null
                        fallBackToPlainVideo(path)
                    }
                },
            )
            // Advances the displayed time even between video frames (e.g. a
            // long/slow clip) - independent of decode rate, matching the
            // static/depth engine's own once-a-second `drawFrame` tick.
            clockTickHandler.removeCallbacks(clockTickRunnable)
            clockTickHandler.postDelayed(clockTickRunnable, 1000L)
        }

        /** Plain direct-surface playback, no clock - used both when no
         * clock is configured at all, and as the recovery path when the GL
         * compositor fails or hangs. Re-fetches the surface rather than
         * trusting a captured reference: a failed/hung `eglCreateWindowSurface`
         * attempt against a Surface can leave its buffer queue unable to
         * accept a fresh producer attach even after GL gives up on it, and
         * the surface may genuinely have been recreated by the time this
         * runs. `holder.surface` is the OS's own source of truth for "the
         * surface to draw on right now." */
        private fun fallBackToPlainVideo(path: String) {
            val freshSurface = surfaceHolder?.surface
            if (freshSurface == null || !freshSurface.isValid) {
                Log.w(TAG, "no valid surface to fall back to")
                return
            }
            var mp: MediaPlayer? = null
            try {
                mp = MediaPlayer()
                mp.setSurface(freshSurface)
                preparePlayer(mp, path)
                player = mp
            } catch (e: Exception) {
                Log.e(TAG, "fallback plain video also failed: ${e.message}", e)
                // See the matching comment in startWithClockOverlay's
                // onVideoSurfaceReady handler - an unreleased MediaPlayer
                // only frees its native decoder on GC finalization, not
                // deterministically, which starves later attempts.
                runCatching { mp?.release() }
                drawPoster()
            }
        }

        private fun onClockTick() {
            val comp = compositor ?: return
            comp.setClockConfig(ClockConfig.fromJson(currentClockConfigJson()))
            comp.setWidgets(currentWidgets())
            comp.setDateWidget(currentDateWidget())
            comp.onClockTick()
            if (visible) clockTickHandler.postDelayed(clockTickRunnable, 1000L)
        }

        private fun preparePlayer(mp: MediaPlayer, path: String) {
            mp.apply {
                setDataSource(path)
                isLooping = true
                // A wallpaper is decoration, never audio: muting also keeps
                // it from stealing audio focus from music or calls.
                setVolume(0f, 0f)
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error what=$what extra=$extra")
                    // Returning true marks the error handled; tear the
                    // player down and show the poster rather than looping
                    // an error state forever.
                    stopPlayback()
                    drawPoster()
                    true
                }
                setOnPreparedListener { it.start() }
                prepareAsync()
            }
        }

        private fun stopPlayback() {
            clockTickHandler.removeCallbacks(clockTickRunnable)
            // A genuine external teardown (surface destroyed, engine
            // destroyed, a MediaPlayer error) must not leave a start
            // permanently "in progress" with nothing left to ever clear it -
            // `startPlayback()`'s own internal call to this method (right
            // before it commits to a fresh attempt) immediately sets this
            // back to true afterward, so resetting it here is always safe.
            startInProgress = false
            val current = player
            player = null
            if (current != null) {
                runCatching { if (current.isPlaying) current.stop() }
                runCatching { current.reset() }
                runCatching { current.release() }
            }
            compositor?.release()
            compositor = null
        }

        /**
         * Paints the still poster (or a neutral fill) when the video cannot
         * play. Never leaves the home screen black, which users read as a
         * crash.
         */
        private fun drawPoster() {
            val holder = surfaceHolder ?: return
            var canvas: Canvas? = null
            try {
                canvas = holder.lockCanvas() ?: return
                canvas.drawColor(Color.BLACK)
                val posterPath = prefs().getString(KEY_POSTER_PATH, null)
                val poster = posterPath?.let {
                    runCatching { BitmapFactory.decodeFile(it) }.getOrNull()
                }
                if (poster != null) {
                    DepthCompositor.drawCoverBitmap(
                        canvas, poster, canvas.width, canvas.height,
                        Paint(Paint.FILTER_BITMAP_FLAG),
                    )
                    poster.recycle()
                }
            } catch (e: Exception) {
                // Surface may be transitioning; the next visibility change retries.
            } finally {
                if (canvas != null) runCatching { holder.unlockCanvasAndPost(canvas) }
            }
        }

        override fun onDestroy() {
            stopPlayback()
            battery.stop()
            super.onDestroy()
        }
    }

    companion object {
        private const val TAG = "VideoWallpaper"
        const val PREFS = "clock_prefs"
        const val KEY_VIDEO_PATH = "live_video_path"
        const val KEY_POSTER_PATH = "live_video_poster_path"
        const val KEY_CLOCK_CONFIG_JSON = "live_video_clock_config_json"

        /** Serialized `studio.widgets` array for the video path. */
        const val KEY_WIDGETS_JSON = "live_video_widgets_json"

        /** Serialized `studio.dateWidget` for the video path. */
        const val KEY_DATE_WIDGET_JSON = "live_video_date_widget_json"

        /** Generous but bounded: real EGL/GL setup plus a MediaPlayer
         * `setSurface()`/`prepareAsync()` call normally completes in well
         * under a second; this only exists to recover from a genuine
         * driver-level hang (observed on at least one emulator GL backend),
         * not to accommodate normal slowness, so it can afford to be well
         * above the happy-path latency without meaningfully delaying the
         * one rare case it exists for. */
        private const val GL_COMPOSITOR_TIMEOUT_MS = 3000L
    }
}
