package com.creative.backgrounds.transparent

import android.app.Activity
import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.util.Log
import com.creative.backgrounds.CameraForegroundService
import com.creative.backgrounds.CameraWallpaperService
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.CopyOnWriteArraySet

/**
 * Central controller for the transparent (live rear-camera) wallpaper. All
 * feature logic funnels through here so there is a single owner of state — no
 * duplicated logic across the channel, the service, and the camera engine.
 *
 * The controller does not itself open the camera. In the true-live model the
 * camera is opened by the wallpaper [CameraWallpaperService] engine while it is
 * visible; this controller (a) keeps the `camera`-typed foreground service alive
 * so that access is legal in the background, (b) persists the enabled flag the
 * engine reads, (c) saves/restores the previous wallpaper, and (d) owns the
 * observable [State] machine the UI reflects.
 */
object TransparentWallpaperManager {

    /** Every state the feature can be in (mirrored by the Flutter UI). */
    enum class State {
        IDLE, CHECKING, PERMISSION_NEEDED, PREPARING, PREVIEW, APPLYING,
        RUNNING, PAUSED, STOPPED, ERROR, CAMERA_BUSY, CAMERA_LOST,
        WALLPAPER_REMOVED, RESTORING, COMPLETED
    }

    fun interface Listener {
        fun onState(state: State, error: String?)
    }

    @Volatile
    private var state: State = State.IDLE

    @Volatile
    private var lastError: String? = null

    private val listeners = CopyOnWriteArraySet<Listener>()

    fun currentState(): State = state

    fun lastError(): String? = lastError

    fun isRunning(): Boolean = state == State.RUNNING

    fun addListener(listener: Listener) {
        listeners.add(listener)
        listener.onState(state, lastError) // emit current immediately
    }

    fun removeListener(listener: Listener) {
        listeners.remove(listener)
    }

    /** Updates the state and notifies observers. Safe to call from any thread. */
    fun updateState(newState: State, error: String? = null) {
        state = newState
        lastError = error
        listeners.forEach { it.onState(newState, error) }
    }

    fun isEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_ENABLED, false)

    /**
     * Begins the apply flow: snapshot the current wallpaper for later restore,
     * mark the feature enabled, start the foreground camera service, and open
     * the system live-wallpaper picker targeting [CameraWallpaperService].
     */
    fun start(activity: Activity) {
        Log.d(TAG, "start() — resetting state and beginning apply flow")
        // Clean slate: clear any error/state left by a previous enable cycle so
        // the second Enable starts identically to the first.
        lastError = null
        updateState(State.PREPARING)
        savePreviousWallpaper(activity)
        prefs(activity).edit().putBoolean(KEY_ENABLED, true).apply()
        CameraForegroundService.start(activity)
        updateState(State.APPLYING)
        launchLiveWallpaperPicker(activity)
    }

    /**
     * Fully disables the feature: clear the enabled flag, stop the foreground
     * camera service, and restore the previous wallpaper. The engine, seeing the
     * flag cleared, releases the camera on its next visibility change.
     */
    fun stop(context: Context) {
        Log.d(TAG, "stop() — disabling, stopping FGS, restoring wallpaper")
        updateState(State.RESTORING)
        prefs(context).edit().putBoolean(KEY_ENABLED, false).apply()
        CameraForegroundService.stop(context)
        restorePreviousWallpaper(context)
        updateState(State.STOPPED)
    }

    fun pause() {
        if (state == State.RUNNING) updateState(State.PAUSED)
    }

    fun resume() {
        if (state == State.PAUSED) updateState(State.RUNNING)
    }

    /** Last-resort cleanup (e.g. on unrecoverable error). */
    fun releaseResources(context: Context) {
        CameraForegroundService.stop(context)
    }

    /**
     * Called by the wallpaper engine when it is destroyed while still enabled —
     * i.e. the user replaced our wallpaper from outside the app. Releases the
     * foreground camera service so the camera indicator/notification clear, and
     * reflects the removed state.
     */
    fun handleWallpaperRemoved(context: Context) {
        prefs(context).edit().putBoolean(KEY_ENABLED, false).apply()
        CameraForegroundService.stop(context)
        updateState(State.WALLPAPER_REMOVED)
    }

    // --- Previous-wallpaper save / restore ---------------------------------
    // Best-effort: if the prior wallpaper was itself a live wallpaper it cannot
    // be captured as a bitmap, so restore falls back to clearing to default.

    private fun savePreviousWallpaper(context: Context) {
        try {
            val wm = WallpaperManager.getInstance(context)
            val drawable = wm.drawable ?: return
            val width = drawable.intrinsicWidth.coerceAtLeast(1)
            val height = drawable.intrinsicHeight.coerceAtLeast(1)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, width, height)
            drawable.draw(canvas)
            val file = File(context.filesDir, PREV_WALLPAPER_FILE)
            FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
            bitmap.recycle()
            prefs(context).edit().putString(KEY_PREV_WALLPAPER, file.absolutePath).apply()
        } catch (e: Exception) {
            // Non-fatal: restore will fall back to clearing the wallpaper.
            prefs(context).edit().remove(KEY_PREV_WALLPAPER).apply()
        }
    }

    /** Restores the saved wallpaper without changing the enabled flag. */
    fun restorePreviousWallpaper(context: Context) {
        val wm = WallpaperManager.getInstance(context)
        val path = prefs(context).getString(KEY_PREV_WALLPAPER, null)
        try {
            if (path != null) {
                val bitmap = android.graphics.BitmapFactory.decodeFile(path)
                if (bitmap != null) {
                    wm.setBitmap(bitmap)
                    bitmap.recycle()
                    return
                }
            }
            wm.clear()
        } catch (e: Exception) {
            runCatching { wm.clear() }
        }
    }

    private fun launchLiveWallpaperPicker(activity: Activity) {
        val intent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
            putExtra(
                WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                ComponentName(activity, CameraWallpaperService::class.java),
            )
        }
        activity.startActivity(intent)
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private const val PREFS = "transparent_prefs"
    private const val KEY_ENABLED = "transparent_enabled"
    private const val KEY_PREV_WALLPAPER = "prev_wallpaper_path"
    private const val PREV_WALLPAPER_FILE = "prev_wallpaper.png"
    private const val TAG = "TransparentCam"
}
