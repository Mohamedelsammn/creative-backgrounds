package com.backgrounds.trend4k.transparent

import android.app.Activity
import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.backgrounds.trend4k.CameraForegroundService
import com.backgrounds.trend4k.CameraWallpaperService
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.CopyOnWriteArraySet
import java.util.concurrent.atomic.AtomicInteger

/**
 * Central controller for the transparent (live rear-camera) wallpaper.
 *
 * All feature logic funnels through here so there is a single owner of state.
 * The controller does not open the camera: the wallpaper engine does that while
 * it is visible. This class (a) keeps the `camera`-typed foreground service
 * alive so background access is legal, (b) owns the two persisted flags the
 * engine reads, (c) saves/restores the previous wallpaper, and (d) owns the
 * guarded [State] machine the UI mirrors.
 *
 * ## Two flags, not one
 *
 * [KEY_ENABLED] is the user's durable intent - "the transparent wallpaper is my
 * wallpaper". [KEY_PENDING_APPLY] is the short-lived "I have opened the system
 * picker and am waiting to find out whether they confirmed".
 *
 * Splitting them is what makes cancelling the picker safe: the old code set
 * `enabled = true` *before* the user confirmed, so backing out left the feature
 * permanently "on" with no wallpaper behind it, and the UI stuck on Preparing.
 *
 * ## Why removal detection is not just "the engine died"
 *
 * A `WallpaperService.Engine` is destroyed for many benign reasons - rotation,
 * a configuration change, surface recreation, the launcher restarting, the
 * system recycling engines, and as a normal step of re-applying the same
 * wallpaper. Treating any of those as "the user removed our wallpaper" is what
 * made Enable -> Disable -> Enable fail.
 *
 * So removal is confirmed by evidence, never inferred from a destroy:
 *  1. the engine that died was a real one, not the picker's preview engine;
 *  2. after a short grace period no other real engine has appeared;
 *  3. [WallpaperManager.getWallpaperInfo] says our component is no longer the
 *     live wallpaper.
 *
 * Only all three together clear [KEY_ENABLED].
 */
object TransparentWallpaperManager {

    /**
     * Every state the feature can be in, mirrored by the Flutter UI.
     *
     * Wire names are the lower-cased enum names; the Dart `TwStatus` enum is
     * the exact counterpart.
     */
    enum class State {
        /** Nothing has happened yet this process. */
        IDLE,

        /** Running the device compatibility checks. */
        CHECKING,

        /** The device cannot run the feature at all. Terminal until reinstall. */
        INCOMPATIBLE,

        /** Compatible, but camera/notification permission is missing. */
        PERMISSION_NEEDED,

        /** Compatible and permitted; waiting for the user to start. */
        READY,

        /** Snapshotting the wallpaper and starting the foreground service. */
        PREPARING,

        /** The in-app camera preview is on screen. */
        PREVIEW,

        /** The system wallpaper picker is open; the outcome is unknown. */
        APPLYING,

        /** Our wallpaper is set and the camera is streaming. */
        RUNNING,

        /** Set, but hidden right now (screen off, another app foreground). */
        PAUSED,

        /** Tearing down after the user disabled the feature. */
        STOPPING,

        /** Restoring the previous wallpaper. */
        RESTORING,

        /** Fully disabled. */
        STOPPED,

        /** A transient camera failure; a retry is scheduled. */
        RECOVERING,

        /** The camera is held by another app. */
        CAMERA_BUSY,

        /** The camera disconnected mid-stream. */
        CAMERA_LOST,

        /** Our wallpaper was replaced from outside the app. */
        WALLPAPER_REMOVED,

        /** An unrecoverable error; [lastError] explains it. */
        ERROR,

        /** The flow finished successfully and the UI has acknowledged it. */
        COMPLETED,
        ;

        /** States from which the camera should be streaming. */
        val isActive: Boolean
            get() = this == RUNNING || this == PAUSED || this == RECOVERING

        /** States the user cannot leave without starting over. */
        val isTerminal: Boolean
            get() = this == STOPPED || this == INCOMPATIBLE ||
                this == WALLPAPER_REMOVED || this == COMPLETED
    }

    fun interface Listener {
        fun onState(state: State, error: String?)
    }

    @Volatile
    private var state: State = State.IDLE

    @Volatile
    private var lastError: String? = null

    private val listeners = CopyOnWriteArraySet<Listener>()
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * How many **real** (non-preview) wallpaper engines are alive. Guards the
     * difference between an engine being recreated and our wallpaper being
     * replaced.
     */
    private val liveEngines = AtomicInteger(0)

