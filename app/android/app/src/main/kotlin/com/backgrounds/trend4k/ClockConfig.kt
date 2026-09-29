package com.backgrounds.trend4k

import org.json.JSONObject

/**
 * Native mirror of the Flutter `ClockConfigModel` (enums serialized by name).
 *
 * The backend-authored fields ([remoteStyle], [weight], [rotation],
 * [shadowStrength], [datePosition], [dateColor], [customX], [customY]) are
 * gated on [isRemote] exactly as they are in the Flutter painter, so a purely
 * local configuration renders identically to how it did before those fields
 * existed. Unknown keys are ignored, so an older config JSON still parses.
 *
 * [stretchY] is user-only (no backend counterpart, so it is NOT gated on
 * [isRemote]): it lets the clock be stretched taller independent of its
 * width. 1f is the identity transform.
 *
 * [dateScale] is likewise user-only: an independent multiplier on the date's
 * font size, on top of its existing derivation from [sizePx]. 1f is the
 * identity transform.
 */
data class ClockConfig(
    val style: String = "modern",
    val position: String = "top",
    val font: String = "inter",
    val color: Long = 0xFFFFFFFF,
    val sizePx: Float = 65f,
    val opacity: Float = 1f,
    val showShadow: Boolean = true,
    val showGlow: Boolean = false,
    val showStroke: Boolean = false,
    val is24Hour: Boolean = false,
    val showDate: Boolean = true,
    val showSeconds: Boolean = false,
    val enabled: Boolean = true,
    val remoteStyle: String? = null,
    val remoteFont: String? = null,
    val weight: Int = 400,
    val rotation: Float = 0f,
    val shadowStrength: Float = 0.5f,
    val datePosition: String = "below",
    val dateColor: Long? = null,
    val customX: Float? = null,
    val customY: Float? = null,
    val stretchY: Float = 1f,
    val dateScale: Float = 1f,
    /** Named weight preset (Dart enum name, e.g. "bold", "extraLight"). */
    val fontWeightPreset: String = "regular",
    val horizontalScale: Float = 1f,
    /** Dart `ClockTimeLayout` enum name: inline/stacked/stackedCompact/offsetStack/verticalPoster. */
    val timeLayout: String = "inline",
    val showColon: Boolean = true,
    val lineSpacing: Float = 1f,
    val minuteOffsetX: Float = 0f,
    /** Dart `ClockColorMode` enum name: single/split. */
    val colorMode: String = "single",
    val hoursColor: Long? = null,
    val minutesColor: Long? = null,
    /** Dart `ClockColonColor` enum name: hours/minutes/custom. */
    val colonColor: String = "hours",
    val colonColorCustom: Long? = null,

    /** Whether a 12-hour time carries an AM/PM suffix. Backend-authored. */
    val showAmPm: Boolean = false,
    val strokeWidth: Float = 2f,

    /** Independent size factor: size = W * 0.14 * scale * (sizePx / 65). */
    val scale: Float = 1f,
    /** DEPTH only: the foreground copy over the clock is drawn at 1 - depth. */
    val depth: Float = 0.45f,
    val gradientFrom: Long? = null,
    val gradientTo: Long? = null,
    /** CSS angle: 0 bottom->top, 90 left->right, 180 top->bottom. */
    val gradientAngleDeg: Float = 180f,
    /** Alpha of the digits' fill only; the stroke is unaffected. */
    val fillOpacity: Float = 1f,
    val hoursFont: String? = null,
    val minutesFont: String? = null,
    val strokeColor: Long = 0xFF000000,
    /** "behind" | "front". */
    val strokeOrder: String = "behind",
    val fadeAmount: Float = 0f,
    /** "bottom" | "top" | "both". */
    val fadeDirection: String = "bottom",
    val blur: Float = 0f,
    /** Dart enum names "h12" | "h24" | "auto"; null = use [is24Hour]. */
    val hourFormat: String? = null,
) {
    /** True when this config came from the backend rather than local defaults. */
    val isRemote: Boolean get() = remoteStyle != null || remoteFont != null

    /** True when the backend authored an exact position rather than an anchor. */
    val hasCustomPosition: Boolean get() = customX != null && customY != null

    companion object {
        /** Disabled config used whenever no clock was authored at all - see
         * [fromJson]'s own doc for why this must never be the enabled
         * default. */
        val DISABLED = ClockConfig(enabled = false)

        /**
         * A null/empty [json] means "no clock" - a deliberate "Wallpaper
         * Only" apply (or a wallpaper with no authored clock) persists no
         * config at all, exactly like [DepthConfig.fromJson] persists no
         * depth config in the equivalent case. It must NOT fall back to
         * [ClockConfig]'s own enabled-by-default constructor: that silently
         * reintroduces a clock the user explicitly turned off, since
         * "missing config" and "author wants the default clock" are not the
         * same thing. A malformed (but PRESENT) JSON string is a genuinely
         * different case - a clock config did exist and failed to parse -
         * and keeps falling back to the enabled default below, matching the
         * pre-existing behaviour for that error path.
         */
        fun fromJson(json: String?): ClockConfig {
            if (json.isNullOrEmpty()) return DISABLED
            return try {
                val o = JSONObject(json)
                ClockConfig(
                    style = o.optString("style", "modern"),
                    position = o.optString("position", "top"),
                    font = o.optString("font", "inter"),
                    color = o.optLong("color", 0xFFFFFFFF),
                    sizePx = o.optDouble("sizePx", 65.0).toFloat(),
                    opacity = o.optDouble("opacity", 1.0).toFloat(),
                    showShadow = o.optBoolean("showShadow", true),
                    showGlow = o.optBoolean("showGlow", false),
                    showStroke = o.optBoolean("showStroke", false),
                    is24Hour = o.optBoolean("is24Hour", false),
                    showDate = o.optBoolean("showDate", true),
                    showSeconds = o.optBoolean("showSeconds", false),
                    enabled = o.optBoolean("enabled", true),
                    remoteStyle = o.optStringOrNull("remoteStyle"),
                    remoteFont = o.optStringOrNull("remoteFont"),
                    weight = o.optInt("weight", 400).coerceIn(100, 900),
                    rotation = o.optDouble("rotation", 0.0).toFloat()
                        .coerceIn(-180f, 180f),
                    shadowStrength = o.optDouble("shadowStrength", 0.5)
                        .toFloat().coerceIn(0f, 1f),
                    datePosition = o.optString("datePosition", "below"),
                    dateColor = if (o.isNull("dateColor")) null
                    else o.optLong("dateColor"),
                    customX = o.optFloatOrNull("customX"),
                    customY = o.optFloatOrNull("customY"),
                    stretchY = o.optDouble("stretchY", 1.0)
                        .toFloat().coerceIn(1f, 3f),
                    dateScale = o.optDouble("dateScale", 1.0)
                        .toFloat().coerceIn(0.5f, 2f),
                    fontWeightPreset = o.optString("fontWeightPreset", "regular"),
                    horizontalScale = o.optDouble("horizontalScale", 1.0)
                        .toFloat().coerceIn(0.55f, 1.5f),
                    timeLayout = o.optString("timeLayout", "inline"),
                    showColon = o.optBoolean("showColon", true),
                    lineSpacing = o.optDouble("lineSpacing", 1.0)
                        .toFloat().coerceIn(0f, 3f),
                    minuteOffsetX = o.optDouble("minuteOffsetX", 0.0)
                        .toFloat().coerceIn(-1f, 1f),
                    colorMode = o.optString("colorMode", "single"),
                    hoursColor = if (o.isNull("hoursColor")) null
                    else o.optLong("hoursColor"),
                    minutesColor = if (o.isNull("minutesColor")) null
                    else o.optLong("minutesColor"),
                    colonColor = o.optString("colonColor", "hours"),
                    colonColorCustom = if (o.isNull("colonColorCustom")) null
                    else o.optLong("colonColorCustom"),
                    showAmPm = o.optBoolean("showAmPm", false),
                    strokeWidth = o.optDouble("strokeWidth", 2.0)
                        .toFloat().coerceIn(0.5f, 20f),
                    scale = o.optDouble("scale", 1.0).toFloat().coerceIn(0.5f, 3f),
                    depth = o.optDouble("depth", 0.45).toFloat().coerceIn(0f, 1f),
                    gradientFrom = if (o.isNull("gradientFrom")) null else o.optLong("gradientFrom"),
                    gradientTo = if (o.isNull("gradientTo")) null else o.optLong("gradientTo"),
                    gradientAngleDeg = o.optDouble("gradientAngleDeg", 180.0).toFloat(),
                    fillOpacity = o.optDouble("fillOpacity", 1.0).toFloat().coerceIn(0f, 1f),
                    hoursFont = o.optStringOrNull("hoursFont"),
                    minutesFont = o.optStringOrNull("minutesFont"),
                    strokeColor = o.optLong("strokeColor", 0xFF000000),
                    strokeOrder = o.optString("strokeOrder", "behind"),
                    fadeAmount = o.optDouble("fadeAmount", 0.0).toFloat().coerceIn(0f, 1f),
                    fadeDirection = o.optString("fadeDirection", "bottom"),
                    blur = o.optDouble("blur", 0.0).toFloat().coerceIn(0f, 20f),
                    hourFormat = o.optStringOrNull("hourFormat"),
                )
            } catch (e: Exception) {
                ClockConfig()
            }
        }

        private fun JSONObject.optStringOrNull(key: String): String? =
            if (isNull(key)) null else optString(key).takeIf { it.isNotEmpty() }

        private fun JSONObject.optFloatOrNull(key: String): Float? =
            if (isNull(key)) null else optDouble(key).takeIf { !it.isNaN() }?.toFloat()
    }
}

