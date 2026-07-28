package com.creative.backgrounds

import android.app.WallpaperManager
import android.content.Context
import android.graphics.BitmapFactory

/**
 * Applies a plain (static) wallpaper via [WallpaperManager.setBitmap]. Clock /
 * depth wallpapers go through the live-wallpaper path instead. The bitmap is
 * decoded from a file path that Flutter downloaded — no networking here.
 */
object WallpaperApplyService {

    fun applyStatic(context: Context, imagePath: String, destination: String): Boolean {
        val bitmap = BitmapFactory.decodeFile(imagePath) ?: return false
        return try {
            val wm = WallpaperManager.getInstance(context)
            if (!wm.isWallpaperSupported) return false
            val flags = when (destination) {
                "homeScreen" -> WallpaperManager.FLAG_SYSTEM
                "lockScreen" -> WallpaperManager.FLAG_LOCK
                else -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
            }
            wm.setBitmap(bitmap, null, true, flags)
            true
        } catch (e: Exception) {
            false
        } finally {
            bitmap.recycle()
        }
    }
}
