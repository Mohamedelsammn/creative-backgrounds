package com.creative.backgrounds.transparent

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.concurrent.Executor

/**
 * In-app live rear-camera preview shown before the user applies the wallpaper.
 * Rendered as a Flutter [PlatformView] wrapping a CameraX [PreviewView], bound to
 * the **activity's** lifecycle — the app is in the foreground during preview, so
 * no foreground service is required here (unlike the wallpaper engine).
 */
class TransparentPreviewView(
    context: Context,
    private val lifecycleOwner: LifecycleOwner,
) : PlatformView {

    private val previewView = PreviewView(context).apply {
        scaleType = PreviewView.ScaleType.FILL_CENTER
    }
    private val mainExecutor: Executor =
        Executor { r -> Handler(Looper.getMainLooper()).post(r) }
    private var cameraProvider: ProcessCameraProvider? = null

    init {
        bindCamera(context)
    }

    private fun bindCamera(context: Context) {
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            try {
                val provider = future.get()
                cameraProvider = provider
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
                provider.unbindAll()
                provider.bindToLifecycle(
                    lifecycleOwner,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                )
            } catch (e: Exception) {
                // No rear camera / camera busy: the preview stays blank. The
                // compatibility gate should prevent reaching here on unsupported
                // devices; this is a defensive no-op.
            }
        }, mainExecutor)
    }

    override fun getView(): View = previewView

    override fun dispose() {
        runCatching { cameraProvider?.unbindAll() }
    }

    /** Registers the platform view under [VIEW_TYPE]. */
    class Factory(private val lifecycleOwner: LifecycleOwner) :
        PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
            TransparentPreviewView(context, lifecycleOwner)
    }

    companion object {
        const val VIEW_TYPE = "com.creative.backgrounds/transparent_preview"
    }
}
