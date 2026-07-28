package com.creative.backgrounds

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import java.util.Calendar

/**
 * Composites a wallpaper into a single bitmap: background → (optional clock) →
 * (optional foreground subject). Used for static depth snapshots; the live
 * wallpaper draws the same layers per-frame.
 */
object DepthCompositor {

    fun compositeWallpaper(
        context: Context,
        background: Bitmap,
        foreground: Bitmap?,
        clockConfig: ClockConfig?,
        screenWidth: Int,
        screenHeight: Int,
    ): Bitmap {
        val output = Bitmap.createBitmap(screenWidth, screenHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG)

        drawCoverBitmap(canvas, background, screenWidth, screenHeight, paint)

        if (clockConfig != null) {
            ClockRenderer(context).render(
                canvas, screenWidth, screenHeight, Calendar.getInstance(), clockConfig
            )
        }

        // Foreground subject on top of the clock (depth effect). If null, the
        // clock simply sits on the background (graceful fallback).
        if (foreground != null) {
            drawCoverBitmap(canvas, foreground, screenWidth, screenHeight, paint)
        }

        return output
    }

    /** Draws [bitmap] scaled to cover the target rect (center-crop). */
    private fun drawCoverBitmap(
        canvas: Canvas,
        bitmap: Bitmap,
        targetW: Int,
        targetH: Int,
        paint: Paint,
    ) {
        val scale = maxOf(
            targetW.toFloat() / bitmap.width,
            targetH.toFloat() / bitmap.height
        )
        val scaledW = (bitmap.width * scale).toInt()
        val scaledH = (bitmap.height * scale).toInt()
        val left = (targetW - scaledW) / 2
        val top = (targetH - scaledH) / 2
        val dst = Rect(left, top, left + scaledW, top + scaledH)
        canvas.drawBitmap(bitmap, null, dst, paint)
    }
}
