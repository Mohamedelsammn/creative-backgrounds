package com.backgrounds.trend4k

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLUtils
import android.opengl.Matrix
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.Calendar

/**
 * Composites a looping [MediaPlayer]-decoded video with a clock/date overlay
 * onto a wallpaper engine's [Surface], via a small hand-rolled EGL/GLES
 * pipeline.
 *
 * ## Why this exists
 *
 * `MediaPlayer.setSurface(surface)` hands the decoder direct, exclusive
 * ownership of a [Surface]'s buffer queue - there is no [Canvas] available to
 * draw anything else on top while it is playing (confirmed: interleaving a
 * `lockCanvas()` draw on the same Surface just races the decoder's own writes
 * and is overwritten within one frame). This is fine for a plain video
 * wallpaper, but a customized clock needs a persistent overlay, which a
 * single shared buffer queue cannot provide.
 *
 * GL compositing is the standard fix (also how video-with-overlay apps in
 * general do this): MediaPlayer is redirected to an offscreen
 * [SurfaceTexture] instead of the real wallpaper Surface - the decoder is
 * completely unaware of the difference, same single decode, same zero-copy
 * GPU path. A small EGL context owned by this class then draws two textured
 * quads onto the REAL wallpaper Surface each time a new video frame is ready:
 * the video frame (via [SurfaceTexture.updateTexImage], cheap, GPU-side) and
 * the clock (a [Bitmap] rendered by the existing [ClockRenderer] onto a small
 * offscreen canvas, uploaded to a texture, but only re-rendered/re-uploaded
 * when the displayed time string actually changes - not every frame).
 *
 * ## Threading
 *
 * All EGL/GL calls happen on a single dedicated [HandlerThread] ([glThread]),
 * since an EGL context is only valid on the thread that created it. Public
 * methods post onto that thread, so callers on the wallpaper engine's own
 * (main) thread never touch GL directly.
 */
class GLVideoClockCompositor(private val context: android.content.Context) {

    private val glThread = HandlerThread("GLVideoClockCompositor").apply { start() }
    private val glHandler = Handler(glThread.looper)

    private val renderer = ClockRenderer(context)
    private val ringRenderer = BatteryRingRenderer(context)
    private val dateRenderer = StudioDateRenderer(context)

    /** Authored studio widgets drawn onto the same overlay texture as the
     * clock, so the video path composes exactly one overlay. */
    private var widgets: List<StudioWidgetConfig> = emptyList()

    /** Latest battery level, or null when unknown/unobserved. */
    private var batteryLevel: Int? = null

    /** The independently-positioned date element. */
    private var dateWidget: StudioDateConfig? = null

    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglConfig: EGLConfig? = null
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE

    private var videoTextureId = 0
    private var clockTextureId = 0
    private var videoSurfaceTexture: SurfaceTexture? = null
    private var videoInputSurface: Surface? = null

    /** Draws the video's `samplerExternalOES` texture (the format
     * SurfaceTexture-backed video frames require - a plain `sampler2D`
     * program cannot sample it). */
    private var videoProgram = 0

    /** Draws the clock's plain `sampler2D` texture. Kept as a separate
     * program rather than one shader with both sampler types bound to the
     * same texture unit, which is not well-defined in GLSL ES 2.0 - two
     * small single-purpose programs is the standard, unambiguous approach. */
    private var clockProgram = 0

    private var vertexBuffer: FloatBuffer? = null
    private var texCoordBuffer: FloatBuffer? = null

    private var surfaceWidth = 0
    private var surfaceHeight = 0

    /** The video's own width/height ratio, used for cover-fit cropping so the
     * clip fills the screen without letterboxing - matches every other
     * cover-fit draw in this codebase ([DepthCompositor.drawCoverBitmap]).
     * [SurfaceTexture] has no direct size query, so this starts at a 1:1
     * guess (a stretch, not a crop, for at most one frame) until
     * [setVideoAspect] supplies the real ratio from MediaPlayer's own
     * `onVideoSizeChanged`. */
    private var videoAspect = 1f

    /** The exact time+date text last rendered into [clockTextureId], so an
     * unchanged minute (the common case, since this ticks once/second but
     * most designs only show `HH:mm`) skips the whole render/upload path. */
    private var lastClockKey: String? = null
    private var clockConfig: ClockConfig = ClockConfig()

    private var released = false

