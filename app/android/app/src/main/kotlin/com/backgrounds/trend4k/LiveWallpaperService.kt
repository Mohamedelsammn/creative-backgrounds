package com.backgrounds.trend4k

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.service.wallpaper.WallpaperService
import android.util.DisplayMetrics
import android.view.SurfaceHolder
import android.view.WindowManager
import java.util.Calendar

/**
 * Renders the clock/depth wallpaper.
 *
 * Draws background -> clock -> foreground each tick (1 Hz) and pauses when not
 * visible to save battery. The foreground transform and the background blur
 * come from the backend's `depthConfig`; the blur is applied once at load time
 * rather than per frame.
 */
class LiveWallpaperService : WallpaperService() {

    override fun onCreateEngine(): Engine = ClockEngine()

    inner class ClockEngine : Engine() {
        private val handler = Handler(Looper.getMainLooper())
        private val renderer = ClockRenderer(this@LiveWallpaperService)
        private val ringRenderer = BatteryRingRenderer(this@LiveWallpaperService)
        private val dateRenderer = StudioDateRenderer(this@LiveWallpaperService)
        private val bitmapPaint = Paint(Paint.FILTER_BITMAP_FLAG)

        /// Authored studio widgets (currently only `batteryRing`). Re-read with
        /// the rest of the config, so applying a different wallpaper swaps them.
        private var widgets: List<StudioWidgetConfig> = emptyList()

        /// The independently-positioned date element, distinct from the
        /// clock's own nested date.
        private var dateWidget: StudioDateConfig? = null

        /// Observes the battery only while a wallpaper that actually draws a
        /// ring is visible - see [syncBatteryObserver].
        private val battery =
            BatteryLevelObserver(this@LiveWallpaperService) {
                if (visible) drawFrame()
            }

        private var background: Bitmap? = null
        private var foreground: Bitmap? = null
        private var depthConfig: DepthConfig = DepthConfig.DEFAULTS
        private var width = 0
        private var height = 0
        private var visible = false

        /// Identifies the asset set currently decoded, so a visibility change
        /// does not needlessly re-decode the same bitmaps every time.
        private var loadedSignature: String? = null

        private val drawRunnable = Runnable { drawFrame() }

        override fun onCreate(surfaceHolder: SurfaceHolder?) {
            super.onCreate(surfaceHolder)
            loadAssets()
        }

        override fun onSurfaceChanged(holder: SurfaceHolder?, format: Int, w: Int, h: Int) {
            super.onSurfaceChanged(holder, format, w, h)
            width = w
            height = h
            drawFrame()
        }

        override fun onVisibilityChanged(visible: Boolean) {
            this.visible = visible
            if (visible) {
                loadAssets() // pick up any config/image change
                syncBatteryObserver()
                drawFrame()
            } else {
                handler.removeCallbacks(drawRunnable)
                // An off-screen wallpaper does no battery work at all.
                battery.stop()
            }
        }

        /**
         * Registers the battery receiver only when this wallpaper actually
         * draws a ring, and only while it is visible. A wallpaper with no
         * `batteryRing` never observes the battery.
         */
        private fun syncBatteryObserver() {
            val needed = visible && widgets.any {
                it is StudioWidgetConfig.BatteryRing
            }
            if (needed) battery.start() else battery.stop()
        }

        private fun prefs() = getSharedPreferences("clock_prefs", Context.MODE_PRIVATE)

        private fun loadAssets() {
            val prefs = prefs()
            val bgPath = prefs.getString("live_bg_path", null)
            val depthEnabled = prefs.getBoolean("live_depth_enabled", false)
            val maskPath = prefs.getString("live_mask_path", null)
            val depthJson = prefs.getString("depth_config_json", null)

            // Read OUTSIDE the asset-signature guard below: applying a
            // different design can change the widgets while leaving the
            // background/foreground bitmaps identical, and the guard would
            // skip the update entirely.
            widgets = StudioWidgetConfig.listFromJson(
                prefs.getString(KEY_WIDGETS_JSON, null),
            )
            dateWidget = StudioDateConfig.fromJson(
                prefs.getString(KEY_DATE_WIDGET_JSON, null),
            )

            // Re-decoding two full-screen bitmaps on every unlock is the single
            // most expensive thing this engine can do. Skip it when nothing
            // about the asset set has changed.
            val signature = "$bgPath|$maskPath|$depthEnabled|$depthJson"
            if (signature == loadedSignature && background != null) return
            loadedSignature = signature

            depthConfig = DepthConfig.fromJson(depthJson)

            background?.recycle()
            val decoded = bgPath?.let { runCatching { BitmapFactory.decodeFile(it) }.getOrNull() }
            background = if (decoded != null && depthConfig.blurRadius > 0f) {
                val blurred = DepthCompositor.blurredBackground(decoded, depthConfig.blurRadius)
                if (blurred !== decoded) decoded.recycle()
                blurred
            } else {
                decoded
            }

            foreground?.recycle()
            foreground = if (depthEnabled && maskPath != null) {
                runCatching { BitmapFactory.decodeFile(maskPath) }.getOrNull()
            } else {
                null
            }
        }

        private fun currentConfig(): ClockConfig =
            ClockConfig.fromJson(prefs().getString("clock_config_json", null))

        /**
         * The one screen-sized rect, centred in the (possibly wider) wallpaper
         * surface, that the user actually sees on a home-screen page.
         *
         * A launcher may allocate a surface wider than the display to pan for
         * parallax. Composing against the full surface is what made the depth
         * wallpaper look horizontally zoomed/cropped once applied: a 9:16
         * source scaled to cover a near-square 2340x2340 surface has to lose
         * most of its width. Falls back to the whole surface whenever it is
         * not actually wider/taller than the display, so a launcher that asks
         * for exactly screen size behaves exactly as before.
         */
        private fun visibleViewport(): Rect {
            if (width <= 0 || height <= 0) return Rect(0, 0, width, height)
            // REAL metrics (system bars included): a wallpaper is drawn behind
            // the bars, so the app-window size `resources.displayMetrics`
            // reports would make the viewport shorter than what is actually
            // visible and push the composition off-centre vertically.
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager)
                .defaultDisplay.getRealMetrics(metrics)
            val screenW = metrics.widthPixels.coerceAtLeast(1)
            val screenH = metrics.heightPixels.coerceAtLeast(1)
            val viewW = minOf(width, screenW)
            val viewH = minOf(height, screenH)
            val left = (width - viewW) / 2
            val top = (height - viewH) / 2
            return Rect(left, top, left + viewW, top + viewH)
        }

