package com.backgrounds.trend4k

import org.json.JSONArray
import org.json.JSONObject

/**
 * A studio widget the native renderers know how to draw.
 *
 * Mirrors Dart's `StudioWidget` sealed type. The backend's `kind` vocabulary is
 * open-ended, so an unrecognised kind is dropped at parse time rather than
 * represented here - exactly as the Dart mapper does, so the two sides agree on
 * what is renderable.
 */
sealed class StudioWidgetConfig {

    /**
     * A ring showing the device's current battery level.
     *
     * Every property here is one the production backend actually authors (see
     * `docs/DESIGN_RENDERING_CONTRACT.md`): `customX`, `customY`, `color`,
     * `scale`, `rotation`, `anchor`, `showPercentage`. Nothing is invented.
     *
     * [color] is an ARGB int, already converted from the backend's CSS
     * `#RRGGBBAA` byte order by the Dart mapper - the same value the Flutter
     * preview drew with, so the two cannot disagree about byte order.
     */
    data class BatteryRing(
        val customX: Float?,
        val customY: Float?,
        val color: Long,
        val scale: Float,
        val rotation: Float,
        val anchor: String,
        val showPercentage: Boolean,
    ) : StudioWidgetConfig()

    companion object {
        /**
         * Parses the serialized `widgets` array.
         *
         * Never throws: malformed optional design data must not take down the
         * wallpaper it belongs to. An unparseable array, a non-object entry or
         * an unknown `kind` each yield "nothing to draw" rather than an error.
         */
        fun listFromJson(json: String?): List<StudioWidgetConfig> {
            if (json.isNullOrBlank()) return emptyList()
            return runCatching {
                val array = JSONArray(json)
                val out = mutableListOf<StudioWidgetConfig>()
                for (i in 0 until array.length()) {
                    val o = array.optJSONObject(i) ?: continue
                    parse(o)?.let(out::add)
                }
                out.toList()
            }.getOrElse { emptyList() }
        }

        private fun parse(o: JSONObject): StudioWidgetConfig? =
            when (o.optString("kind")) {
                "batteryRing" -> BatteryRing(
                    customX = optFloatOrNull(o, "customX"),
                    customY = optFloatOrNull(o, "customY"),
                    color = if (o.isNull("color")) 0xFFFFFFFFL
                    else o.optLong("color", 0xFFFFFFFFL),
                    scale = o.optDouble("scale", 1.0).toFloat()
                        .coerceIn(0.1f, 5f),
                    rotation = o.optDouble("rotation", 0.0).toFloat()
                        .coerceIn(-180f, 180f),
                    anchor = o.optString("anchor", "top"),
                    showPercentage = o.optBoolean("showPercentage", true),
                )
                // A newer backend element this build cannot draw. Skipping it
                // keeps the rest of the design renderable.
                else -> null
            }

        private fun optFloatOrNull(o: JSONObject, key: String): Float? {
            if (o.isNull(key)) return null
            val v = o.optDouble(key, Double.NaN)
            return if (v.isNaN()) null else v.toFloat().coerceIn(0f, 1f)
        }
    }
}
