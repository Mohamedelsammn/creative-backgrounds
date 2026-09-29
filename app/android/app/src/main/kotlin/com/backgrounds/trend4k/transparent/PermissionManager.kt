package com.backgrounds.trend4k.transparent

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel

/**
 * Owns the runtime-permission flow for the transparent wallpaper: camera
 * (always) and notifications (Android 13+). The foreground-service-camera
 * permission is install-time and needs no runtime request.
 *
 * Reports every state Flutter needs to react to — granted / denied /
 * permanentlyDenied / notRequired — and provides a "go to settings" escape
 * hatch. "Permanently denied" is inferred by combining a persisted
 * "already asked" flag with [Activity.shouldShowRequestPermissionRationale],
 * which is the only way Android exposes it.
 */
class PermissionManager(private val activity: Activity) {

    private var pending: MethodChannel.Result? = null

    /** Current status of each permission, without prompting. */
    fun status(): Map<String, String> = mapOf(
        "camera" to statusFor(Manifest.permission.CAMERA, KEY_ASKED_CAMERA),
        "notifications" to notificationStatus(),
    )

    /**
     * Requests any not-yet-granted permissions. Replies asynchronously via
     * [onRequestPermissionsResult] with the resulting [status] map. If nothing
     * needs requesting, replies immediately.
     */
    fun request(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("in_progress", "A permission request is already running", null)
            return
        }
        val needed = buildList {
            if (!granted(Manifest.permission.CAMERA)) add(Manifest.permission.CAMERA)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                !granted(Manifest.permission.POST_NOTIFICATIONS)
            ) {
                add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
        if (needed.isEmpty()) {
            result.success(status())
            return
        }
        pending = result
        activity.requestPermissions(needed.toTypedArray(), REQUEST_CODE)
    }

    /**
     * Forwarded from `MainActivity.onRequestPermissionsResult`. Returns true if
     * it handled [requestCode].
     */
    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        // Persist that these were asked so a later denial can be distinguished
        // from "never asked" when computing permanentlyDenied.
        val editor = prefs().edit()
        permissions.forEach { p ->
            when (p) {
                Manifest.permission.CAMERA -> editor.putBoolean(KEY_ASKED_CAMERA, true)
                Manifest.permission.POST_NOTIFICATIONS ->
                    editor.putBoolean(KEY_ASKED_NOTIFICATIONS, true)
            }
        }
        editor.apply()
        pending?.success(status())
        pending = null
        return true
    }

    /** Opens this app's system settings page so the user can grant manually. */
    fun openAppSettings(): Boolean = try {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", activity.packageName, null),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
        true
    } catch (e: Exception) {
        false
    }

    /**
     * Opens the system battery-optimization settings so the user can exempt this
     * app — needed on aggressive OEMs (MIUI/HyperOS, One UI, ColorOS, …) that
     * kill the background camera service. Falls back to app details.
     */
    fun openBatterySettings(): Boolean = try {
        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
        true
    } catch (e: Exception) {
        openAppSettings()
    }

    // --- internals ---------------------------------------------------------

    private fun notificationStatus(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return "notRequired"
        return statusFor(Manifest.permission.POST_NOTIFICATIONS, KEY_ASKED_NOTIFICATIONS)
    }

    private fun statusFor(permission: String, askedKey: String): String {
        if (granted(permission)) return "granted"
        val asked = prefs().getBoolean(askedKey, false)
        val showRationale = activity.shouldShowRequestPermissionRationale(permission)
        // Asked before + system no longer offers a rationale => "Don't ask again".
        return if (asked && !showRationale) "permanentlyDenied" else "denied"
    }

    private fun granted(permission: String): Boolean =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun prefs() =
        activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    companion object {
        private const val PREFS = "transparent_prefs"
        private const val KEY_ASKED_CAMERA = "asked_camera"
        private const val KEY_ASKED_NOTIFICATIONS = "asked_notifications"
        private const val REQUEST_CODE = 0xCA11
    }
}