        private fun drawFrame() {
            val holder = surfaceHolder
            var canvas: Canvas? = null
            try {
                canvas = holder.lockCanvas() ?: return
                canvas.drawColor(Color.BLACK)

                // The surface a launcher hands a live wallpaper is frequently
                // WIDER than the screen, so it can pan the wallpaper for
                // parallax across its home-screen pages (on the tested device
                // the surface is 2340 wide against a 1080-wide display).
                // Everything below is therefore composed against the VISIBLE
                // viewport - one screen-sized rect centred in that surface -
                // not against the full surface:
                //
                //  * the background fits the viewport, so the composition the
                //    backend authored is fully visible on the page the user is
                //    actually looking at, instead of being scaled up to the
                //    parallax width and losing its left/right edges;
                //  * the clock keeps its authored normalized position, because
                //    those fractions are now resolved against the viewport the
                //    user sees rather than against a surface twice its width
                //    (which pushed a centred clock off toward one edge).
                val viewport = visibleViewport()

                background?.let {
                    DepthCompositor.drawCoverBitmap(
                        canvas, it, viewport.width(), viewport.height(), bitmapPaint,
                        viewport.left, viewport.top,
                    )
                }

                // FLUTTER_RENDERING_GUIDE §2. DEPTH: background, foreground,
                // clock, foreground again at (1 - depth) so the subject
                // occludes the clock by that much, then the date widget and
                // extras on top. Without a foreground (STANDARD) this reduces
                // to background, clock, date widget, extras.
                val config = currentConfig()
                val fg = foreground
                if (fg != null) {
                    DepthCompositor.drawForeground(
                        canvas, fg, viewport.width(), viewport.height(), bitmapPaint,
                        depthConfig, viewport.left, viewport.top,
                    )
                }

                canvas.save()
                canvas.translate(viewport.left.toFloat(), viewport.top.toFloat())
                renderer.render(canvas, viewport.width(), viewport.height(), Calendar.getInstance(), config)
                canvas.restore()

                if (fg != null && config.enabled) {
                    val occlusion = 1f - config.depth
                    if (occlusion > 0f) {
                        val p = Paint(bitmapPaint).apply { alpha = (occlusion * 255).toInt().coerceIn(0, 255) }
                        DepthCompositor.drawForeground(
                            canvas, fg, viewport.width(), viewport.height(), p,
                            depthConfig, viewport.left, viewport.top,
                        )
                    }
                }

                canvas.save()
                canvas.translate(viewport.left.toFloat(), viewport.top.toFloat())
                dateRenderer.render(
                    canvas,
                    viewport.width(),
                    viewport.height(),
                    dateWidget,
                    Calendar.getInstance(),
                )
                ringRenderer.render(
                    canvas,
                    viewport.width(),
                    viewport.height(),
                    widgets,
                    battery.level,
                )
                canvas.restore()
            } catch (e: Exception) {
                // The surface can be torn down mid-frame; the next tick recovers.
            } finally {
                if (canvas != null) runCatching { holder.unlockCanvasAndPost(canvas) }
            }
            handler.removeCallbacks(drawRunnable)
            if (visible) handler.postDelayed(drawRunnable, 1000L)
        }

        override fun onDestroy() {
            handler.removeCallbacks(drawRunnable)
            battery.stop()
            background?.recycle()
            foreground?.recycle()
            background = null
            foreground = null
            loadedSignature = null
            super.onDestroy()
        }
    }

    companion object {
        /**
         * SharedPreferences key holding the serialized `studio.widgets` array
         * for the static/depth path. Named here so the channel that writes it
         * and the engine that reads it cannot drift apart.
         */
        const val KEY_WIDGETS_JSON = "live_widgets_json"

        /** SharedPreferences key for the serialized `studio.dateWidget`. */
        const val KEY_DATE_WIDGET_JSON = "live_date_widget_json"
    }
}
