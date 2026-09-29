package com.backgrounds.trend4k

import android.app.ActivityManager
import android.app.WallpaperManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.util.DisplayMetrics
import android.view.WindowManager

/**
 * Applies a plain (static) wallpaper via [WallpaperManager.setBitmap]. Clock /
 * depth wallpapers go through the live-wallpaper path instead. The bitmap is
 * decoded from a file path that Flutter downloaded — no networking here.
 */
object WallpaperApplyService {

    /**
     * Prepares ONE screen-sized composition and applies it.
     *
     * `visibleCropHint` stays null (this app never pre-crops source pixels),
     * and the bitmap handed to [WallpaperManager.setBitmap] is sized to the
     * PHYSICAL DISPLAY, never to [WallpaperManager.getDesiredMinimumWidth].
     *
     * That distinction is the whole fix for the reported "wallpaper is spread
     * across the launcher pages, a different section on each" bug.
     * `desiredMinimumWidth` is not the screen - it is the width the ACTIVE
     * LAUNCHER would like in order to pan the wallpaper for parallax across
     * its home-screen pages. On the tested device (1080x2340 display) it
     * reports 2340, i.e. a near-square canvas roughly twice the display
     * width. A previous revision here targeted exactly that, so it built a
     * 2340-wide bitmap, fit the portrait wallpaper into the middle of it, and
     * the launcher then panned a 1080-wide window across the result - showing
     * a different slice per page, with the unused side regions visible as
     * mismatched bands. Targeting the display instead yields one fixed
     * composition framed for one screen.
     *
     * [WallpaperManager.suggestDesiredDimensions] is also called with the
     * display size, which is the supported way to tell the framework this
     * wallpaper wants no extra parallax width. Whether a given third-party or
     * OEM launcher honours that is up to the launcher - but this app no longer
     * *requests* an oversized surface, which is the part it controls.
     *
     * See [buildDeviceFitBitmap].
     */
    fun applyStatic(context: Context, imagePath: String, destination: String): Boolean {
        var source: Bitmap? = null
        var fitted: Bitmap? = null
        return try {
            source = decodeBounded(context, imagePath) ?: return false
            val wm = WallpaperManager.getInstance(context)
            if (!wm.isWallpaperSupported) return false
            fitted = buildDeviceFitBitmap(context, source)
            // Ask for a fixed, screen-sized wallpaper surface rather than
            // letting the launcher's parallax width stand - see this
            // function's doc. Best-effort: some OEM builds ignore it, and it
            // must never fail the apply itself.
            runCatching {
                val m = displayMetrics(context)
                wm.suggestDesiredDimensions(m.widthPixels, m.heightPixels)
            }
            val flags = when (destination) {
                "homeScreen" -> WallpaperManager.FLAG_SYSTEM
                "lockScreen" -> WallpaperManager.FLAG_LOCK
                else -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
            }
            wm.setBitmap(fitted, null, true, flags)
            true
        } catch (e: Exception) {
            false
        } catch (e: OutOfMemoryError) {
            // A wallpaper source image can be large enough (multi-MP) that a
            // full-resolution decode exhausts the heap on a low-RAM device -
            // this used to escape uncaught out of this function (BitmapFactory
            // .decodeFile ran outside any try/catch, and OutOfMemoryError is an
            // Error, not an Exception, so a plain `catch (e: Exception)` here
            // would not have caught it either), crashing the whole process on
            // the bare background Thread WallpaperChannel runs this on -
            // exactly the "black screen, app restarts, splash never leaves"
            // symptom this fixes. Report failure instead of letting the
            // process die.
            false
        } finally {
            source?.recycle()
            // fitted may be the same object as source's downscaled cousin -
            // only recycle it if it's a distinct bitmap.
            if (fitted != null && fitted !== source) fitted.recycle()
        }
    }

