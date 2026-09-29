package com.backgrounds.trend4k

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface

/**
 * Draws the `batteryRing` studio widget.
 *
 * THE single native battery-ring renderer, shared by every wallpaper path
 * (static-routed-to-live, video, depth) so the three cannot diverge - the same
 * arrangement `ClockRenderer` already has.
 *
 * Geometry mirrors Dart's `BatteryRingWidget` line for line: the constants in
 * [Metrics] are the same numbers as `BatteryRingMetrics`, `customX`/`customY`
 * anchor the ring's CENTRE (the proven convention, unchanged), the arc starts
 * at 12 o'clock and sweeps clockwise, and the percentage text is sized off the
 * ring diameter. A divergence here would mean the applied wallpaper does not
 * match what the user previewed.
 *
 * Sizes are authored in Flutter logical pixels, so every absolute quantity is
 * multiplied by the display density - exactly as `ClockRenderer` converts
 * `sizePx`.
 */
class BatteryRingRenderer(private val context: Context) {

    object Metrics {
        /**
         * Ring diameter in logical pixels at `scale: 1.0`.
         *
         * The dashboard's own composited reference renders this as a small
         * thin badge, not a dominant circle - closer to a status-bar battery
         * glyph than a progress ring. 28 (down from an earlier 64) matches
         * that proportion. Mirrors Dart's `BatteryRingMetrics.baseDiameter`.
         */
        const val BASE_DIAMETER = 28f

        /** Stroke thickness in logical pixels at `scale: 1.0`. */
        const val BASE_STROKE = 2.5f

        /** Alpha applied to the authored colour for the unfilled track. */
        const val TRACK_ALPHA = 0.25f

        /** 12 o'clock, sweeping clockwise. */
        const val START_ANGLE = -90f

        /** Percentage label's font size as a fraction of the ring diameter. */
        const val LABEL_SIZE_FRACTION = 0.62f

        /** Gap between the ring's right edge and the label, at `scale: 1.0`. */
        const val LABEL_GAP = 6f
    }

    private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }

    private val arcPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }

    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        // Beside the ring, not centred inside it - see `draw`'s label
        // positioning below.
        textAlign = Paint.Align.LEFT
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }

    private val oval = RectF()

    /**
     * Draws every battery ring in [widgets] onto [canvas].
     *
     * [level] is the current battery percentage 0..100, or null when it cannot
     * be read - in which case only the track is drawn, because an empty ring
     * would read as "0%", which would be a lie rather than an absence.
     *
     * [width]/[height] are the surface the normalized coordinates resolve
     * against. Callers that compose into a viewport (see
     * `LiveWallpaperService.visibleViewport`) pass the VIEWPORT size and
     * translate the canvas first, exactly as they already do for the clock.
     */
    fun render(
        canvas: Canvas,
        width: Int,
        height: Int,
        widgets: List<StudioWidgetConfig>,
        level: Int?,
    ) {
        if (width <= 0 || height <= 0) return
        for (widget in widgets) {
            if (widget is StudioWidgetConfig.BatteryRing) {
                draw(canvas, width, height, widget, level)
            }
        }
    }

    private fun draw(
        canvas: Canvas,
        width: Int,
        height: Int,
        config: StudioWidgetConfig.BatteryRing,
        level: Int?,
    ) {
        // FLUTTER_RENDERING_GUIDE §7.2: base font size W * 0.045 * scale, the
        // ring about 1.1x that with a 0.14x border; ring and percentage form
        // one row centred on the point. Mirrors battery_ring_widget.dart.
        val text = width * 0.045f * config.scale
        val diameter = text * 1.1f
        val stroke = diameter * 0.14f
        val radius = (diameter - stroke) / 2f
        if (radius <= 0f) return

        val label = if (level != null && config.showPercentage) "$level%" else null
        textPaint.textSize = text
        val gap = diameter * Metrics.LABEL_GAP / Metrics.BASE_DIAMETER
        val rowWidth = diameter + if (label != null) gap + textPaint.measureText(label) else 0f

        val ax: Float
        val ay: Float
        val cxRaw = config.customX
        val cyRaw = config.customY
        if (cxRaw != null && cyRaw != null) {
            ax = width * cxRaw
            ay = height * cyRaw
        } else {
            ax = width / 2f
            ay = height * when (config.anchor) {
                "center" -> 0.5f
                "bottom" -> 0.82f
                else -> 0.2f
            }
        }
        val centerX = ax - rowWidth / 2f + diameter / 2f
        val centerY = ay

        val color = config.color.toInt()
        val baseAlpha = Color.alpha(color)

        val saved = canvas.save()
        if (config.rotation != 0f) {
            canvas.rotate(config.rotation, centerX, centerY)
        }

        trackPaint.strokeWidth = stroke
        trackPaint.color = color
        trackPaint.alpha = (baseAlpha * Metrics.TRACK_ALPHA).toInt()
            .coerceIn(0, 255)
        canvas.drawCircle(centerX, centerY, radius, trackPaint)

        if (level != null) {
            val fraction = (level / 100f).coerceIn(0f, 1f)
            arcPaint.strokeWidth = stroke
            arcPaint.color = color
            arcPaint.alpha = baseAlpha
            oval.set(
                centerX - radius,
                centerY - radius,
                centerX + radius,
                centerY + radius,
            )
            canvas.drawArc(
                oval,
                Metrics.START_ANGLE,
                360f * fraction,
                false,
                arcPaint,
            )

            if (label != null) {
                textPaint.color = color
                textPaint.alpha = baseAlpha
                val metrics = textPaint.fontMetrics
                val baseline = centerY - (metrics.ascent + metrics.descent) / 2f
                canvas.drawText(label, centerX + diameter / 2f + gap, baseline, textPaint)
            }
        }

        canvas.restoreToCount(saved)
    }
}
