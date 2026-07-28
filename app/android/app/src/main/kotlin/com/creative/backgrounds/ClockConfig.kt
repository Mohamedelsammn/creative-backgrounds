package com.creative.backgrounds

import org.json.JSONObject

/** Native mirror of the Flutter `ClockConfigModel` (enums serialized by name). */
data class ClockConfig(
    val style: String = "modern",
    val position: String = "center",
    val font: String = "inter",
    val color: Long = 0xFFFFFFFF,
    val sizePx: Float = 76f,
    val opacity: Float = 1f,
    val showShadow: Boolean = true,
    val showGlow: Boolean = false,
    val showStroke: Boolean = false,
    val is24Hour: Boolean = false,
    val showDate: Boolean = true,
    val showSeconds: Boolean = false,
) {
    companion object {
        fun fromJson(json: String?): ClockConfig {
            if (json.isNullOrEmpty()) return ClockConfig()
            return try {
                val o = JSONObject(json)
                ClockConfig(
                    style = o.optString("style", "modern"),
                    position = o.optString("position", "center"),
                    font = o.optString("font", "inter"),
                    color = o.optLong("color", 0xFFFFFFFF),
                    sizePx = o.optDouble("sizePx", 76.0).toFloat(),
                    opacity = o.optDouble("opacity", 1.0).toFloat(),
                    showShadow = o.optBoolean("showShadow", true),
                    showGlow = o.optBoolean("showGlow", false),
                    showStroke = o.optBoolean("showStroke", false),
                    is24Hour = o.optBoolean("is24Hour", false),
                    showDate = o.optBoolean("showDate", true),
                    showSeconds = o.optBoolean("showSeconds", false),
                )
            } catch (e: Exception) {
                ClockConfig()
            }
        }
    }
}
