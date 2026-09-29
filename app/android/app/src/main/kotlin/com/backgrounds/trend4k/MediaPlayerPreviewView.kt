package com.backgrounds.trend4k

import android.content.Context
import android.graphics.Matrix
import android.graphics.SurfaceTexture
import android.media.MediaPlayer
import android.util.Log
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Fallback in-app preview for a looping video wallpaper, rendered with plain
 * Android [MediaPlayer] instead of `video_player`'s ExoPlayer/Media3 pipeline.
 *
 * ## Why this exists
 *
 * `video_player` (ExoPlayer/Media3) fails to initialise the hardware decoder
 * on some MediaTek chipsets for content this app's backend already serves -
 * observed as `MediaCodecRenderer$DecoderInitializationException` /
 * `IllegalArgumentException: start failed` inside `MediaCodec.native_start`,
 * thrown from ExoPlayer's own codec-configuration sequence (buffer-count
 * negotiation, priority/operating-rate config, ViLTE parameters) that plain
 * `MediaPlayer` never performs. The exact same file plays back correctly via
 * `MediaPlayer` - proven by [VideoWallpaperService], which has always used it
 * for the applied live wallpaper. This view exists to give the in-app preview
 * (Home cards, Details) that same working decode path as a fallback when
 * `video_player` reports an initialization error, without touching the
 * backend's encoding or adding a new plugin dependency.
 *
 * ## Why TextureView, not SurfaceView
 *
 * Mirrors [TransparentPreviewView]'s reasoning exactly: inside a Flutter
 * [PlatformView], a `SurfaceView` lives in its own window and does not follow
 * the platform view's layout/compositing. `TextureView` is a normal view and
 * composites correctly inside Flutter's view hierarchy.
 *
 * ## Why the texture gets an explicit crop-to-fill transform
 *
 * A `TextureView` stretches its content to exactly fill its own bounds with
 * no aspect-ratio awareness of its own - unlike Flutter's `video_player` path
 * (`LiveWallpaperPlayer`'s `FittedBox(fit: cover)` over a `SizedBox` sized to
 * the decoded video's real dimensions), which already crops/letterboxes
 * correctly. Left alone, this view would visibly stretch/squash any clip
 * whose native aspect ratio does not exactly match the card's box - a real,
 * visible distortion specific to this fallback path. [MediaPlayer]'s
 * `onVideoSizeChanged` callback reports the true decoded width/height once
 * known; [_applyCoverTransform] then scales+centers via a `Matrix` on the
 * `TextureView` itself, replicating `BoxFit.cover` so this path matches the
 * ExoPlayer path's behaviour exactly.
 */
class MediaPlayerPreviewView(
    context: Context,
    private val videoUrl: String,
) : PlatformView {

    private var player: MediaPlayer? = null
    private var surface: Surface? = null
    private var released = false

    /** Decoded video dimensions, once `MediaPlayer` reports them. */
    private var videoWidth = 0
    private var videoHeight = 0

    private val textureView = TextureView(context).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
        )
        surfaceTextureListener = object : TextureView.SurfaceTextureListener {
            override fun onSurfaceTextureAvailable(st: SurfaceTexture, width: Int, height: Int) {
                startPlayback(st)
            }

            override fun onSurfaceTextureSizeChanged(st: SurfaceTexture, width: Int, height: Int) {
                applyCoverTransform()
            }

            override fun onSurfaceTextureDestroyed(st: SurfaceTexture): Boolean {
                stopPlayback()
                // We own teardown; tell the framework not to release the
                // texture itself out from under a still-running player.
                return false
            }

            override fun onSurfaceTextureUpdated(st: SurfaceTexture) {}
        }
    }

    /**
     * Scales+centers the texture's content so the video covers its box
     * (crops the overflow) instead of stretching to fill it - mirrors
     * `BoxFit.cover`. A no-op until both the view has a real size and the
     * decoder has reported the video's true dimensions.
     */
    private fun applyCoverTransform() {
        val vw = videoWidth
        val vh = videoHeight
        val viewW = textureView.width
        val viewH = textureView.height
        if (vw <= 0 || vh <= 0 || viewW <= 0 || viewH <= 0) return

        // Cover-fit scale: the larger of the two ratios, so the shorter edge
        // in the video's own coordinate space fully spans the view and the
        // overflow on the longer edge is what gets cropped.
        val scale = maxOf(viewW.toFloat() / vw, viewH.toFloat() / vh)
        val scaledW = vw * scale
        val scaledH = vh * scale

        val matrix = Matrix()
        // TextureView's default mapping already stretches the buffer to fill
        // the view; undo that non-uniform stretch first (back to the video's
        // native aspect ratio at the view's own pixel scale), then apply the
        // uniform cover scale, then center.
        matrix.setScale(scale * vw / viewW, scale * vh / viewH)
        matrix.postTranslate((viewW - scaledW) / 2f, (viewH - scaledH) / 2f)
        textureView.setTransform(matrix)
    }

    // Same reasoning as TransparentPreviewView's container: Flutter measures a
    // platform view by calling getView().measure(...) with its own widget
    // size, but does not attach it to a parent that honours LayoutParams -
    // MATCH_PARENT on the TextureView alone would leave it at its intrinsic
    // (zero) size. Forcing the measured size onto the child on every layout
    // pass is what makes it actually fill the box Flutter gave us.
    private val container = object : FrameLayout(context) {
        override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
            val w = MeasureSpec.getSize(widthMeasureSpec)
            val h = MeasureSpec.getSize(heightMeasureSpec)
            if (w > 0 && h > 0) {
                textureView.measure(
                    MeasureSpec.makeMeasureSpec(w, MeasureSpec.EXACTLY),
                    MeasureSpec.makeMeasureSpec(h, MeasureSpec.EXACTLY),
                )
                setMeasuredDimension(w, h)
            } else {
                super.onMeasure(widthMeasureSpec, heightMeasureSpec)
            }
        }

        override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
            textureView.layout(0, 0, r - l, b - t)
        }
    }.apply {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        addView(textureView)
    }

    private fun startPlayback(surfaceTexture: SurfaceTexture) {
        if (released || player != null) return
        val s = Surface(surfaceTexture)
        surface = s
        try {
            player = MediaPlayer().apply {
                setDataSource(videoUrl)
                setSurface(s)
                isLooping = true
                // A wallpaper preview is decoration: muted, exactly like the
                // applied wallpaper's own player and video_player's controller.
                setVolume(0f, 0f)
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error what=$what extra=$extra url=$videoUrl")
                    true
                }
                setOnVideoSizeChangedListener { _, width, height ->
                    // Qualified explicitly: unqualified `videoWidth`/
                    // `videoHeight` here would resolve to MediaPlayer's own
                    // synthetic (getter-only) properties of the same name,
                    // not this class's fields, since `this` inside `apply`
                    // is the MediaPlayer instance being configured.
                    this@MediaPlayerPreviewView.videoWidth = width
                    this@MediaPlayerPreviewView.videoHeight = height
                    applyCoverTransform()
                }
                setOnPreparedListener { it.start() }
                prepareAsync()
            }
        } catch (e: Exception) {
            Log.e(TAG, "failed to start preview playback: ${e.message}", e)
        }
    }

    private fun stopPlayback() {
        val current = player ?: return
        player = null
        runCatching { if (current.isPlaying) current.stop() }
        runCatching { current.reset() }
        runCatching { current.release() }
        surface?.release()
        surface = null
        videoWidth = 0
        videoHeight = 0
    }

    override fun getView(): View = container

    override fun dispose() {
        released = true
        stopPlayback()
    }

    /** Registers the platform view under [VIEW_TYPE]; [args] carries the clip URL. */
    class Factory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
            val url = (args as? Map<*, *>)?.get("videoUrl") as? String ?: ""
            return MediaPlayerPreviewView(context, url)
        }
    }

    companion object {
        const val VIEW_TYPE = "com.backgrounds.trend4k/media_player_preview"
        private const val TAG = "MediaPlayerPreview"
    }
}
