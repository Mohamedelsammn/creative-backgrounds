package com.creative.backgrounds

import com.creative.backgrounds.channels.ClockChannel
import com.creative.backgrounds.channels.TransparentWallpaperChannel
import com.creative.backgrounds.channels.WallpaperChannel
import com.creative.backgrounds.transparent.TransparentPreviewView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private lateinit var transparentChannel: TransparentWallpaperChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WallpaperChannel(this).register(flutterEngine)
        ClockChannel(this).register(flutterEngine)
        transparentChannel = TransparentWallpaperChannel(this)
        transparentChannel.register(flutterEngine)

        // Live camera preview surface for the transparent-wallpaper flow.
        flutterEngine.platformViewsController.registry.registerViewFactory(
            TransparentPreviewView.VIEW_TYPE,
            TransparentPreviewView.Factory(this),
        )
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