    /**
     * Prepares EGL/GL against [outputSurface] (the real wallpaper Surface)
     * and hands the caller the [Surface] to redirect `MediaPlayer.setSurface`
     * to via [onVideoSurfaceReady]. Frames written to that surface by the
     * decoder trigger a composite+redraw automatically.
     *
     * Some GPU drivers/backends (confirmed on at least one Android emulator's
     * virtualized GL path) reject an app-created `SurfaceTexture`-backed
     * `Surface` handed to `MediaPlayer.setSurface()`, or fail EGL setup
     * itself, in ways [initEgl]/[initGl] cannot detect ahead of time - the
     * failure only surfaces when the caller actually calls `setSurface` on
     * the returned Surface. [onFailed] lets the caller recover by falling
     * back to a direct `setSurface(outputSurface)` (no clock, but the video
     * still plays) rather than the video silently never starting.
     */
    fun start(
        outputSurface: Surface,
        width: Int,
        height: Int,
        onVideoSurfaceReady: (Surface) -> Unit,
        onFailed: () -> Unit,
    ) {
        glHandler.post {
            if (released) return@post
            surfaceWidth = width
            surfaceHeight = height
            try {
                initEgl(outputSurface)
                initGl()
                val texture = SurfaceTexture(videoTextureId)
                texture.setOnFrameAvailableListener({ onFrameAvailable() }, glHandler)
                videoSurfaceTexture = texture
                val inputSurface = Surface(texture)
                videoInputSurface = inputSurface
                glHandler.post { drawIfReady() } // Paint the clock even before the first video frame.
                onVideoSurfaceReady(inputSurface)
            } catch (e: Throwable) {
                // Broad catch deliberately includes non-Exception failures:
                // confirmed on-device that eglCreateWindowSurface (inside
                // initEgl) can throw an IllegalStateException that must
                // still route through the same cleanup/onFailed path as any
                // other setup failure here.
                Log.e(TAG, "failed to initialise GL video compositor: ${e.message}", e)
                released = true
                // videoInputSurface/videoSurfaceTexture may already be
                // assigned by this point (they're set as soon as
                // SurfaceTexture/Surface construction succeeds, before
                // onVideoSurfaceReady is even called) - destroyGl/destroyEgl
                // below clean up the GL texture ID and EGL context/surface,
                // but NOT these two, which hold their own separate native
                // BufferQueue/Surface resources. Confirmed on-device:
                // leaving these (and, separately, an abandoned MediaPlayer -
                // see VideoWallpaperService's matching fix) to GC
                // finalization instead of releasing them explicitly, across
                // the many repeated failure/retry cycles this compositor is
                // specifically designed to survive, starved the device's
                // software video decoder of memory (logcat: repeating
                // "MediaCodec: keep callback message for reclaim", the
                // fingerprint of a NO_MEMORY retry loop) - surfacing later
                // as a video that renders one frame then freezes.
                videoInputSurface?.release()
                videoInputSurface = null
                videoSurfaceTexture?.release()
                videoSurfaceTexture = null
                destroyGl()
                destroyEgl()
                onFailed()
            }
        }
    }

    /** Updates the size the video quad is fit to (a wallpaper surface can be
     * (re)created at a new size, e.g. rotation or a different launcher). */
    fun onOutputSizeChanged(width: Int, height: Int) {
        glHandler.post {
            surfaceWidth = width
            surfaceHeight = height
            invalidateClockTexture()
        }
    }

    /** Replaces the clock configuration used for future draws. Cheap: does
     * not itself trigger a redraw or texture rebuild - the next frame (video
     * or the once-a-second clock tick) picks it up. */
    fun setClockConfig(config: ClockConfig) {
        glHandler.post {
            clockConfig = config
            lastClockKey = null // force a redraw of the new config next tick.
        }
    }

    /** Sets the authored studio widgets. Forces an overlay rebuild, same as
     * [setClockConfig]. */
    fun setWidgets(next: List<StudioWidgetConfig>) {
        glHandler.post {
            widgets = next
            lastClockKey = null
        }
    }

    /** Sets the independently-positioned date element. */
    fun setDateWidget(next: StudioDateConfig?) {
        glHandler.post {
            dateWidget = next
            lastClockKey = null
        }
    }

