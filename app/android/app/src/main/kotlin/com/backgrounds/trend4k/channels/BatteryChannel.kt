package com.backgrounds.trend4k.channels

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import com.backgrounds.trend4k.BatteryLevelObserver
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Reports the device's current battery level for the `batteryRing` studio
 * widget.
 *
 * Uses [BatteryManager.BATTERY_PROPERTY_CAPACITY], which needs **no
 * permission** at all - the level is not private data on Android. Nothing here
 * requests a dangerous permission, and no location or network access is
 * involved.
 *
 * A read failure resolves with `null` rather than an error, so a wallpaper
 * whose design includes a battery ring still renders (the ring simply shows no
 * level) instead of surfacing a platform exception.
 */
class BatteryChannel(private val context: Context) :
    MethodChannel.MethodCallHandler {

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "level" -> result.success(readLevel(context))
            else -> result.notImplemented()
        }
    }

    companion object {
        private const val CHANNEL = "com.backgrounds.trend4k/battery"

        /**
         * The battery level as 0..100, or null when it cannot be read.
         *
         * Reads the STICKY `ACTION_BATTERY_CHANGED` broadcast - the same
         * source [BatteryLevelObserver] uses for the applied wallpaper, and
         * the same one the system status bar shows. That matters for parity:
         * `BATTERY_PROPERTY_CAPACITY` is a different API backed by sysfs, and
         * the two can disagree (an emulator's `dumpsys battery set level`
         * overrides the broadcast but not sysfs). Reading one source
         * everywhere is what keeps the Details preview and the applied
         * wallpaper showing the same number.
         *
         * Falls back to `BATTERY_PROPERTY_CAPACITY` only when no sticky
         * broadcast is available.
         */
        fun readLevel(context: Context): Int? {
            val sticky = runCatching {
                context.registerReceiver(
                    null,
                    IntentFilter(Intent.ACTION_BATTERY_CHANGED),
                )
            }.getOrNull()
            if (sticky != null) {
                val level = BatteryLevelObserver.percentOf(
                    sticky.getIntExtra(BatteryManager.EXTRA_LEVEL, -1),
                    sticky.getIntExtra(BatteryManager.EXTRA_SCALE, -1),
                )
                if (level != null) return level
            }

            val manager = context.getSystemService(Context.BATTERY_SERVICE)
                as? BatteryManager ?: return null
            val level = runCatching {
                manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            }.getOrNull() ?: return null
            // The API returns Integer.MIN_VALUE when the property is not
            // supported, so anything outside 0..100 is "unknown", not a level.
            return if (level in 0..100) level else null
        }
    }
}
