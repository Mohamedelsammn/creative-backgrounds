package com.backgrounds.trend4k

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Draws the `studio.dateWidget` - a date element positioned independently of
 * the clock, with its own coordinates, font, scale and colour.
 *
 * This is NOT the clock's own nested `date` (which sits directly above or
 * below the time and is drawn by [ClockRenderer]). The two are separate
 * authored elements; production data enables at most one of them per wallpaper.
 *
 * Formatting mirrors Dart's `StudioDateFormats` exactly - same patterns, same
 * base size, same CENTRE anchor - so the applied wallpaper shows the string the
 * user previewed.
 */
class StudioDateRenderer(private val context: Context) {

    companion object {
        /** Base font size in logical pixels at `scale: 1.0`. */
        const val BASE_SIZE_PX = 28f

        /**
         * `format` id -> date pattern. Mirrors `StudioDateFormats.patternFor`.
         */
        fun patternFor(format: String): String = when (format) {
            "short" -> "MMM d"
            "long" -> "EEEE, MMMM d"
            // `medium` is the documented default.
            else -> "MMM d, yyyy"
        }

        /** Formats the date for [config], including its uppercase rule. */
        fun format(config: StudioDateConfig, now: Calendar): String {
            val pattern = config.pattern ?: patternFor(config.format)
            // The authored locale, not the device's - the wallpaper is
            // artwork, so it must read as the content team composed it. Same
            // rationale as the clock's pinned Latin digits.
            val locale = runCatching { Locale.forLanguageTag(config.locale) }
                .getOrNull() ?: Locale.US
            val text = runCatching {
                SimpleDateFormat(pattern, locale).format(now.time)
            }.getOrElse { return "" }
            return if (config.uppercase) text.uppercase(locale) else text
        }
    }

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
    }

    /**
     * Draws [config] onto [canvas].
     *
     * [width]/[height] are the surface the normalized coordinates resolve
     * against - callers that compose into a viewport pass the VIEWPORT size
     * and translate first, exactly as they already do for the clock.
     */
    fun render(
        canvas: Canvas,
        width: Int,
        height: Int,
        config: StudioDateConfig?,
        now: Calendar,
    ) {
        if (config == null || !config.enabled) return
        if (width <= 0 || height <= 0) return

        val text = format(config, now)
        if (text.isEmpty()) return

        // FLUTTER_RENDERING_GUIDE §7.1: font size W * 0.05 * scale, letter
        // spacing 0.06em, centred on its point. Mirrors date_widget_renderer.dart.
        paint.textSize = width * 0.05f * config.scale
        paint.letterSpacing = 0.06f
        paint.color = config.color.toInt()
        paint.alpha = Color.alpha(config.color.toInt())
        paint.typeface = typefaceFor(config.font, config.weight)

        val x = config.customX
        val y = config.customY
        val centerX: Float
        val centerY: Float
        if (x != null && y != null) {
            centerX = width * x
            centerY = height * y
        } else {
            centerX = width / 2f
            centerY = height * when (config.position) {
                "top" -> 0.14f
                "center" -> 0.5f
                else -> 0.78f
            }
        }
        val metrics = paint.fontMetrics
        val baseline = centerY - (metrics.ascent + metrics.descent) / 2f
        canvas.drawText(text, centerX, baseline, paint)
    }

    private fun typefaceFor(font: String, weight: Int): Typeface {
        val family = ClockSpec.familyFor(font)
        val asset = when (family) {
            ClockSpec.SERIF -> "PlayfairDisplay-Variable.ttf"
            ClockSpec.MONO -> "JetBrainsMono-Variable.ttf"
            ClockSpec.OSWALD -> "Oswald-Variable.ttf"
            ClockSpec.ARCHIVO -> "ArchivoBlack-Regular.ttf"
            ClockSpec.ANTON -> "Anton-Regular.ttf"
            else -> "Inter-Variable.ttf"
        }
        val path = "flutter_assets/assets/fonts/$asset"
        val w = weight.coerceIn(1, 1000)
        return runCatching {
            if (family in ClockSpec.VARIABLE_FAMILIES) {
                Typeface.Builder(context.assets, path)
                    .setFontVariationSettings("'wght' $w").setWeight(w).build()
            } else if (family == ClockSpec.ARCHIVO) {
                Typeface.createFromAsset(context.assets, path)
            } else {
                Typeface.create(Typeface.createFromAsset(context.assets, path), w, false)
            }
        }.getOrElse { Typeface.create(Typeface.DEFAULT, w, false) }
    }
}
