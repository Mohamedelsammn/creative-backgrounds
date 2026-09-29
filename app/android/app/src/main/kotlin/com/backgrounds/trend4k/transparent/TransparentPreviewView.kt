package com.backgrounds.trend4k.transparent

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.core.UseCase
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.concurrent.Executor

/**
 * In-app live rear-camera preview shown before the user applies the wallpaper.
 *
 * Rendered as a Flutter [PlatformView] wrapping a CameraX [PreviewView], bound
 * to the **activity's** lifecycle - the app is in the foreground during preview,
 * so no foreground service is required here (unlike the wallpaper engine).
 *
 * ## Why the view is wrapped in a FrameLayout
 *
 * Flutter measures a platform view by calling `getView().measure(...)` with the
 * size of the Flutter widget, then lays it out itself. It does **not** attach
 * the view to a parent that honours `LayoutParams`, so setting MATCH_PARENT on
 * the `PreviewView` alone does nothing - it measures itself at its content size
 * and the rest of the widget stays black.
 *
 * The container below forces the measured size down onto its child on every
 * layout pass, so the preview always fills the exact box Flutter gave us.
 *
 * ## Why this never calls `unbindAll()`
 *
 * [ProcessCameraProvider] is a **process-wide singleton**, shared with the
 * wallpaper engine. Calling `unbindAll()` here would tear down whatever the
 * wallpaper engine had bound, leaving a black wallpaper. This class unbinds
 * only its own use case.
 */
class TransparentPreviewView(
    context: Context,
    private val lifecycleOwner: LifecycleOwner,
) : PlatformView {

    private val previewView = PreviewView(context).apply {
        // FILL_CENTER centre-crops the sensor feed to cover the view, so the
        // preview matches what the wallpaper will actually look like full-bleed.
        scaleType = PreviewView.ScaleType.FILL_CENTER

        // COMPATIBLE (TextureView) rather than the default PERFORMANCE
        // (SurfaceView): inside a Flutter platform view a SurfaceView sits in
        // its own window and does not follow the platform view's layout.
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE

        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
        )
    }

    /**
     * Container that propagates the size Flutter measured it at down to the
     * camera preview. Without this the preview measures itself independently
     * and occupies only part of the widget.
     */
    private val container = object : FrameLayout(context) {
        override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
            val w = MeasureSpec.getSize(widthMeasureSpec)
            val h = MeasureSpec.getSize(heightMeasureSpec)
            if (w > 0 && h > 0) {
                // Force the child to exactly our size, whatever it would have
                // chosen for itself.
                previewView.measure(
                    MeasureSpec.makeMeasureSpec(w, MeasureSpec.EXACTLY),
                    MeasureSpec.makeMeasureSpec(h, MeasureSpec.EXACTLY),
                )
                setMeasuredDimension(w, h)
            } else {
                super.onMeasure(widthMeasureSpec, heightMeasureSpec)
            }
        }

        override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
            previewView.layout(0, 0, r - l, b - t)
        }
    }.apply {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        addView(previewView)
    }

    private val mainExecutor: Executor =
        Executor { r -> Handler(Looper.getMainLooper()).post(r) }

    private var cameraProvider: ProcessCameraProvider? = null
    private var useCase: UseCase? = null

    /// Set once dispose() has run, so a provider callback that resolves after
    /// the view is gone does not bind a camera nobody is watching.
    private var disposed = false

    init {
        bindCamera(context)
    }

    private fun bindCamera(context: Context) {
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            if (disposed) return@addListener
            try {
                val provider = future.get()
                cameraProvider = provider
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
                useCase = preview
                provider.bindToLifecycle(
                    lifecycleOwner,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                )
            } catch (e: Exception) {
                // No rear camera / camera busy: the preview stays blank. The
                // compatibility gate should prevent reaching here on unsupported
                // devices; this is a defensive no-op.
                Log.w(TAG, "preview bind failed: ${e.message}")
            }
        }, mainExecutor)
    }

    override fun getView(): View = container

    override fun dispose() {
        disposed = true
        // Unbind ONLY our use case - never `unbindAll()`, which would also
        // release the wallpaper engine's camera.
        val provider = cameraProvider
        val case = useCase
        if (provider != null && case != null) {
            runCatching { provider.unbind(case) }
                .onFailure { Log.w(TAG, "preview unbind failed: ${it.message}") }
        }
        useCase = null
        cameraProvider = null
    }

    /** Registers the platform view under [VIEW_TYPE]. */
    class Factory(private val lifecycleOwner: LifecycleOwner) :
        PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
            TransparentPreviewView(context, lifecycleOwner)
    }

    companion object {
        const val VIEW_TYPE = "com.backgrounds.trend4k/transparent_preview"
        private const val TAG = "TransparentCam"
    }
}
