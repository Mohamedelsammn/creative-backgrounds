package com.backgrounds.trend4k

import com.backgrounds.trend4k.channels.AdBlockChannel
import com.backgrounds.trend4k.channels.BatteryChannel
import com.backgrounds.trend4k.channels.ClockChannel
import com.backgrounds.trend4k.channels.TransparentWallpaperChannel
import com.backgrounds.trend4k.channels.WallpaperChannel
import com.backgrounds.trend4k.transparent.TransparentPreviewView
import com.backgrounds.trend4k.transparent.TransparentWallpaperManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private lateinit var transparentChannel: TransparentWallpaperChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WallpaperChannel(this).register(flutterEngine)
        ClockChannel(this).register(flutterEngine)
        AdBlockChannel(this).register(flutterEngine)
        BatteryChannel(this).register(flutterEngine)
        transparentChannel = TransparentWallpaperChannel(this)
        transparentChannel.register(flutterEngine)

        // Live camera preview surface for the transparent-wallpaper flow.
        flutterEngine.platformViewsController.registry.registerViewFactory(
            TransparentPreviewView.VIEW_TYPE,
            TransparentPreviewView.Factory(this),
        )

        // MediaPlayer-backed fallback preview for live/video wallpapers, used
        // when video_player's ExoPlayer pipeline fails to initialise the
        // hardware decoder on some devices. See MediaPlayerPreviewView's
        // doc comment for why this exists.
        flutterEngine.platformViewsController.registry.registerViewFactory(
            MediaPlayerPreviewView.VIEW_TYPE,
            MediaPlayerPreviewView.Factory(),
        )
    }

    /**
     * Reconciles the transparent wallpaper with reality every time the app comes
     * back to the foreground.
     *
     * This is the return path from the system wallpaper picker, and the only
     * moment we can learn whether the user actually confirmed. It is also what
     * repairs state after a process kill, where the wallpaper keeps running but
     * the in-memory state machine has reset.
     *
     * Without it the UI can sit on "Preparing..." forever when the user backs
     * out of the picker.
     */
    override fun onResume() {
        super.onResume()
        TransparentWallpaperManager.syncWithSystem(applicationContext)
        LiveWallpaperApplyTracker.syncWithSystem(applicationContext)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // Forward to the transparent-wallpaper permission flow (no-op if not ours).
        transparentChannel.onRequestPermissionsResult(requestCode, permissions)
    }
}