    /** Updates the battery level the ring draws. Cheap and idempotent: an
     * unchanged level does not invalidate the cached overlay texture. */
    fun setBatteryLevel(level: Int?) {
        glHandler.post {
            if (batteryLevel == level) return@post
            batteryLevel = level
            lastClockKey = null
        }
    }

    /** Called once/second by the engine's own clock tick (independent of
     * video frame rate) so the displayed time advances even while the video
     * frame itself is unchanged (e.g. a very long/slow clip, or the engine
     * paused on a frame). Cheap when the visible string hasn't changed. */
    fun onClockTick() {
        glHandler.post { drawIfReady() }
    }

    /**
     * Tears down EGL/GL and releases the video surface/texture, BLOCKING
     * the calling thread until that teardown has actually run on
     * [glThread].
     *
     * This must be synchronous: the caller ([VideoWallpaperService]'s
     * `stopPlayback()`) immediately constructs a NEW [GLVideoClockCompositor]
     * and calls `eglCreateWindowSurface()` against the SAME output Surface
     * right after calling this. [destroyEgl] is what actually disconnects
     * this instance's EGL producer from that Surface's buffer queue - if
     * this method returned before that ran (the previous implementation
     * only *posted* the teardown and returned immediately), the new
     * instance's `eglCreateWindowSurface` call could run on its own thread
     * before the old disconnect executed on this one, losing the race and
     * failing with `EGL_BAD_ALLOC`/"already connected" even on a completely
     * fresh process (confirmed via logcat - not a leftover-state issue,
     * a genuine unguarded connect/disconnect race between two instances).
     * A `CountDownLatch` is the standard, safe way to wait for a specific
     * enqueued task on another thread's `Handler` without any polling.
     */
    fun release() {
        val latch = java.util.concurrent.CountDownLatch(1)
        glHandler.post {
            released = true
            videoInputSurface?.release()
            videoInputSurface = null
            videoSurfaceTexture?.release()
            videoSurfaceTexture = null
            destroyGl()
            destroyEgl()
            latch.countDown()
        }
        // Bounded: this thread is never the GL thread itself (all public
        // methods here are called from the wallpaper engine's main thread),
        // so there is no self-deadlock risk - the timeout exists only to
        // avoid hanging forever if glHandler's thread is somehow already
        // dead (e.g. a prior quitSafely() actually took effect), matching
        // the "never leave the wallpaper stuck" principle used throughout
        // this class.
        latch.await(500, java.util.concurrent.TimeUnit.MILLISECONDS)
        glThread.quitSafely()
    }

    private fun onFrameAvailable() {
        if (released) return
        videoSurfaceTexture?.updateTexImage()
        drawIfReady()
    }

    /** Lets the caller (which owns the MediaPlayer and gets its
     * `onVideoSizeChanged` callback) supply the clip's real aspect ratio for
     * correct cover-fit cropping, exactly like every other cover-fit draw in
     * this codebase. */
    fun setVideoAspect(width: Int, height: Int) {
        if (width <= 0 || height <= 0) return
        glHandler.post { videoAspect = width.toFloat() / height.toFloat() }
    }

    private fun drawIfReady() {
        if (released || eglSurface == EGL14.EGL_NO_SURFACE || surfaceWidth <= 0 || surfaceHeight <= 0) return
        if (!makeCurrent()) return

        updateClockTextureIfNeeded()

        GLES20.glViewport(0, 0, surfaceWidth, surfaceHeight)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

        drawVideoQuad()
        drawClockQuad()

        EGL14.eglSwapBuffers(eglDisplay, eglSurface)
    }

    // ---- EGL setup -----------------------------------------------------

    private fun initEgl(outputSurface: Surface) {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        check(eglDisplay != EGL14.EGL_NO_DISPLAY) { "no EGL display" }
        val version = IntArray(2)
        check(EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) { "eglInitialize failed" }

        val attribList = intArrayOf(
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_NONE,
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        check(
            EGL14.eglChooseConfig(eglDisplay, attribList, 0, configs, 0, 1, numConfigs, 0),
        ) { "eglChooseConfig failed" }
        eglConfig = configs[0] ?: error("no matching EGL config")

        val contextAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE)
        eglContext = EGL14.eglCreateContext(eglDisplay, eglConfig, EGL14.EGL_NO_CONTEXT, contextAttribs, 0)
        check(eglContext != EGL14.EGL_NO_CONTEXT) { "eglCreateContext failed" }

        val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
        eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, eglConfig, outputSurface, surfaceAttribs, 0)
        check(eglSurface != EGL14.EGL_NO_SURFACE) { "eglCreateWindowSurface failed" }

