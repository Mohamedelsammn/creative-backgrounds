package com.creative.backgrounds.channels

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.creative.backgrounds.transparent.CompatibilityChecker
import com.creative.backgrounds.transparent.PermissionManager
import com.creative.backgrounds.transparent.TransparentWallpaperManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Command surface for the Transparent (live rear-camera) Wallpaper feature.
 *
 * Flutter only issues commands; the native side owns all state. A companion
 * [EventChannel] streams every [TransparentWallpaperManager] state change so the
 * UI reflects native truth without polling.
 */
class TransparentWallpaperChannel(private val activity: Activity) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val permissions = PermissionManager(activity)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var eventSink: EventChannel.EventSink? = null
    private val stateListener = TransparentWallpaperManager.Listener { state, error ->
        val payload = mapOf(
            "state" to state.name.lowercase(),
            "error" to error,
        )
        mainHandler.post { eventSink?.success(payload) }
    }

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
        EventChannel(engine.dartExecutor.binaryMessenger, EVENTS)
            .setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkCompatibility" ->
                result.success(CompatibilityChecker(activity).check())
            "getPermissionStatus" -> result.success(permissions.status())
            "requestPermissions" -> permissions.request(result)
            "openAppSettings" -> result.success(permissions.openAppSettings())
            "openBatterySettings" -> result.success(permissions.openBatterySettings())
            "start" -> {
                TransparentWallpaperManager.start(activity)
                result.success(true)
            }
            "stop" -> {
                TransparentWallpaperManager.stop(activity)
                result.success(true)
            }
            "pause" -> {
                TransparentWallpaperManager.pause()
                result.success(true)
            }
            "resume" -> {
                TransparentWallpaperManager.resume()
                result.success(true)
            }
            "restorePreviousWallpaper" -> {
                TransparentWallpaperManager.restorePreviousWallpaper(activity)
                result.success(true)
            }
            "status" -> result.success(statusMap())
            "getSettings" -> result.success(settingsMap())
            "updateSettings" -> {
                val fps = call.argument<Int>("fps")
                if (fps != null) {
                    prefs().edit().putInt("tw_fps", fps).apply()
                }
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun prefs() =
        activity.getSharedPreferences("transparent_prefs", Context.MODE_PRIVATE)

    private fun settingsMap(): Map<String, Any?> = mapOf(
        "fps" to prefs().getInt("tw_fps", 24),
    )

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        // Emits the current state immediately, then on every change.
        TransparentWallpaperManager.addListener(stateListener)
    }

    override fun onCancel(arguments: Any?) {
        TransparentWallpaperManager.removeListener(stateListener)
        eventSink = null
    }

    /** Forwarded from [MainActivity]; returns true when it owns [requestCode]. */
    fun onRequestPermissionsResult(
        requestCode: Int,
        perms: Array<out String>,
    ): Boolean = permissions.onRequestPermissionsResult(requestCode, perms)

    private fun statusMap(): Map<String, Any?> = mapOf(
        "state" to TransparentWallpaperManager.currentState().name.lowercase(),
        "error" to TransparentWallpaperManager.lastError(),
        "running" to TransparentWallpaperManager.isRunning(),
        "enabled" to TransparentWallpaperManager.isEnabled(activity),
    )

    companion object {
        private const val CHANNEL = "com.creative.backgrounds/transparent"
        private const val EVENTS = "com.creative.backgrounds/transparent_events"
    }
}
