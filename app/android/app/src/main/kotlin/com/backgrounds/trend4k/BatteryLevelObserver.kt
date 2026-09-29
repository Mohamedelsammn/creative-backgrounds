package com.backgrounds.trend4k

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager

/**
 * Observes the device's battery level for the `batteryRing` studio widget.
 *
 * Event-driven, not polled: Android already broadcasts
 * [Intent.ACTION_BATTERY_CHANGED] whenever the level moves, so a timer would
 * burn wakeups to learn something the system volunteers. The receiver is
 * registered only while a wallpaper that actually needs it is VISIBLE, so an
 * off-screen wallpaper does no battery work at all.
 *
 * Requires **no permission** - battery level is not private data on Android.
 *
 * Not thread-safe; callers drive it from the wallpaper engine's own thread,
 * which is where the lifecycle callbacks already run.
 */
class BatteryLevelObserver(
    private val context: Context,
    /** Invoked with the new level when it CHANGES, so the caller can redraw.
     * Passing the value avoids callers having to reach back into this object
     * while it is still being constructed. */
    private val onChanged: (Int?) -> Unit,
) {

    /** Current level 0..100, or null when unknown. */
    var level: Int? = null
        private set

    private var receiver: BroadcastReceiver? = null

    val isRegistered: Boolean get() = receiver != null

    /**
     * Starts observing, if not already.
     *
     * `registerReceiver` for a sticky broadcast returns the last value
     * immediately, so the first level is known without waiting for a change -
     * no blank ring on the first frame.
     */
    fun start() {
        if (receiver != null) return
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent != null && apply(intent)) onChanged(level)
            }
        }
        val sticky = runCatching {
            context.registerReceiver(
                r,
                IntentFilter(Intent.ACTION_BATTERY_CHANGED),
            )
        }.getOrElse {
            // Registration can fail while the service is being torn down;
            // the ring simply shows its track until the next start().
            return
        }
        receiver = r
        sticky?.let(::apply)
    }

    /** Stops observing and releases the receiver. Safe to call repeatedly. */
    fun stop() {
        val r = receiver ?: return
        receiver = null
        runCatching { context.unregisterReceiver(r) }
    }

    /**
     * Reads the level out of a battery broadcast.
     *
     * Returns true when the value actually changed, so the caller only redraws
     * on a real change - `ACTION_BATTERY_CHANGED` also fires for temperature
     * and plug events that leave the percentage alone.
     */
    private fun apply(intent: Intent): Boolean {
        val raw = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        val next = percentOf(raw, scale)
        if (next == level) return false
        level = next
        return true
    }

    companion object {
        /**
         * Converts a raw level/scale pair into 0..100, or null when unknown.
         *
         * Pure, so the mapping is testable without a device.
         */
        fun percentOf(raw: Int, scale: Int): Int? {
            if (raw < 0 || scale <= 0) return null
            return ((raw * 100f) / scale).toInt().coerceIn(0, 100)
        }
    }
}