/**
 * Native mirror of the backend `depthConfig`: how the cut-out foreground is
 * placed over the background plate. Offsets are normalized fractions of the
 * surface so one authored value lands identically on any screen.
 */
data class DepthConfig(
    val foregroundScale: Float = 1f,
    val foregroundOffsetX: Float = 0f,
    val foregroundOffsetY: Float = 0f,
    val blurRadius: Float = 0f,
    val shadowStrength: Float = 0f,
) {
    companion object {
        val DEFAULTS = DepthConfig()

        fun fromJson(json: String?): DepthConfig {
            if (json.isNullOrEmpty()) return DEFAULTS
            return try {
                val o = JSONObject(json)
                DepthConfig(
                    foregroundScale = o.optDouble("foregroundScale", 1.0)
                        .toFloat().coerceIn(0.5f, 3f),
                    foregroundOffsetX = o.optDouble("foregroundOffsetX", 0.0)
                        .toFloat().coerceIn(-1f, 1f),
                    foregroundOffsetY = o.optDouble("foregroundOffsetY", 0.0)
                        .toFloat().coerceIn(-1f, 1f),
                    blurRadius = o.optDouble("blurRadius", 0.0)
                        .toFloat().coerceIn(0f, 100f),
                    shadowStrength = o.optDouble("shadowStrength", 0.0)
                        .toFloat().coerceIn(0f, 1f),
                )
            } catch (e: Exception) {
                DEFAULTS
            }
        }
    }
}
