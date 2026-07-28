package com.creative.backgrounds.channels

import android.app.Activity
import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.creative.backgrounds.LiveWallpaperService
import com.creative.backgrounds.WallpaperApplyService
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
            // SET_WALLPAPER is a normal install-time permission — always granted.
            "requestWallpaperPermission" -> result.success(true)
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

        if (imagePath == null) {
            result.success(false)
            return
        }

        if (isLive) {
            persistLiveAssets(imagePath, maskPath, depthEnabled, clockConfig)
            launchLiveWallpaperPicker()
            // The system picker handles final confirmation.
            result.success(true)
        } else {
            Thread {
                val ok = WallpaperApplyService.applyStatic(activity, imagePath, destination)
                mainHandler.post { result.success(ok) }
            }.start()
        }
    }

    private fun persistLiveAssets(
        imagePath: String,
        maskPath: String?,
        depthEnabled: Boolean,
        clockConfig: String?,
    ) {
        val prefs = activity.getSharedPreferences("clock_prefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString("live_bg_path", imagePath)
            putString("live_mask_path", maskPath)
            putBoolean("live_depth_enabled", depthEnabled)
            if (clockConfig != null) putString("clock_config_json", clockConfig)
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
        activity.startActivity(intent)
    }

    companion object {
        private const val CHANNEL = "com.creative.backgrounds/wallpaper"
    }
}