    /** Real (full-screen, including system bars) display size in pixels. */
    private fun displayMetrics(context: Context): DisplayMetrics {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager)
            .defaultDisplay.getRealMetrics(metrics)
        return metrics
    }

    /**
     * Renders [source] onto a new canvas sized to exactly ONE PHYSICAL
     * DISPLAY - deliberately not to the launcher's desired/parallax width,
     * which is what previously spread the wallpaper across home-screen pages
     * (see [applyStatic]'s doc).
     *
     * COVER-scaled and centered - the same geometry contract
     * [DepthCompositor.drawCoverBitmap] uses for the live-wallpaper engine's
     * background, and the one confirmed correct on a physical device for
     * "With Design". This used to be FIT/contain (every source pixel
     * preserved, letterbox margin filled with a dimmed cover-scaled copy of
     * the same image rather than a hard bar) specifically to avoid a hard
     * black gap - but "Wallpaper Only" and "With Design" must share the same
     * background geometry (design presence must never change background
     * framing), and a static Wallpaper-Only apply was the one path still
     * using that older FIT-based composite, producing a visibly different
     * (if softer) top/bottom margin than the now-COVER "With Design" result.
     * A minimal, centered crop is preferred over any letterbox now - see
     * [DepthCompositor.drawCoverBitmap]'s own doc for the same reasoning.
     */
    private fun buildDeviceFitBitmap(
        context: Context,
        source: Bitmap,
    ): Bitmap {
        val metrics = displayMetrics(context)

        val destW = metrics.widthPixels.coerceAtLeast(1)
        val destH = metrics.heightPixels.coerceAtLeast(1)

        // Source already matches the destination shape closely enough that
        // cover-scaling would crop nothing visible - skip building a second
        // bitmap entirely rather than paying for a no-op composite.
        val srcRatio = source.width.toFloat() / source.height
        val destRatio = destW.toFloat() / destH
        if (kotlin.math.abs(srcRatio - destRatio) < 0.01f &&
            source.width >= destW && source.height >= destH
        ) {
            return source
        }

        val destBitmap = Bitmap.createBitmap(destW, destH, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(destBitmap)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
        DepthCompositor.drawCoverBitmap(canvas, source, destW, destH, paint)
        return destBitmap
    }

    /**
     * A wallpaper is never displayed larger than the screen, so decoding
     * far beyond screen resolution wastes heap for no visual benefit on a
     * launcher that shows it 1:1. But some launchers pan a wider bitmap for
     * a parallax effect across home-screen pages, and any launcher may
     * upscale a source that landed exactly at screen resolution during a
     * zoom/transition, softening fine detail. This margin keeps a quality
     * cushion above the exact screen size when the source and the device's
     * memory both allow it, without ever decoding more than the source
     * actually has.
     */
    private const val QUALITY_MARGIN = 1.35f

    /**
     * Decodes [imagePath] downsampled to roughly the device's own screen
     * resolution (times [QUALITY_MARGIN] when memory allows - see
     * [hasMemoryHeadroomForMargin]) rather than at the source image's full
     * resolution - decoding far beyond what any launcher will ever show is
     * what made the previous unbounded decode prone to [OutOfMemoryError] on
     * large source images / low-RAM devices.
     */
    private fun decodeBounded(context: Context, imagePath: String): Bitmap? {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager)
            .defaultDisplay.getRealMetrics(metrics)
        val margin = if (hasMemoryHeadroomForMargin(context)) QUALITY_MARGIN else 1f
        val targetW = (metrics.widthPixels * margin).toInt()
        val targetH = (metrics.heightPixels * margin).toInt()

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(imagePath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        // Never upscale beyond the source: a sample size below 1 is not a
        // valid BitmapFactory option, so the margin can only shrink how much
        // downsampling happens, never magnify past what the file actually has.
        var sampleSize = 1
        while (bounds.outWidth / (sampleSize * 2) >= targetW &&
            bounds.outHeight / (sampleSize * 2) >= targetH
        ) {
            sampleSize *= 2
        }

        val decodeOptions = BitmapFactory.Options().apply { inSampleSize = sampleSize }
        return BitmapFactory.decodeFile(imagePath, decodeOptions)
    }

    /**
     * Conservative gate on decoding above exact screen resolution: skips the
     * margin entirely on a device already under memory pressure, or with a
     * small per-app heap where a margin decode plus the crop/setBitmap copy
     * WallpaperManager makes internally could plausibly exhaust it. Errs
     * toward the safe (no-margin) side rather than trying to predict exact
     * bitmap byte counts.
     */
    private fun hasMemoryHeadroomForMargin(context: Context): Boolean {
        return try {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val info = ActivityManager.MemoryInfo()
            am.getMemoryInfo(info)
            !info.lowMemory && am.memoryClass >= 128
        } catch (e: Exception) {
            false
        }
    }
}
