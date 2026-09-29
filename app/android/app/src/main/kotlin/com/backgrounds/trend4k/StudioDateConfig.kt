package com.backgrounds.trend4k

import org.json.JSONObject

/**
 * The `studio.dateWidget` element, as the native renderers see it.
 *
 * Mirrors Dart's `StudioDateWidget`. [color] is an ARGB int, already converted
 * from the backend's CSS `#RRGGBBAA` byte order by `StudioDesignMapper`, so
 * native never re-parses a colour string and the two sides cannot disagree
 * about byte order.
 */
data class StudioDateConfig(
    val enabled: Boolean,
    val format: String,
    val pattern: String?,
    val locale: String,
    val customX: Float?,
    val customY: Float?,
    val color: Long,
    val scale: Float,
    val font: String,
    val weight: Int,
    val uppercase: Boolean,
    /** top | center | bottom; used when customX/customY are not both set. */
    val position: String = "bottom",
) {
    companion object {
        /**
         * Parses the serialized date widget.
         *
         * Never throws: malformed optional design data must not take down the
         * wallpaper it belongs to.
         */
        fun fromJson(json: String?): StudioDateConfig? {
            if (json.isNullOrBlank()) return null
            return runCatching {
                val o = JSONObject(json)
                if (!o.optBoolean("enabled", false)) return null
                StudioDateConfig(
                    enabled = true,
                    format = o.optString("format", "medium"),
                    pattern = if (o.isNull("pattern")) null
                    else o.optString("pattern").ifBlank { null },
                    locale = o.optString("locale", "en"),
                    customX = optFloatOrNull(o, "customX"),
                    customY = optFloatOrNull(o, "customY"),
                    color = if (o.isNull("color")) 0xFFFFFFFFL
                    else o.optLong("color", 0xFFFFFFFFL),
                    scale = o.optDouble("scale", 1.0).toFloat()
                        .coerceIn(0.1f, 5f),
                    font = o.optString("font", "Inter"),
                    weight = o.optInt("weight", 400).coerceIn(100, 900),
                    uppercase = o.optBoolean("uppercase", false),
                    position = o.optString("position", "bottom"),
                )
            }.getOrNull()
        }

        private fun optFloatOrNull(o: JSONObject, key: String): Float? {
            if (o.isNull(key)) return null
            val v = o.optDouble(key, Double.NaN)
            return if (v.isNaN()) null else v.toFloat().coerceIn(0f, 1f)
        }
    }
}