        makeCurrent()
    }

    private fun makeCurrent(): Boolean {
        if (eglDisplay == EGL14.EGL_NO_DISPLAY) return false
        return EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
    }

    private fun destroyEgl() {
        if (eglDisplay == EGL14.EGL_NO_DISPLAY) return
        EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
        if (eglSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(eglDisplay, eglSurface)
        if (eglContext != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(eglDisplay, eglContext)
        EGL14.eglTerminate(eglDisplay)
        eglDisplay = EGL14.EGL_NO_DISPLAY
        eglContext = EGL14.EGL_NO_CONTEXT
        eglSurface = EGL14.EGL_NO_SURFACE
    }

    // ---- GL setup --------------------------------------------------------

    private fun initGl() {
        videoTextureId = createExternalTexture()
        clockTextureId = createTexture2D()
        videoProgram = buildProgram(VERTEX_SHADER, FRAGMENT_SHADER_EXTERNAL)
        clockProgram = buildProgram(VERTEX_SHADER, FRAGMENT_SHADER_2D)

        val vertices = floatArrayOf(
            -1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f,
        )
        vertexBuffer = ByteBuffer.allocateDirect(vertices.size * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(vertices); position(0) }

        // The "natural"/unflipped GL mapping - bottom-left vertex samples
        // v=0, top-left vertex samples v=1 - matching Grafika's reference
        // STextureRender (google/grafika) exactly. SurfaceTexture.
        // getTransformMatrix() already supplies whatever flip a given video
        // buffer actually needs on top of THIS mapping; pre-flipping these
        // base texcoords as well double-corrects it, which is what produced
        // an upside-down video (confirmed on-device). The plain 2D clock
        // texture needs the opposite correction instead - see
        // CLOCK_TEX_MATRIX below, applied only to that draw.
        val texCoords = floatArrayOf(
            0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f,
        )
        texCoordBuffer = ByteBuffer.allocateDirect(texCoords.size * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(texCoords); position(0) }
    }

    private fun destroyGl() {
        if (videoProgram != 0) GLES20.glDeleteProgram(videoProgram)
        if (clockProgram != 0) GLES20.glDeleteProgram(clockProgram)
        if (videoTextureId != 0) GLES20.glDeleteTextures(1, intArrayOf(videoTextureId), 0)
        if (clockTextureId != 0) GLES20.glDeleteTextures(1, intArrayOf(clockTextureId), 0)
        videoProgram = 0
        clockProgram = 0
        videoTextureId = 0
        clockTextureId = 0
    }

    private fun createExternalTexture(): Int {
        val ids = IntArray(1)
        GLES20.glGenTextures(1, ids, 0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, ids[0])
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        return ids[0]
    }

    private fun createTexture2D(): Int {
        val ids = IntArray(1)
        GLES20.glGenTextures(1, ids, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, ids[0])
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        return ids[0]
    }

    private fun buildProgram(vertexSrc: String, fragmentSrc: String): Int {
        val vs = compileShader(GLES20.GL_VERTEX_SHADER, vertexSrc)
        val fs = compileShader(GLES20.GL_FRAGMENT_SHADER, fragmentSrc)
        val prog = GLES20.glCreateProgram()
        GLES20.glAttachShader(prog, vs)
        GLES20.glAttachShader(prog, fs)
        GLES20.glLinkProgram(prog)
        val status = IntArray(1)
        GLES20.glGetProgramiv(prog, GLES20.GL_LINK_STATUS, status, 0)
        check(status[0] != 0) { "program link failed: ${GLES20.glGetProgramInfoLog(prog)}" }
        GLES20.glDeleteShader(vs)
        GLES20.glDeleteShader(fs)
        return prog
    }

    private fun compileShader(type: Int, src: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, src)
        GLES20.glCompileShader(shader)
        val status = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, status, 0)
        check(status[0] != 0) { "shader compile failed: ${GLES20.glGetShaderInfoLog(shader)}" }
        return shader
    }

    // ---- Drawing -----------------------------------------------------------

    private fun drawVideoQuad() {
        val texture = videoSurfaceTexture ?: return
        val transform = FloatArray(16)
        texture.getTransformMatrix(transform)

        GLES20.glUseProgram(videoProgram)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, videoTextureId)
        drawQuad(
            program = videoProgram,
            textureUnit = 0,
            modelMatrix = coverFitMatrix(videoAspect),
            texTransform = transform,
        )
    }

    private fun drawClockQuad() {
        if (!clockConfig.enabled || clockConfig.opacity <= 0f) return
        GLES20.glUseProgram(clockProgram)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, clockTextureId)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        drawQuad(
            program = clockProgram,
            textureUnit = 0,
            // The clock texture is already the full surface size (see
            // updateClockTextureIfNeeded) with the clock/date drawn at its
            // real position by ClockRenderer's own layout math - so the quad
            // itself is a plain fullscreen rect.
            modelMatrix = IDENTITY_MATRIX,
            // NOT identity: the shared base texcoords (see initGl) use the
            // "natural"/unflipped GL mapping that SurfaceTexture's own
            // transform matrix expects for the video draw. A plain
            // GLUtils.texImage2D upload of a Canvas Bitmap has no such
            // auto-correcting matrix of its own - Bitmap row 0 (top) lands
            // at texel v=0, so with the natural mapping the image would
            // draw upside down. This manual Y-flip (t' = 1 - t) supplies
            // the correction SurfaceTexture would otherwise have provided.
            texTransform = CLOCK_TEX_MATRIX,
        )
        GLES20.glDisable(GLES20.GL_BLEND)
    }

    private fun drawQuad(
        program: Int,
        textureUnit: Int,
        modelMatrix: FloatArray,
        texTransform: FloatArray,
    ) {
        val vBuf = vertexBuffer ?: return
        val tBuf = texCoordBuffer ?: return

        val posLoc = GLES20.glGetAttribLocation(program, "aPosition")
        val texLoc = GLES20.glGetAttribLocation(program, "aTexCoord")
        val mvpLoc = GLES20.glGetUniformLocation(program, "uMVP")
        val texMatrixLoc = GLES20.glGetUniformLocation(program, "uTexMatrix")
        val samplerLoc = GLES20.glGetUniformLocation(program, "uTexture")

        vBuf.position(0)
        GLES20.glEnableVertexAttribArray(posLoc)
        GLES20.glVertexAttribPointer(posLoc, 2, GLES20.GL_FLOAT, false, 0, vBuf)

        tBuf.position(0)
        GLES20.glEnableVertexAttribArray(texLoc)
        GLES20.glVertexAttribPointer(texLoc, 2, GLES20.GL_FLOAT, false, 0, tBuf)

        GLES20.glUniformMatrix4fv(mvpLoc, 1, false, modelMatrix, 0)
        GLES20.glUniformMatrix4fv(texMatrixLoc, 1, false, texTransform, 0)
        GLES20.glUniform1i(samplerLoc, textureUnit)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(posLoc)
        GLES20.glDisableVertexAttribArray(texLoc)
    }

    /** Cover-fit scale for the fullscreen video quad, mirroring
     * [DepthCompositor.drawCoverBitmap]'s center-crop behaviour but expressed
     * as a clip-space scale matrix instead of a destination Rect. */
    private fun coverFitMatrix(clipAspect: Float): FloatArray {
        val surfaceAspect = surfaceWidth.toFloat() / surfaceHeight.toFloat()
        val scaleX: Float
        val scaleY: Float
        if (clipAspect > surfaceAspect) {
            // Video is relatively wider than the screen - crop its sides.
            scaleX = clipAspect / surfaceAspect
            scaleY = 1f
        } else {
            scaleY = surfaceAspect / clipAspect
            scaleX = 1f
        }
        val m = FloatArray(16)
        Matrix.setIdentityM(m, 0)
        Matrix.scaleM(m, 0, scaleX, scaleY, 1f)
        return m
    }

    /**
     * Rebuilds [clockTextureId] from [ClockRenderer] only when the rendered
     * output would actually differ from last time - the whole point of
     * keeping this off the per-video-frame path. The offscreen bitmap is
     * sized to the full surface, with the design laid out against the centred
     * visible viewport inside it, not
     * cropped to just the clock's own bounds - simplicity over a tighter
     * texture at a fixed, small, once-a-second/minute cost.
     */
    private fun updateClockTextureIfNeeded() {
        if (surfaceWidth <= 0 || surfaceHeight <= 0) return
        val now = Calendar.getInstance()
        val key = clockCacheKey(now)
        if (key == lastClockKey) return
        lastClockKey = key

        val bitmap = Bitmap.createBitmap(surfaceWidth, surfaceHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        // Every design size is a proportion of the phone-screen width, so the
        // design is laid out against the screen-sized rect the user actually
        // sees, centred in a (possibly wider, parallax) launcher surface -
        // the same visible viewport LiveWallpaperService uses.
        val metrics = android.util.DisplayMetrics()
        @Suppress("DEPRECATION")
        (context.getSystemService(android.content.Context.WINDOW_SERVICE) as android.view.WindowManager)
            .defaultDisplay.getRealMetrics(metrics)
        val viewW = minOf(surfaceWidth, metrics.widthPixels.coerceAtLeast(1))
        val viewH = minOf(surfaceHeight, metrics.heightPixels.coerceAtLeast(1))
        canvas.translate(((surfaceWidth - viewW) / 2).toFloat(), ((surfaceHeight - viewH) / 2).toFloat())
        renderer.render(canvas, viewW, viewH, now, clockConfig)
        // Widgets paint ABOVE the clock onto the SAME overlay bitmap, so the
        // video path keeps composing exactly one overlay texture and the
        // stacking matches `DesignOverlay` in the Flutter preview.
        dateRenderer.render(canvas, viewW, viewH, dateWidget, now)
        ringRenderer.render(canvas, viewW, viewH, widgets, batteryLevel)

        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, clockTextureId)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
        bitmap.recycle()
    }

    private fun invalidateClockTexture() {
        lastClockKey = null
    }

    /** Cache key for the clock texture: changes exactly when the rendered
     * pixels would change - the displayed time text (at the design's own
     * cadence, seconds or minutes) plus the date (at most once/day) plus the
     * surface size (a rotation/resize). Config itself is not part of the key
     * since [setClockConfig] already forces a rebuild by clearing the key. */
    private fun clockCacheKey(now: Calendar): String {
        val bucket = if (clockConfig.showSeconds) {
            now.get(Calendar.HOUR_OF_DAY) * 3600 + now.get(Calendar.MINUTE) * 60 + now.get(Calendar.SECOND)
        } else {
            now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        }
        // The battery level is part of the rendered pixels, so it must be part
        // of the key - otherwise the ring would freeze at its first value.
        return "$bucket|${now.get(Calendar.DAY_OF_YEAR)}|$surfaceWidth|$surfaceHeight|$batteryLevel"
    }

    companion object {
        private const val TAG = "GLVideoClockCompositor"

        private val IDENTITY_MATRIX = FloatArray(16).also { Matrix.setIdentityM(it, 0) }

        /** Vertical flip (t' = 1 - t) applied to the clock quad's texture
         * coordinates - see [drawClockQuad]'s doc for why a plain
         * GLUtils-uploaded Canvas Bitmap needs this while the video quad
         * (fed by SurfaceTexture, which supplies its own correcting matrix)
         * does not. */
        private val CLOCK_TEX_MATRIX = FloatArray(16).also {
            Matrix.setIdentityM(it, 0)
            // Negate the Y scale and translate by +1 to map t -> 1 - t.
            it[5] = -1f
            it[13] = 1f
        }

        private const val VERTEX_SHADER = """
            attribute vec2 aPosition;
            attribute vec2 aTexCoord;
            uniform mat4 uMVP;
            uniform mat4 uTexMatrix;
            varying vec2 vTexCoord;
            void main() {
                gl_Position = uMVP * vec4(aPosition, 0.0, 1.0);
                vec4 tc = uTexMatrix * vec4(aTexCoord, 0.0, 1.0);
                vTexCoord = tc.xy;
            }
        """

        /** Samples the video's `samplerExternalOES` texture - the type a
         * SurfaceTexture-backed decode target requires. */
        private const val FRAGMENT_SHADER_EXTERNAL = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            varying vec2 vTexCoord;
            uniform samplerExternalOES uTexture;
            void main() {
                gl_FragColor = texture2D(uTexture, vTexCoord);
            }
        """

        /** Samples the clock's plain `sampler2D` texture. */
        private const val FRAGMENT_SHADER_2D = """
            precision mediump float;
            varying vec2 vTexCoord;
            uniform sampler2D uTexture;
            void main() {
                gl_FragColor = texture2D(uTexture, vTexCoord);
            }
        """
    }
}
