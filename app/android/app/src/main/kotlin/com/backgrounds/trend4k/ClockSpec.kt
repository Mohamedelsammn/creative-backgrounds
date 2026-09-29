package com.backgrounds.trend4k

import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/**
 * Native mirror of Dart's `ClockRenderSpec` (FLUTTER_RENDERING_GUIDE.md §1, §3).
 * Every constant here must equal the Dart one; `clock_render_spec_test.dart`
 * pins both files to the same values.
 */
object ClockSpec {

    /** size = W * 0.14 * scale * (sizePx / 65), W = the viewport width. */
    fun clockSize(viewportWidth: Float, c: ClockConfig): Float =
        viewportWidth * 0.14f * c.scale * (c.sizePx / 65f)

    fun rowGap(layout: String, size: Float, lineSpacing: Float): Float = when (layout) {
        "stacked" -> 0.08f * size * lineSpacing
        "stackedCompact" -> 0.02f * size * lineSpacing
        "offsetStack" -> 0.08f * size * lineSpacing
        else -> 0f // inline, verticalPoster
    }

    fun minuteShift(c: ClockConfig, size: Float): Float =
        if (c.timeLayout == "offsetStack") c.minuteOffsetX * size else 0f

    fun amPmFontSize(size: Float): Float = 0.3f * size
    fun amPmGap(size: Float): Float = 0.08f * size
    const val AM_PM_LETTER_SPACING_EM = 0.04f

    fun dateFontSize(size: Float, dateScale: Float): Float = 0.2f * size * dateScale
    const val DATE_LETTER_SPACING_EM = 0.06f

    fun strokeWidth(c: ClockConfig, size: Float): Float = c.strokeWidth * (size / 65f)
    fun shadowOffsetY(size: Float): Float = 0.04f * size
    fun shadowBlur(size: Float): Float = 0.05f * size
    fun glowInnerBlur(size: Float): Float = 0.18f * size
    fun glowOuterBlur(size: Float): Float = 0.30f * size
    fun blurSigma(c: ClockConfig, size: Float): Float = c.blur * (size / 65f)

    fun uses24Hour(c: ClockConfig, deviceIs24Hour: Boolean): Boolean = when (c.hourFormat) {
        "h24" -> true
        "h12" -> false
        "auto" -> deviceIs24Hour
        else -> c.is24Hour
    }

    fun showsAmPm(c: ClockConfig, is24Hour: Boolean): Boolean = c.showAmPm && !is24Hour

    fun drawsColon(c: ClockConfig): Boolean {
        if (c.timeLayout != "inline") return false
        return if (c.colorMode == "split") c.showColon else true
    }

    /** Centre of the whole clock piece. Exact coordinates win when both are set. */
    fun center(c: ClockConfig, w: Float, h: Float): Pair<Float, Float> {
        val x = c.customX
        val y = c.customY
        if (x != null && y != null) return Pair(x * w, y * h)
        val fy = when (c.position) {
            "top" -> 0.14f
            "bottom" -> 0.78f
            else -> 0.5f
        }
        return Pair(w / 2f, fy * h)
    }

    data class Face(val family: String, val weight: Int, val letterSpacingEm: Float, val italic: Boolean = false)

    /** [half]: "hours", "minutes" or null for the clock as a whole (§3.2). */
    fun typeface(c: ClockConfig, half: String? = null): Face {
        val style = (c.remoteStyle ?: c.style).trim().lowercase()
        val halfFont = when (half) {
            "hours" -> c.hoursFont
            "minutes" -> c.minutesFont
            else -> null
        }
        val own = when {
            halfFont != null -> familyFor(halfFont)
            c.remoteFont != null -> familyFor(c.remoteFont)
            else -> bundledFamily(c.font)
        }
        val w = c.weight
        val t = when (style) {
            "modern" -> Face(own, w, -0.03f)
            "minimal" -> Face(own, 300, 0.12f)
            "elegant" -> Face(SERIF, w, 0f, italic = true)
            "digital" -> Face(MONO, 700, 0.04f)
            "condensed" -> Face(OSWALD, 600, -0.02f)
            "poster" -> Face(ARCHIVO, 900, -0.03f)
            "outline" -> Face(own, 900, 0f)
            "split" -> Face(own, 800, -0.02f)
            "futuristic" -> Face(ANTON, w, 0.05f)
            "editorial" -> Face(ARCHIVO, 900, -0.02f)
            "monument" -> Face(OSWALD, 700, -0.03f)
            "stencil" -> Face(ANTON, w, 0.08f)
            "soft" -> Face(own, 500, 0f)
            "thin" -> Face(own, 200, 0f)
            "bold" -> Face(own, 800, 0f)
            "classic" -> Face(SERIF, w, 0f)
            else -> Face(own, w, 0f)
        }
        return if (halfFont == null) t else t.copy(family = own)
    }

    const val INTER = "Inter"
    const val SERIF = "PlayfairDisplay"
    const val MONO = "JetBrainsMono"
    const val OSWALD = "Oswald"
    const val ARCHIVO = "ArchivoBlack"
    const val ANTON = "Anton"

    val VARIABLE_FAMILIES = setOf(INTER, SERIF, MONO, OSWALD)

    /** ClockFont's Dart enum names, as the channel JSON carries them. */
    fun bundledFamily(font: String): String = when (font) {
        "serif" -> SERIF
        "mono" -> MONO
        "oswald" -> OSWALD
        "archivoBlack" -> ARCHIVO
        "anton" -> ANTON
        else -> INTER
    }

    fun familyFor(name: String): String {
        val n = name.trim().lowercase().replace(Regex("[\\s_-]"), "")
        return when {
            n.contains("archivo") -> ARCHIVO
            n.contains("anton") -> ANTON
            n.contains("oswald") -> OSWALD
            listOf("playfair", "serif", "georgia", "times", "merriweather").any { n.contains(it) } -> SERIF
            listOf("mono", "jetbrains", "courier", "code").any { n.contains(it) } -> MONO
            else -> INTER
        }
    }

    /** CSS linear-gradient line across a w x h box (origin top-left). */
    fun gradientLine(angleDeg: Float, w: Float, h: Float): FloatArray {
        val rad = Math.toRadians(angleDeg.toDouble())
        val dx = sin(rad).toFloat()
        val dy = (-cos(rad)).toFloat()
        val half = (w * abs(dx) + h * abs(dy)) / 2f
        val cx = w / 2f
        val cy = h / 2f
        return floatArrayOf(cx - dx * half, cy - dy * half, cx + dx * half, cy + dy * half)
    }

    /** (offsets, alphas) top to bottom of the time block. */
    fun fadeStops(direction: String, amount: Float): Pair<FloatArray, FloatArray> {
        val a = amount.coerceIn(0f, 1f)
        return when (direction) {
            "top" -> Pair(floatArrayOf(0f, a, 1f), floatArrayOf(0f, 1f, 1f))
            "both" -> if (a <= 0.5f) {
                Pair(floatArrayOf(0f, a, 1f - a, 1f), floatArrayOf(0f, 1f, 1f, 0f))
            } else {
                Pair(floatArrayOf(0f, 0.5f, 1f), floatArrayOf(0f, 0.5f / a, 0f))
            }
            else -> Pair(floatArrayOf(0f, 1f - a, 1f), floatArrayOf(1f, 1f, 0f))
        }
    }
}
