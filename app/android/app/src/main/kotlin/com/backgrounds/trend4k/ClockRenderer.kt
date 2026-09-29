package com.backgrounds.trend4k

import android.content.Context
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kotlin.math.sqrt

/**
 * Draws the authored clock on the applied wallpaper exactly as the dashboard
 * does. Mirrors Dart's `ClockPainter` line for line; every number comes from
 * [ClockSpec], the Kotlin twin of `ClockRenderSpec`.
 *
 * `width`/`height` are the visible phone-screen viewport in device pixels.
 * Sizes are proportions of that width, so no density conversion is involved.
 */
class ClockRenderer(private val context: Context) {

    private val typefaceCache = HashMap<String, Typeface>()

    /**
     * Every clock/date string is formatted in this locale, never the device
     * one: the clock is artwork, and an Arabic device locale would put
     * Arabic-Indic digits into the applied wallpaper.
     */
    private val artworkLocale: Locale = Locale.US

    /** A run of text on one clock line, already positioned. */
    class Segment(
        val role: String, // hours | colon | minutes | amPm
        val text: String,
        val paint: Paint,
        val x: Float,
        val baseline: Float,
    )

    /** Resolved geometry, before rotation and horizontalScale/stretchY. */
    class Layout(
        val size: Float,
        val centerX: Float,
        val centerY: Float,
        val timeRect: RectF,
        val lineRects: List<RectF>,
        val segments: List<Segment>,
        val dateText: String?,
        val datePaint: Paint?,
        val dateRect: RectF?,
    )

    fun render(canvas: Canvas, width: Int, height: Int, now: Calendar, config: ClockConfig) {
        if (!config.enabled || config.opacity <= 0f) return
        val layout = computeLayout(width.toFloat(), height.toFloat(), now, config) ?: return

        canvas.save()
        canvas.translate(layout.centerX, layout.centerY)
        if (config.rotation != 0f) canvas.rotate(config.rotation)
        if (config.horizontalScale != 1f || config.stretchY != 1f) {
            canvas.scale(config.horizontalScale, config.stretchY)
        }
        canvas.translate(-layout.centerX, -layout.centerY)

        val wholeLayer = config.opacity < 1f
        if (wholeLayer) canvas.saveLayerAlpha(null, (config.opacity * 255).toInt().coerceIn(0, 255))

        paintTime(canvas, layout, config)

        val dp = layout.datePaint
        val dr = layout.dateRect
        if (layout.dateText != null && dp != null && dr != null) {
            if (config.showShadow) drawShadowPass(canvas, layout.dateText, dr.left, baselineInBox(dp, dr.height()) + dr.top, dp, shadowColor(config), ClockSpec.shadowBlur(layout.size), ClockSpec.shadowOffsetY(layout.size), 0f)
            canvas.drawText(layout.dateText, dr.left, dr.top + baselineInBox(dp, dr.height()), dp)
        }

        if (wholeLayer) canvas.restore()
        canvas.restore()
    }

