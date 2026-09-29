package com.backgrounds.trend4k

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RenderEffect
import android.graphics.Shader
import android.os.Build

/**
 * Draws the wallpaper layers in the one order that makes the depth effect
 * work:
 *
 * ```
 * BACKGROUND  ->  CLOCK  ->  FOREGROUND
 * ```
 *
 * Painting the cut-out subject last is what places the clock *behind* it.
 *
 * The foreground transform (scale, offsets) comes from the backend's
 * `depthConfig`; nothing here invents a position. This must stay visually in
 * sync with the Flutter `DepthLayerStack`.
 *
 * These are drawing primitives, not a compositor that builds an intermediate
 * bitmap: `LiveWallpaperService` paints straight onto the surface each tick, so
 * an always-on wallpaper never allocates a full-screen ARGB_8888 per frame.
 */
object DepthCompositor {

    /**
     * Draws the cut-out subject with the backend-authored transform applied.
     * Offsets are normalized fractions of the surface, so one authored value
     * lands identically on any screen size.
     */
    fun drawForeground(
        canvas: Canvas,
        foreground: Bitmap,
        targetW: Int,
        targetH: Int,
        paint: Paint,
        config: DepthConfig,
        offsetX: Int = 0,
        offsetY: Int = 0,
    ) {
        // COVER, matching [drawCoverBitmap] and the background beneath it: the
        // cut-out subject is registered pixel-for-pixel against the background
        // it was cut out of, so the two layers must be scaled identically or
        // the subject drifts out of alignment with its own scene. Both layers
        // switched from FIT to COVER together - a still depth/clock wallpaper
        // used to letterbox instead of filling the visible viewport whenever
        // its source aspect ratio didn't match the device's, leaving an
        // unpainted (black) strip; the visible viewport must always be fully
        // covered, so any cropping this introduces on a mismatched aspect
        // ratio is preferable to that gap. FIT is still correct for a video
        // poster's own frame area vs the clock overlay - unaffected here.
        val scale = maxOf(
            targetW.toFloat() / foreground.width,
            targetH.toFloat() / foreground.height,
        ) * config.foregroundScale

        val scaledW = (foreground.width * scale).toInt()
        val scaledH = (foreground.height * scale).toInt()
        val left = offsetX + (targetW - scaledW) / 2 +
            (config.foregroundOffsetX * targetW).toInt()
        val top = offsetY + (targetH - scaledH) / 2 +
            (config.foregroundOffsetY * targetH).toInt()

        canvas.drawBitmap(
            foreground,
            null,
            Rect(left, top, left + scaledW, top + scaledH),
            paint,
        )
    }

    /**
     * Draws [bitmap] scaled to FIT entirely inside the target rect, centred -
     * the complete authored composition stays visible, and any leftover margin
     * (when the target's aspect ratio differs from the bitmap's) is simply not
     * painted, leaving whatever the caller already drew underneath.
     *
     * No longer used for a wallpaper's own background/foreground layers (see
     * [drawCoverBitmap]'s doc for why) - kept for any future caller that
     * genuinely wants letterboxing over guaranteed edge-to-edge coverage.
     */
    fun drawFitBitmap(
        canvas: Canvas,
        bitmap: Bitmap,
        targetW: Int,
        targetH: Int,
        paint: Paint,
        offsetX: Int = 0,
        offsetY: Int = 0,
    ) {
        if (bitmap.width <= 0 || bitmap.height <= 0) return
        val scale = minOf(
            targetW.toFloat() / bitmap.width,
            targetH.toFloat() / bitmap.height,
        )
        val scaledW = (bitmap.width * scale).toInt().coerceAtLeast(1)
        val scaledH = (bitmap.height * scale).toInt().coerceAtLeast(1)
        val left = offsetX + (targetW - scaledW) / 2
        val top = offsetY + (targetH - scaledH) / 2
        canvas.drawBitmap(
            bitmap,
            null,
            Rect(left, top, left + scaledW, top + scaledH),
            paint,
        )
    }

    /**
     * Draws [bitmap] scaled to COVER the target rect (center-crop), offset the
     * same way [drawFitBitmap] is so it can be centred within an oversized
     * (parallax) wallpaper surface.
     *
     * This is the wallpaper background's own draw mode (via
     * [LiveWallpaperService]) as well as a video poster's: the visible
     * home-screen viewport must always be fully painted, so on a source
     * aspect ratio that does not match the device's, cropping some edge
     * content is strictly preferable to leaving an unpainted (black) strip
     * where FIT's letterbox margin would otherwise land. [drawForeground]
     * uses this exact same scale formula so a DEPTH wallpaper's cut-out
     * subject stays pixel-registered against this background.
     */
    fun drawCoverBitmap(
        canvas: Canvas,
        bitmap: Bitmap,
        targetW: Int,
        targetH: Int,
        paint: Paint,
        offsetX: Int = 0,
        offsetY: Int = 0,
    ) {
        if (bitmap.width <= 0 || bitmap.height <= 0) return
        val scale = maxOf(
            targetW.toFloat() / bitmap.width,
            targetH.toFloat() / bitmap.height
        )
        val scaledW = (bitmap.width * scale).toInt().coerceAtLeast(1)
        val scaledH = (bitmap.height * scale).toInt().coerceAtLeast(1)
        val left = offsetX + (targetW - scaledW) / 2
        val top = offsetY + (targetH - scaledH) / 2
        val dst = Rect(left, top, left + scaledW, top + scaledH)
        canvas.drawBitmap(bitmap, null, dst, paint)
    }

    /**
     * Applies the authored background blur, once, at load time.
     *
     * [RenderEffect] needs API 31; below that the plate is returned unblurred
     * rather than blurring per frame on the CPU, which an always-on wallpaper
     * cannot afford. The composite is still correct, just without the blur.
     */
    fun blurredBackground(source: Bitmap, radius: Float): Bitmap {
        if (radius <= 0f || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return source
        return try {
            val output = Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888)
            val renderNode = android.graphics.RenderNode("depthBlur").apply {
                setPosition(0, 0, source.width, source.height)
                setRenderEffect(
                    RenderEffect.createBlurEffect(radius, radius, Shader.TileMode.CLAMP)
                )
            }
            val renderCanvas = renderNode.beginRecording()
            renderCanvas.drawBitmap(source, 0f, 0f, null)
            renderNode.endRecording()

            // A RenderNode cannot draw into a software canvas, so fall back to
            // the source when no hardware path is available.
            val hardwareRenderer = android.graphics.HardwareRenderer()
            val imageReader = android.media.ImageReader.newInstance(
                source.width, source.height, android.graphics.PixelFormat.RGBA_8888, 1
            )
            hardwareRenderer.setSurface(imageReader.surface)
            hardwareRenderer.setContentRoot(renderNode)
            hardwareRenderer.createRenderRequest().setWaitForPresent(true).syncAndDraw()

            val image = imageReader.acquireNextImage() ?: run {
                hardwareRenderer.destroy()
                imageReader.close()
                return source
            }
            val plane = image.planes[0]
            val copy = Bitmap.createBitmap(
                plane.rowStride / plane.pixelStride, source.height, Bitmap.Config.ARGB_8888
            )
            copy.copyPixelsFromBuffer(plane.buffer)
            image.close()
            imageReader.close()
            hardwareRenderer.destroy()

            Canvas(output).drawBitmap(
                copy, Rect(0, 0, source.width, source.height),
                Rect(0, 0, source.width, source.height), null
            )
            copy.recycle()
            output
        } catch (e: Exception) {
            source
        }
    }
}