    private var pendingRemovalCheck: Runnable? = null
    private var pendingApplyTimeout: Runnable? = null

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

    /**
     * Moves to [newState] if the transition is legal, and notifies observers.
     * Safe to call from any thread.
     *
     * Guarding matters because three different places report state
     * asynchronously (this controller, the camera engine's success callback,
     * and the error handler). Without it, a `RUNNING` callback that lands just
     * after the user pressed Disable would leave the impossible combination of
     * `state = RUNNING` with `enabled = false`.
     */
    @Synchronized
    fun updateState(newState: State, error: String? = null) {
        if (!canTransition(state, newState)) {
            Log.d(TAG, "ignored illegal transition ${state} -> $newState")
            return
        }
        Log.d(TAG, "state ${state} -> $newState${error?.let { " ($it)" } ?: ""}")
        state = newState
        lastError = error
        listeners.forEach { it.onState(newState, error) }
    }

    /**
     * The transition table. Only genuinely contradictory moves are rejected -
     * this is a safety net against races, not a straitjacket.
     */
    private fun canTransition(from: State, to: State): Boolean {
        if (from == to) return false // no-op, do not re-notify
        return when (to) {
            // A late "camera is streaming" callback must not resurrect the
            // feature after the user disabled it or the wallpaper was replaced.
            State.RUNNING -> from != State.STOPPED &&
                from != State.STOPPING &&
                from != State.RESTORING &&
                from != State.WALLPAPER_REMOVED &&
                from != State.INCOMPATIBLE

            // Likewise a late camera error must not overwrite a clean stop.
            State.CAMERA_BUSY, State.CAMERA_LOST, State.RECOVERING, State.ERROR ->
                from != State.STOPPED && from != State.STOPPING &&
                    from != State.RESTORING

            State.PAUSED -> from.isActive

            // Everything else (user-initiated moves, teardown, reporting) is
            // always allowed: the user must never be locked out of Disable.
            else -> true
        }
    }

    // --- persisted flags ---------------------------------------------------

