package com.creative.backgrounds

import android.content.Context
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Draws the clock (time + optional date) on a canvas. Mirrors the Flutter
 * `ClockPainter` so the live wallpaper matches the in-app preview.
 */
class ClockRenderer(private val context: Context) {

    private val typefaceCache = HashMap<String, Typeface>()

    fun render(canvas: Canvas, width: Int, height: Int, now: Calendar, config: ClockConfig) {
        if (config.opacity <= 0f) return

        val timeText = formatTime(now, config.is24Hour, config.showSeconds)
        val baseColor = config.color.toInt()
        val alpha = (config.opacity * 255).toInt().coerceIn(0, 255)

        val timePaint = buildTimePaint(config, baseColor, alpha)
        val timeWidth = timePaint.measureText(timeText)
        val timeHeight = timePaint.fontMetrics.let { it.descent - it.ascent }

        var dateText: String? = null
        var datePaint: Paint? = null
        var dateHeight = 0f
        if (config.showDate) {
            dateText = formatDate(now)
            datePaint = buildDatePaint(config, baseColor, alpha)
            dateHeight = datePaint.fontMetrics.let { it.descent - it.ascent }
        }

        val gap = 24f
        val blockHeight = timeHeight + if (dateText != null) gap + dateHeight else 0f
        val topY = positionTop(config.position, height.toFloat(), blockHeight)
        val centerX = width / 2f

        // baseline for the time text
        val timeBaseline = topY - timePaint.fontMetrics.ascent

        if (config.showStroke) {
            val strokePaint = buildStrokePaint(config, alpha)
            canvas.drawText(timeText, centerX, timeBaseline, strokePaint)
        }
        canvas.drawText(timeText, centerX, timeBaseline, timePaint)

        if (dateText != null && datePaint != null) {
            val dateBaseline = topY + timeHeight + gap - datePaint.fontMetrics.ascent
            canvas.drawText(dateText, centerX, dateBaseline, datePaint)
        }
    }

    private fun buildTimePaint(config: ClockConfig, color: Int, alpha: Int): Paint {
        val paint = basePaint(config, color, alpha)
        paint.textSize = config.sizePx * 2f // px sizes match Flutter logical → device scale
        if (config.showShadow) paint.setShadowLayer(10f, 0f, 5f, Color.argb(140, 0, 0, 0))
        if (config.showGlow) paint.maskFilter = BlurMaskFilter(24f, BlurMaskFilter.Blur.OUTER)
        return paint
    }

    private fun buildDatePaint(config: ClockConfig, color: Int, alpha: Int): Paint {
        val paint = basePaint(config, color, alpha)
        paint.textSize = (config.sizePx * 0.44f).coerceIn(28f, 48f)
        paint.typeface = loadTypeface(config.font, 500, false)
        if (config.showShadow) paint.setShadowLayer(6f, 0f, 3f, Color.argb(120, 0, 0, 0))
        return paint
    }

    private fun buildStrokePaint(config: ClockConfig, alpha: Int): Paint {
        val paint = basePaint(config, Color.BLACK, alpha)
        paint.textSize = config.sizePx * 2f
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 4f
        return paint
    }

    private fun basePaint(config: ClockConfig, color: Int, alpha: Int): Paint {
        return Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            this.alpha = alpha
            textAlign = Paint.Align.CENTER
            typeface = loadTypeface(config.font, weightForStyle(config.style),
                config.style == "elegant")
            letterSpacing = letterSpacingForStyle(config.style)
        }
    }

    private fun weightForStyle(style: String): Int = when (style) {
        "minimal" -> 300
        "elegant" -> 400
        else -> 700 // modern, digital
    }

    private fun letterSpacingForStyle(style: String): Float = when (style) {
        "minimal" -> 0.1f
        "digital" -> 0.04f
        "modern" -> -0.03f
        else -> 0f
    }

    private fun loadTypeface(font: String, weight: Int, italic: Boolean): Typeface {
        val asset = when (font) {
            "serif" -> "flutter_assets/assets/fonts/PlayfairDisplay-Variable.ttf"
            "mono" -> "flutter_assets/assets/fonts/JetBrainsMono-Variable.ttf"
            else -> "flutter_assets/assets/fonts/Inter-Variable.ttf"
        }
        val key = "$asset:$weight:$italic"
        return typefaceCache.getOrPut(key) {
            val base = try {
                Typeface.createFromAsset(context.assets, asset)
            } catch (e: Exception) {
                Typeface.DEFAULT
            }
            Typeface.create(base, weight, italic)
        }
    }

    private fun positionTop(position: String, height: Float, blockHeight: Float): Float =
        when (position) {
            "top" -> height * 0.16f
            "bottom" -> height * 0.74f - blockHeight
            else -> (height - blockHeight) / 2f
        }

    private fun formatTime(now: Calendar, is24Hour: Boolean, showSeconds: Boolean): String {
        val pattern = if (is24Hour) {
            if (showSeconds) "HH:mm:ss" else "HH:mm"
        } else {
            if (showSeconds) "h:mm:ss" else "h:mm"
        }
        return SimpleDateFormat(pattern, Locale.getDefault()).format(now.time)
    }

    private fun formatDate(now: Calendar): String =
        SimpleDateFormat("EEEE, MMMM d", Locale.getDefault()).format(now.time)
}