    fun computeLayout(w: Float, h: Float, now: Calendar, c: ClockConfig): Layout? {
        if (!c.enabled) return null
        val s = ClockSpec.clockSize(w, c)
        if (s <= 0f) return null

        val deviceIs24 = android.text.format.DateFormat.is24HourFormat(context)
        val is24 = ClockSpec.uses24Hour(c, deviceIs24)
        val time = formatTime(now, is24, c.showSeconds)
        val colon = time.indexOf(':')
        val hourText = if (colon < 0) time else time.substring(0, colon)
        val minuteText = if (colon < 0) "" else time.substring(colon + 1)
        val amPm = if (ClockSpec.showsAmPm(c, is24)) SimpleDateFormat("a", artworkLocale).format(now.time) else null

        val hoursFace = ClockSpec.typeface(c, "hours")
        val minutesFace = ClockSpec.typeface(c, "minutes")
        val clockFace = ClockSpec.typeface(c)

        data class Run(val role: String, val text: String, val paint: Paint, val leadingGap: Float = 0f)

        val hours = Run("hours", hourText, textPaint(hoursFace, s))
        val minutes = Run("minutes", minuteText, textPaint(minutesFace, s))
        val amPmRun = amPm?.let {
            Run(
                "amPm", it,
                textPaint(minutesFace.copy(letterSpacingEm = ClockSpec.AM_PM_LETTER_SPACING_EM), ClockSpec.amPmFontSize(s)),
                ClockSpec.amPmGap(s),
            )
        }
        val inline = c.timeLayout == "inline"
        val lines = if (inline) {
            listOfNotNull(hours, if (ClockSpec.drawsColon(c)) Run("colon", ":", textPaint(clockFace, s)) else null, minutes, amPmRun).let { listOf(it) }
        } else {
            listOf(listOf(hours), listOfNotNull(minutes, amPmRun))
        }

        val gap = ClockSpec.rowGap(c.timeLayout, s, c.lineSpacing)
        val shift = ClockSpec.minuteShift(c, s)
        fun lineWidth(line: List<Run>) = line.sumOf { (it.leadingGap + it.paint.measureText(it.text)).toDouble() }.toFloat()
        val timeW = lines.maxOf { lineWidth(it) }
        val timeH = lines.size * s + (lines.size - 1) * gap

        var dateText: String? = null
        var datePaint: Paint? = null
        var dateH = 0f
        if (c.showDate) {
            val d = ClockSpec.dateFontSize(s, c.dateScale)
            dateText = formatDate(now)
            datePaint = textPaint(clockFace.copy(letterSpacingEm = ClockSpec.DATE_LETTER_SPACING_EM), d).apply {
                color = (c.dateColor ?: c.color).toInt()
            }
            dateH = d
        }

        val pieceH = timeH + dateH
        val (cx, cy) = ClockSpec.center(c, w, h)
        val pieceTop = cy - pieceH / 2f
        val dateAbove = dateText != null && c.datePosition == "above"
        val timeTop = pieceTop + if (dateAbove) dateH else 0f
        val timeRect = RectF(cx - timeW / 2f, timeTop, cx + timeW / 2f, timeTop + timeH)

        val segments = ArrayList<Segment>()
        val lineRects = ArrayList<RectF>()
        lines.forEachIndexed { i, line ->
            val top = timeTop + i * (s + gap)
            val lw = lineWidth(line)
            var x = cx - lw / 2f + if (!inline && i == 1) shift else 0f
            lineRects.add(RectF(x, top, x + lw, top + s))
            // The line's em box sets the baseline; smaller runs share it.
            val baseline = top + baselineInBox(line.first().paint, s)
            for (r in line) {
                x += r.leadingGap
                segments.add(Segment(r.role, r.text, r.paint, x, baseline))
                x += r.paint.measureText(r.text)
            }
        }

        val dateRect = if (dateText != null && datePaint != null) {
            val dw = datePaint.measureText(dateText)
            val top = if (dateAbove) pieceTop else timeTop + timeH
            RectF(cx - dw / 2f, top, cx + dw / 2f, top + dateH)
        } else null

        return Layout(s, cx, cy, timeRect, lineRects, segments, dateText, datePaint, dateRect)
    }

