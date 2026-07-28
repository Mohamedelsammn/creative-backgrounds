package com.creative.backgrounds.channels

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Persists the clock config to SharedPreferences so the native renderers
 * (`ClockRenderer` / `LiveWallpaperService`) can read it.
 */
class ClockChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val prefs = context.getSharedPreferences("clock_prefs", Context.MODE_PRIVATE)
        when (call.method) {
            "saveClockConfig" -> {
                val json = call.arguments as? String
                prefs.edit().putString("clock_config_json", json).apply()
                result.success(true)
            }
            "clearClockConfig" -> {
                prefs.edit().remove("clock_config_json").apply()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        private const val CHANNEL = "com.creative.backgrounds/clock"
    }
}