    /** The user's durable intent: the transparent wallpaper is their wallpaper. */
    fun isEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_ENABLED, false)

    /** True while the system picker is open and the outcome is still unknown. */
    fun isPendingApply(context: Context): Boolean =
        prefs(context).getBoolean(KEY_PENDING_APPLY, false)

    /**
     * Whether the wallpaper engine should be driving the camera.
     *
     * True during the pending-apply window as well, so the picker's preview
     * engine shows a live camera feed rather than a black rectangle - which is
     * what the user is being asked to approve.
     */
    fun shouldRunCamera(context: Context): Boolean =
        isEnabled(context) || isPendingApply(context)

    // --- apply flow --------------------------------------------------------

    /**
     * Begins the apply flow: snapshot the current wallpaper, mark the apply as
     * pending (NOT enabled - that waits for confirmation), start the foreground
     * camera service, and open the system live-wallpaper picker.
     *
     * [confirmApplyOutcome] must be called when the app regains focus; a
     * timeout is armed here so the UI can never sit on "Preparing" forever even
     * if that call never arrives.
     */
    fun start(activity: Activity) {
        Log.d(TAG, "start() - beginning apply flow")
        lastError = null
        updateState(State.PREPARING)

        savePreviousWallpaper(activity)
        prefs(activity).edit().putBoolean(KEY_PENDING_APPLY, true).apply()
        CameraForegroundService.start(activity)

        updateState(State.APPLYING)
        armApplyTimeout(activity.applicationContext)

        if (!launchLiveWallpaperPicker(activity)) {
            // No picker on this device: fail immediately and visibly instead of
            // leaving the user staring at a spinner.
            cancelApplyTimeout()
            prefs(activity).edit().putBoolean(KEY_PENDING_APPLY, false).apply()
            CameraForegroundService.stop(activity)
            updateState(
                State.ERROR,
                "This device has no live wallpaper picker, so the transparent " +
                    "wallpaper cannot be applied here.",
            )
        }
    }

    /**
     * Resolves a pending apply by asking the system what the wallpaper actually
     * is. Called when the activity regains focus after the picker closes.
     *
     * This is the only place [KEY_ENABLED] is set: the feature turns on because
     * the system confirms our wallpaper is live, never because we asked for it.
     */
    fun confirmApplyOutcome(context: Context) {
        if (!isPendingApply(context)) return
        cancelApplyTimeout()

        val applied = isOurWallpaperActive(context)
        prefs(context).edit()
            .putBoolean(KEY_PENDING_APPLY, false)
            .putBoolean(KEY_ENABLED, applied)
            .apply()

        if (applied) {
            Log.d(TAG, "apply confirmed - our wallpaper is live")
            // The engine reports RUNNING once frames actually flow; until then
            // APPLYING is still the honest state.
            if (state != State.RUNNING) updateState(State.APPLYING)
        } else {
            Log.d(TAG, "apply cancelled - wallpaper is not ours")
            CameraForegroundService.stop(context)
            updateState(State.STOPPED)
        }
    }

    /**
     * Safety net for the apply flow. If the outcome is never confirmed - the
     * user wandered off, the picker crashed, the OEM never returned focus - the
     * pending flag is cleared and the UI is told, rather than being left on
     * "Preparing..." indefinitely.
     */
    private fun armApplyTimeout(context: Context) {
        cancelApplyTimeout()
        val runnable = Runnable {
            if (!isPendingApply(context)) return@Runnable
            Log.w(TAG, "apply timed out after ${APPLY_TIMEOUT_MS}ms")
            // Ask the system one last time before giving up: on some OEMs the
            // wallpaper is set but focus never came back to us.
            if (isOurWallpaperActive(context)) {
                confirmApplyOutcome(context)
                return@Runnable
            }
            prefs(context).edit()
                .putBoolean(KEY_PENDING_APPLY, false)
                .putBoolean(KEY_ENABLED, false)
                .apply()
            CameraForegroundService.stop(context)
            updateState(
                State.ERROR,
                "Setting the wallpaper did not complete. Please try again.",
            )
        }
        pendingApplyTimeout = runnable
        mainHandler.postDelayed(runnable, APPLY_TIMEOUT_MS)
    }

    private fun cancelApplyTimeout() {
        pendingApplyTimeout?.let { mainHandler.removeCallbacks(it) }
        pendingApplyTimeout = null
    }

    // --- stop flow ---------------------------------------------------------

    /**
     * Fully disables the feature: clear both flags, stop the foreground camera
     * service, and restore the previous wallpaper. The engine, seeing the flags
     * cleared, releases the camera.
     *
     * [onComplete] fires on the main thread once the restore finishes. The
     * restore itself runs off the main thread because it decodes and uploads a
     * full-screen bitmap.
     */
    fun stop(context: Context, onComplete: (() -> Unit)? = null) {
        Log.d(TAG, "stop() - disabling")
        cancelApplyTimeout()
        cancelRemovalCheck()

        // Clear intent FIRST so any engine still running bails out on its next
        // callback instead of racing the teardown.
        prefs(context).edit()
            .putBoolean(KEY_ENABLED, false)
            .putBoolean(KEY_PENDING_APPLY, false)
            .apply()

        updateState(State.STOPPING)
        CameraForegroundService.stop(context)
        updateState(State.RESTORING)

        Thread {
            restorePreviousWallpaper(context)
            mainHandler.post {
                updateState(State.STOPPED)
                onComplete?.invoke()
            }
        }.start()
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

    // --- engine lifecycle bookkeeping --------------------------------------

    /**
     * Called by a **real** (non-preview) wallpaper engine when it is created.
     *
     * Cancels any pending removal check: a new engine appearing right after an
     * old one died is a recreation, not a removal.
     */
    fun onRealEngineCreated(context: Context) {
        val count = liveEngines.incrementAndGet()
        Log.d(TAG, "real engine created (live=$count)")
        cancelRemovalCheck()

        // An engine existing at all proves the wallpaper is ours, which is the
        // strongest possible confirmation of a pending apply.
        if (isPendingApply(context)) confirmApplyOutcome(context)
    }

    /**
     * Called by a **real** wallpaper engine when it is destroyed.
     *
     * Schedules - never performs - the removal decision. See the class docs for
     * why a destroy on its own proves nothing.
     */
    fun onRealEngineDestroyed(context: Context) {
        val count = liveEngines.decrementAndGet().coerceAtLeast(0)
        Log.d(TAG, "real engine destroyed (live=$count)")
        if (!isEnabled(context)) return

        cancelRemovalCheck()
        val runnable = Runnable {
            pendingRemovalCheck = null
            // Another engine took over in the meantime: this was a recreation.
            if (liveEngines.get() > 0) {
                Log.d(TAG, "removal check: another engine is live - recreation")
                return@Runnable
            }
            // The system is the authority on what the wallpaper actually is.
            if (isOurWallpaperActive(context)) {
                Log.d(TAG, "removal check: still our wallpaper - no removal")
                return@Runnable
            }
            Log.d(TAG, "removal check: wallpaper replaced externally")
            handleWallpaperRemoved(context)
        }
        pendingRemovalCheck = runnable
        mainHandler.postDelayed(runnable, REMOVAL_GRACE_MS)
    }

    private fun cancelRemovalCheck() {
        pendingRemovalCheck?.let { mainHandler.removeCallbacks(it) }
        pendingRemovalCheck = null
    }

    /**
     * Confirmed: the user replaced our wallpaper from outside the app. Releases
     * the foreground camera service so the camera indicator clears, and records
     * the state.
     */
    private fun handleWallpaperRemoved(context: Context) {
        prefs(context).edit()
            .putBoolean(KEY_ENABLED, false)
            .putBoolean(KEY_PENDING_APPLY, false)
            .apply()
        CameraForegroundService.stop(context)
        updateState(State.WALLPAPER_REMOVED)
    }

    /**
     * Whether our [CameraWallpaperService] is the live wallpaper right now, as
     * reported by the system. The single source of truth for "is the feature
     * actually applied".
     */
    fun isOurWallpaperActive(context: Context): Boolean = try {
        val info = WallpaperManager.getInstance(context).wallpaperInfo
        info != null &&
            info.packageName == context.packageName &&
            info.serviceName == CameraWallpaperService::class.java.name
    } catch (e: Exception) {
        Log.w(TAG, "getWallpaperInfo failed: ${e.message}")
        false
    }

    /**
     * Reconciles in-memory state with reality. Called on cold start and on
     * every activity resume, because the process can be killed while the
     * wallpaper keeps running - leaving `state = IDLE` while the camera streams.
     */
    fun syncWithSystem(context: Context) {
        if (isPendingApply(context)) {
            confirmApplyOutcome(context)
            return
        }
        val active = isOurWallpaperActive(context)
        val enabled = isEnabled(context)

        if (enabled && !active) {
            // Replaced while we were not looking.
            handleWallpaperRemoved(context)
            return
        }
        if (!enabled && active) {
            // Applied out-of-band (e.g. from system settings): adopt it rather
            // than leaving the UI insisting the feature is off.
            prefs(context).edit().putBoolean(KEY_ENABLED, true).apply()
        }
        if (active && !state.isActive) {
            updateState(State.RUNNING)
        } else if (!active && state.isActive) {
            updateState(State.STOPPED)
        }
    }

    // --- Previous-wallpaper save / restore ---------------------------------
    // Best-effort: if the prior wallpaper was itself a live wallpaper it cannot
    // be captured as a bitmap, so restore falls back to clearing to default.

    private fun savePreviousWallpaper(context: Context) {
        try {
            // A live wallpaper cannot be snapshotted meaningfully - drawing it
            // yields one arbitrary frame. Record that there is nothing to
            // restore rather than saving a misleading still.
            if (WallpaperManager.getInstance(context).wallpaperInfo != null) {
                prefs(context).edit().remove(KEY_PREV_WALLPAPER).apply()
                return
            }
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
            Log.w(TAG, "could not snapshot previous wallpaper: ${e.message}")
            prefs(context).edit().remove(KEY_PREV_WALLPAPER).apply()
        }
    }

    /**
     * Restores the saved wallpaper without changing the enabled flag.
     *
     * Decodes and uploads a full-screen bitmap, so callers must keep this off
     * the main thread.
     */
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
            Log.w(TAG, "restore failed: ${e.message}")
            runCatching { wm.clear() }
        }
    }

    /** Returns false when the device has no live-wallpaper picker. */
    private fun launchLiveWallpaperPicker(activity: Activity): Boolean {
        val intent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
            putExtra(
                WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                ComponentName(activity, CameraWallpaperService::class.java),
            )
        }
        return try {
            activity.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "no live wallpaper picker: ${e.message}")
            false
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private const val PREFS = "transparent_prefs"
    private const val KEY_ENABLED = "transparent_enabled"
    private const val KEY_PENDING_APPLY = "transparent_pending_apply"
    private const val KEY_PREV_WALLPAPER = "prev_wallpaper_path"
    private const val PREV_WALLPAPER_FILE = "prev_wallpaper.png"

    /**
     * How long to wait after a real engine dies before deciding the wallpaper
     * was removed. Long enough to cover a rotation or configuration change
     * (which recreate the engine almost immediately), short enough that the UI
     * reflects a genuine removal promptly.
     */
    private const val REMOVAL_GRACE_MS = 2_000L

    /** Upper bound on how long the UI may sit in APPLYING. */
    private const val APPLY_TIMEOUT_MS = 90_000L

    private const val TAG = "TransparentCam"
}