    private fun paintTime(canvas: Canvas, layout: Layout, c: ClockConfig) {
        val s = layout.size
        val fading = c.fadeAmount > 0f
        val bounds = RectF(layout.timeRect).apply { inset(-s, -s) }
        if (fading) canvas.saveLayer(bounds, null)

        val sigma = ClockSpec.blurSigma(c, s)
        val gradient = if (c.colorMode == "gradient") gradientShader(layout.timeRect, c) else null
        val strokeW = if (c.showStroke) ClockSpec.strokeWidth(c, s) else 0f

        for (seg in layout.segments) {
            val digits = seg.role != "amPm"
            // Shadow and glow, beneath the fill (Flutter paints a text's
            // shadows in list order, then the text).
            if (c.showShadow) drawShadowPass(canvas, seg.text, seg.x, seg.baseline, seg.paint, shadowColor(c), ClockSpec.shadowBlur(s), ClockSpec.shadowOffsetY(s), sigma)
            if (c.showGlow) {
                drawShadowPass(canvas, seg.text, seg.x, seg.baseline, seg.paint, c.color.toInt(), ClockSpec.glowInnerBlur(s), 0f, sigma)
                drawShadowPass(canvas, seg.text, seg.x, seg.baseline, seg.paint, c.color.toInt(), ClockSpec.glowOuterBlur(s), 0f, sigma)
            }
            if (digits && strokeW > 0f && c.strokeOrder != "front") {
                canvas.drawText(seg.text, seg.x, seg.baseline, strokePaint(seg.paint, c, strokeW * 2f, sigma))
            }
            val fill = Paint(seg.paint).apply {
                val base = fillColor(seg.role, c)
                color = base
                alpha = (Color.alpha(base) * c.fillOpacity).toInt().coerceIn(0, 255)
                if (gradient != null) shader = gradient
                maskFilter = blurFilter(sigma)
            }
            canvas.drawText(seg.text, seg.x, seg.baseline, fill)
            if (digits && strokeW > 0f && c.strokeOrder == "front") {
                canvas.drawText(seg.text, seg.x, seg.baseline, strokePaint(seg.paint, c, strokeW, sigma))
            }
        }

        if (fading) {
            val (offsets, alphas) = ClockSpec.fadeStops(c.fadeDirection, c.fadeAmount)
            val colors = IntArray(alphas.size) { Color.argb((alphas[it] * 255).toInt(), 0, 0, 0) }
            val r = layout.timeRect
            canvas.drawRect(bounds, Paint().apply {
                shader = LinearGradient(r.centerX(), r.top, r.centerX(), r.bottom, colors, offsets, Shader.TileMode.CLAMP)
                xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN)
            })
            canvas.restore()
        }
    }

    private fun fillColor(role: String, c: ClockConfig): Int {
        val base = c.color.toInt()
        if (c.colorMode != "split") return base
        val hours = (c.hoursColor ?: c.color).toInt()
        val minutes = (c.minutesColor ?: c.color).toInt()
        return when (role) {
            "hours" -> hours
            "colon" -> when (c.colonColor) {
                "minutes" -> minutes
                "custom" -> (c.colonColorCustom ?: c.color).toInt()
                else -> hours
            }
            else -> minutes // minutes, amPm
        }
    }

    private fun gradientShader(r: RectF, c: ClockConfig): Shader {
        val l = ClockSpec.gradientLine(c.gradientAngleDeg, r.width(), r.height())
        return LinearGradient(
            r.left + l[0], r.top + l[1], r.left + l[2], r.top + l[3],
            (c.gradientFrom ?: c.color).toInt(), (c.gradientTo ?: c.color).toInt(),
            Shader.TileMode.CLAMP,
        )
    }

    private fun shadowColor(c: ClockConfig): Int =
        Color.argb((c.shadowStrength * 255).toInt().coerceIn(0, 255), 0, 0, 0)

    /** A blurred silhouette of the glyphs, like a Flutter text [Shadow]. */
    private fun drawShadowPass(
        canvas: Canvas, text: String, x: Float, baseline: Float, base: Paint,
        color: Int, blurRadius: Float, dy: Float, extraSigma: Float,
    ) {
        val p = Paint(base).apply {
            this.color = color
            shader = null
            // Radius -> sigma exactly as Flutter/Skia convert it, then combined
            // with the time's own blur (a blurred layer blurs its shadows too).
            val sigma = sqrt(radiusToSigma(blurRadius).let { it * it } + extraSigma * extraSigma)
            maskFilter = blurFilter(sigma)
        }
        canvas.drawText(text, x, baseline + dy, p)
    }

    private fun strokePaint(base: Paint, c: ClockConfig, width: Float, sigma: Float): Paint =
        Paint(base).apply {
            style = Paint.Style.STROKE
            strokeWidth = width
            strokeJoin = Paint.Join.ROUND
            color = c.strokeColor.toInt()
            shader = null
            maskFilter = blurFilter(sigma)
        }

    private fun radiusToSigma(radius: Float): Float = if (radius > 0f) radius * 0.57735f + 0.5f else 0f

    private fun blurFilter(sigma: Float): BlurMaskFilter? {
        if (sigma <= 0.5f) return null
        return BlurMaskFilter((sigma - 0.5f) / 0.57735f, BlurMaskFilter.Blur.NORMAL)
    }

    /** Baseline of a one-em line box with CSS `line-height: 1` (even) leading. */
    private fun baselineInBox(paint: Paint, boxHeight: Float): Float {
        val fm = paint.fontMetrics
        val ascent = -fm.ascent
        val descent = fm.descent
        return (boxHeight - (ascent + descent)) / 2f + ascent
    }

    private fun textPaint(face: ClockSpec.Face, fontSize: Float): Paint =
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.LEFT
            textSize = fontSize
            typeface = loadTypeface(face.family, face.weight, face.italic)
            letterSpacing = face.letterSpacingEm
            color = Color.WHITE
        }

    private fun loadTypeface(family: String, weight: Int, italic: Boolean): Typeface {
        val key = "$family:$weight:$italic"
        return typefaceCache.getOrPut(key) {
            val asset = when (family) {
                ClockSpec.SERIF -> if (italic) "PlayfairDisplay-Italic-Variable.ttf" else "PlayfairDisplay-Variable.ttf"
                ClockSpec.MONO -> "JetBrainsMono-Variable.ttf"
                ClockSpec.OSWALD -> "Oswald-Variable.ttf"
                ClockSpec.ARCHIVO -> "ArchivoBlack-Regular.ttf"
                ClockSpec.ANTON -> "Anton-Regular.ttf"
                else -> "Inter-Variable.ttf"
            }
            val path = "flutter_assets/assets/fonts/$asset"
            try {
                if (family in ClockSpec.VARIABLE_FAMILIES) {
                    // The weight is the variable font's `wght` axis, so it
                    // renders the real cut instead of a synthesized bold.
                    Typeface.Builder(context.assets, path)
                        .setFontVariationSettings("'wght' $weight")
                        .setWeight(weight.coerceIn(1, 1000))
                        .setItalic(italic)
                        .build()
                } else if (family == ClockSpec.ARCHIVO) {
                    // Archivo Black ships only its Black (900) cut; requesting
                    // a weight on top would synthesize a second bold.
                    Typeface.createFromAsset(context.assets, path)
                } else {
                    Typeface.create(Typeface.createFromAsset(context.assets, path), weight.coerceIn(1, 1000), italic)
                }
            } catch (e: Exception) {
                Typeface.create(Typeface.DEFAULT, weight.coerceIn(1, 1000), italic)
            }
        }
    }

    /** Hours and minutes two digits, seconds with the minutes, Latin digits. */
    private fun formatTime(now: Calendar, is24Hour: Boolean, showSeconds: Boolean): String {
        val pattern = if (is24Hour) {
            if (showSeconds) "HH:mm:ss" else "HH:mm"
        } else {
            if (showSeconds) "hh:mm:ss" else "hh:mm"
        }
        return SimpleDateFormat(pattern, artworkLocale).format(now.time)
    }

    /**
     * "Sunday, September 27". Pinned to the artwork locale like the time, so
     * an Arabic phone never gets Arabic-Indic digits in the applied wallpaper.
     * Mirrors ClockPainter's `DateFormat.MMMMEEEEd('en_US')`.
     */
    private fun formatDate(now: Calendar): String =
        SimpleDateFormat("EEEE, MMMM d", artworkLocale).format(now.time)
}
