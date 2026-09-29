package com.backgrounds.trend4k

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * A `camera`-typed foreground service whose sole job is to keep the app process
 * eligible to use the camera while the launcher (a different app) is in the
 * foreground. It does **not** open the camera itself — the wallpaper engine
 * does — but on Android 14+ a running `FOREGROUND_SERVICE_TYPE_CAMERA` service
 * is what makes that access legal, and it shows the required privacy
 * notification while the transparent wallpaper is active.
 */
class CameraForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureChannel()
        val notification = buildNotification()
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            Log.d(TAG, "foreground camera service started")
        }.onFailure { Log.e(TAG, "startForeground failed: ${it.message}", it) }
        // NOT sticky: a null-intent auto-restart would re-show the camera
        // notification with no camera actually in use. The wallpaper engine
        // re-starts us when it needs the camera.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        }
        Log.d(TAG, "foreground camera service destroyed")
        super.onDestroy()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "Transparent wallpaper",
                        NotificationManager.IMPORTANCE_LOW,
                    ).apply {
                        description = getString(R.string.transparent_camera_notification_text)
                        setShowBadge(false)
                    },
                )
            }
        }
    }

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle(getString(R.string.transparent_camera_notification_title))
            .setContentText(getString(R.string.transparent_camera_notification_text))
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "transparent_wallpaper_camera"
        private const val NOTIFICATION_ID = 0x7CA1
        private const val TAG = "TransparentCam"

        fun start(context: Context) {
            val intent = Intent(context, CameraForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            Log.d(TAG, "FGS start() requested")
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, CameraForegroundService::class.java))
            Log.d(TAG, "FGS stop() requested")
        }
    }
}
