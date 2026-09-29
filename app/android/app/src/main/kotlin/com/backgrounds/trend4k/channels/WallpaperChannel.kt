package com.backgrounds.trend4k.channels

import android.app.Activity
import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.backgrounds.trend4k.LiveWallpaperApplyTracker
import com.backgrounds.trend4k.LiveWallpaperService
import com.backgrounds.trend4k.VideoWallpaperService
import com.backgrounds.trend4k.WallpaperApplyService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles wallpaper apply requests. Plain images are applied silently via
 * [WallpaperApplyService]; clock/depth wallpapers persist their assets and open
 * the system live-wallpaper picker for [LiveWallpaperService].
 */
class WallpaperChannel(private val activity: Activity) :
    MethodChannel.MethodCallHandler {

    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "applyWallpaper" -> applyWallpaper(call, result)
            "applyVideoWallpaper" -> applyVideoWallpaper(call, result)
            // SET_WALLPAPER is a normal install-time permission — always granted.
            "requestWallpaperPermission" -> result.success(true)
            "consumePendingApplyOutcome" ->
                result.success(LiveWallpaperApplyTracker.consumeOutcome(activity))
            else -> result.notImplemented()
        }
    }

    private fun applyWallpaper(call: MethodCall, result: MethodChannel.Result) {
        val imagePath = call.argument<String>("imagePath")
        val destination = call.argument<String>("destination") ?: "both"
        val isLive = call.argument<Boolean>("isLive") ?: false
        val clockConfig = call.argument<String>("clockConfig")
        val depthEnabled = call.argument<Boolean>("depthEnabled") ?: false
        val maskPath = call.argument<String>("maskPath")
        val depthConfig = call.argument<String>("depthConfig")
        val widgets = call.argument<String>("widgets")
        val dateWidget = call.argument<String>("dateWidget")

        if (imagePath == null) {
            result.success(false)
            return
        }

        if (isLive) {
            persistLiveAssets(
                imagePath, maskPath, depthEnabled, clockConfig, depthConfig,
                widgets, dateWidget,
            )
            launchLiveWallpaperPicker()
            // The system picker handles final confirmation.
            result.success(true)
        } else {
            Thread {
                // Top-level boundary for this thread: WallpaperApplyService
                // .applyStatic already guards its own known failure modes
                // (decode failure, OOM during decode, setBitmap throwing), but
                // this outer catch is the difference between "applyWallpaper
                // resolves false" and "an uncaught exception on this background
                // Thread crashes the whole process" for anything unforeseen -
                // an uncaught Throwable on a plain Thread has no handler here,
                // and previously took the app down before `result.success()`
                // could ever be posted back, leaving the Dart await hanging
                // and the next launch stuck (black screen, app restart,
                // splash never leaves).
                val ok = try {
                    WallpaperApplyService.applyStatic(activity, imagePath, destination)
                } catch (e: Throwable) {
                    false
                }
                mainHandler.post { result.success(ok) }
            }.start()
        }
    }

    /**
     * Applies a looping video wallpaper. The file is already on disk (Flutter
     * downloaded it); we persist the path and hand off to the system picker,
     * which is the only way Android lets an app install a live wallpaper.
     */
    private fun applyVideoWallpaper(call: MethodCall, result: MethodChannel.Result) {
        val videoPath = call.argument<String>("videoPath")
        val posterPath = call.argument<String>("posterPath")
        val clockConfig = call.argument<String>("clockConfig")
        val widgets = call.argument<String>("widgets")
        val dateWidget = call.argument<String>("dateWidget")
        if (videoPath.isNullOrEmpty()) {
            result.success(false)
            return
        }
        activity.getSharedPreferences(VideoWallpaperService.PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(VideoWallpaperService.KEY_VIDEO_PATH, videoPath)
            .putString(VideoWallpaperService.KEY_POSTER_PATH, posterPath)
            // Always written, even when null, so re-applying without a clock
            // clears a previously configured one rather than leaving it drawn
            // on top of the new clip.
            .putString(VideoWallpaperService.KEY_CLOCK_CONFIG_JSON, clockConfig)
            .putString(VideoWallpaperService.KEY_WIDGETS_JSON, widgets)
            .putString(VideoWallpaperService.KEY_DATE_WIDGET_JSON, dateWidget)
            .apply()

        val intent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
            putExtra(
                WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                ComponentName(activity, VideoWallpaperService::class.java),
            )
        }
        return try {
            LiveWallpaperApplyTracker.markPending(activity)
            activity.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            // No live-wallpaper picker on this device/ROM.
            result.success(false)
        }
    }

    private fun persistLiveAssets(
        imagePath: String,
        maskPath: String?,
        depthEnabled: Boolean,
        clockConfig: String?,
        depthConfig: String?,
        widgets: String?,
        dateWidget: String?,
    ) {
        val prefs = activity.getSharedPreferences("clock_prefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString("live_bg_path", imagePath)
            putString("live_mask_path", maskPath)
            putBoolean("live_depth_enabled", depthEnabled)
            // Always written, even when null, so a stale clock from a
            // previously applied wallpaper is cleared when this one
            // authored none - matches depthConfig's existing behaviour below.
            putString("clock_config_json", clockConfig)
            // Always write the depth config, so a stale one from a previously
            // applied wallpaper is cleared when this one authored none.
            putString("depth_config_json", depthConfig)
            // Same rule for the authored widgets: always written, so a ring
            // from a previously applied wallpaper cannot survive onto one that
            // authored none (or onto a "Wallpaper Only" apply).
            putString(LiveWallpaperService.KEY_WIDGETS_JSON, widgets)
            putString(LiveWallpaperService.KEY_DATE_WIDGET_JSON, dateWidget)
            apply()
        }
    }

    private fun launchLiveWallpaperPicker() {
        val intent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
            putExtra(
                WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                ComponentName(activity, LiveWallpaperService::class.java)
            )
        }
        LiveWallpaperApplyTracker.markPending(activity)
        activity.startActivity(intent)
    }

    companion object {
        private const val CHANNEL = "com.backgrounds.trend4k/wallpaper"
    }
}
