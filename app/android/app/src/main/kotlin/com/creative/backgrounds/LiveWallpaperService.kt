package com.creative.backgrounds

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
import android.view.SurfaceHolder
import java.util.Calendar

/**
 * Renders the clock/depth wallpaper. Draws background → clock → foreground each
 * tick (1 Hz), and pauses when not visible to save battery.
 */
class LiveWallpaperService : WallpaperService() {

    override fun onCreateEngine(): Engine = ClockEngine()

    inner class ClockEngine : Engine() {
        private val handler = Handler(Looper.getMainLooper())
        private val renderer = ClockRenderer(this@LiveWallpaperService)
        private val bitmapPaint = Paint(Paint.FILTER_BITMAP_FLAG)

        private var background: Bitmap? = null
        private var foreground: Bitmap? = null
        private var width = 0
        private var height = 0
        private var visible = false

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
                drawFrame()
            } else {
                handler.removeCallbacks(drawRunnable)
            }
        }

        private fun loadAssets() {
            val prefs = getSharedPreferences("clock_prefs", Context.MODE_PRIVATE)
            val bgPath = prefs.getString("live_bg_path", null)
            val depthEnabled = prefs.getBoolean("live_depth_enabled", false)
            val maskPath = prefs.getString("live_mask_path", null)

            background?.recycle()
            background = bgPath?.let { runCatching { BitmapFactory.decodeFile(it) }.getOrNull() }

            foreground?.recycle()
            foreground = if (depthEnabled && maskPath != null) {
                runCatching { BitmapFactory.decodeFile(maskPath) }.getOrNull()
            } else null
        }

        private fun currentConfig(): ClockConfig {
            val prefs = getSharedPreferences("clock_prefs", Context.MODE_PRIVATE)
            return ClockConfig.fromJson(prefs.getString("clock_config_json", null))
        }

        private fun drawFrame() {
            val holder = surfaceHolder
            var canvas: Canvas? = null
            try {
                canvas = holder.lockCanvas() ?: return
                canvas.drawColor(Color.BLACK)
                background?.let { drawCover(canvas, it) }
                renderer.render(canvas, width, height, Calendar.getInstance(), currentConfig())
                foreground?.let { drawCover(canvas, it) }
            } finally {
                if (canvas != null) holder.unlockCanvasAndPost(canvas)
            }
            handler.removeCallbacks(drawRunnable)
            if (visible) handler.postDelayed(drawRunnable, 1000L)
        }

        private fun drawCover(canvas: Canvas, bitmap: Bitmap) {
            if (width == 0 || height == 0) return
            val scale = maxOf(width.toFloat() / bitmap.width, height.toFloat() / bitmap.height)
            val sw = (bitmap.width * scale).toInt()
            val sh = (bitmap.height * scale).toInt()
            val left = (width - sw) / 2
            val top = (height - sh) / 2
            canvas.drawBitmap(bitmap, null, Rect(left, top, left + sw, top + sh), bitmapPaint)
        }

        override fun onDestroy() {
            handler.removeCallbacks(drawRunnable)
            background?.recycle()
            foreground?.recycle()
            super.onDestroy()
        }
    }
}
