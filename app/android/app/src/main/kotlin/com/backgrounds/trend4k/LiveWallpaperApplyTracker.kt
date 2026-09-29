package com.backgrounds.trend4k

import android.app.WallpaperManager
import android.content.Context

/**
 * Tracks the outcome of the system live-wallpaper picker for the clock/depth
 * and video apply paths ([LiveWallpaperService], [VideoWallpaperService]).
 *
 * [WallpaperChannel.applyWallpaper]/`applyVideoWallpaper` only ever
 * `startActivity` the system picker and report success immediately - Android
 * gives no `startActivityForResult`-style callback for
 * `ACTION_CHANGE_LIVE_WALLPAPER`, so that is the only thing the app can know
 * at that moment. Without this tracker, nothing ever learns whether the user
 * actually confirmed, backed out, or the picker failed, which is what read as
 * the app "getting stuck" in the picker: the app had already moved on and had
 * no way to reconcile what happened after.
 *
 * Mirrors [com.backgrounds.trend4k.transparent.TransparentWallpaperManager]'s
 * proven pending/confirm pattern for the same class of problem, applied here
 * to the clock/depth/video picker instead of the transparent one.
 */
object LiveWallpaperApplyTracker {
    private const val PREFS = "live_wallpaper_apply_tracker"
    private const val KEY_PENDING = "pending"
    private const val KEY_OUTCOME = "outcome"

    private const val OUTCOME_NONE = "none"
    private const val OUTCOME_APPLIED = "applied"
    private const val OUTCOME_CANCELLED = "cancelled"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Call right before launching the system picker intent. */
    fun markPending(context: Context) {
        prefs(context).edit()
            .putBoolean(KEY_PENDING, true)
            .putString(KEY_OUTCOME, OUTCOME_NONE)
            .apply()
    }

    /**
     * Reconciles a pending apply with reality. Call from `Activity.onResume` -
     * that is the only moment after the picker closes that the app runs again.
     * Safe to call unconditionally; a no-op when nothing is pending.
     */
    fun syncWithSystem(context: Context) {
        if (!prefs(context).getBoolean(KEY_PENDING, false)) return

        val applied = isOurWallpaperActive(context)
        prefs(context).edit()
            .putBoolean(KEY_PENDING, false)
            .putString(KEY_OUTCOME, if (applied) OUTCOME_APPLIED else OUTCOME_CANCELLED)
            .apply()
    }

    /**
     * Returns the last apply outcome ("applied"/"cancelled"/"none") and clears
     * it - a one-shot read so the same outcome is never reported twice (e.g. on
     * a second resume with nothing new having happened).
     */
    fun consumeOutcome(context: Context): String {
        val outcome = prefs(context).getString(KEY_OUTCOME, OUTCOME_NONE) ?: OUTCOME_NONE
        if (outcome != OUTCOME_NONE) {
            prefs(context).edit().putString(KEY_OUTCOME, OUTCOME_NONE).apply()
        }
        return outcome
    }

    private fun isOurWallpaperActive(context: Context): Boolean = try {
        val info = WallpaperManager.getInstance(context).wallpaperInfo
        info != null &&
            info.packageName == context.packageName &&
            (info.serviceName == LiveWallpaperService::class.java.name ||
                info.serviceName == VideoWallpaperService::class.java.name)
    } catch (e: Exception) {
        false
    }
}
