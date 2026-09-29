package com.backgrounds.trend4k.transparent

import android.app.WallpaperManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build

/**
 * Single source of truth for whether the Transparent (live rear-camera)
 * Wallpaper can run on this device. Flutter must never guess compatibility —
 * it always asks this class.
 *
 * The result is a plain [Map] so it crosses the MethodChannel unchanged. Each
 * individual check is reported (id / label / status / detail) so the UI can
 * explain *why* the feature is unavailable, and the overall [levelOf] gates the
 * whole flow.
 *
 * Note on the background-camera policy: whether a foreground `camera` service
 * can keep the camera open while the launcher is foreground cannot be proven
 * statically — it is validated at runtime on first start. That check is
 * therefore reported as [UNKNOWN] here rather than a false PASS/FAIL.
 */
class CompatibilityChecker(private val context: Context) {

    /** Per-check outcome. */
    enum class Status { PASS, WARN, FAIL, UNKNOWN }

    /** Overall feature support derived from the individual checks. */
    enum class Level { SUPPORTED, SUPPORTED_WITH_WARNINGS, UNSUPPORTED }

    private data class Check(
        val id: String,
        val label: String,
        val status: Status,
        val detail: String,
    )

    fun check(): Map<String, Any?> {
        val checks = mutableListOf<Check>()

        checks += androidVersionCheck()
        checks += liveWallpaperFeatureCheck()
        checks += wallpaperManagerCheck()
        checks += livePickerCheck()
        checks += cameraFeatureCheck()
        checks += rearCameraCheck()
        checks += cameraApiCheck()
        checks += cameraPermissionCheck()
        checks += foregroundServiceCheck()
        checks += backgroundCameraPolicyCheck()
        checks += manufacturerCheck()

        val level = levelOf(checks)
        return mapOf(
            "supportLevel" to level.name.lowercase(),
            "sdkInt" to Build.VERSION.SDK_INT,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "summary" to summaryFor(level, checks),
            "checks" to checks.map {
                mapOf(
                    "id" to it.id,
                    "label" to it.label,
                    "status" to it.status.name.lowercase(),
                    "detail" to it.detail,
                )
            },
        )
    }

    // --- Individual checks -------------------------------------------------

    private fun androidVersionCheck(): Check {
        // minSdk is 29, so this always passes; we still report the value because
        // camera/background behaviour differs sharply by API level.
        val note = when {
            Build.VERSION.SDK_INT >= 34 ->
                "Android 14+: foreground camera service type is mandatory (handled)."
            Build.VERSION.SDK_INT >= 31 ->
                "Android 12+: a persistent camera privacy indicator will be shown."
            else -> "Android 10/11: background-camera limits apply."
        }
        return Check(
            "android_version",
            "Android version",
            Status.PASS,
            "API ${Build.VERSION.SDK_INT} (${Build.VERSION.RELEASE}). $note",
        )
    }

    private fun liveWallpaperFeatureCheck(): Check {
        val ok = context.packageManager
            .hasSystemFeature(PackageManager.FEATURE_LIVE_WALLPAPER)
        return Check(
            "live_wallpaper_feature",
            "Live wallpaper support",
            if (ok) Status.PASS else Status.FAIL,
            if (ok) "Device supports live wallpapers."
            else "This device does not support live wallpapers.",
        )
    }

    private fun wallpaperManagerCheck(): Check {
        return try {
            val wm = WallpaperManager.getInstance(context)
            val supported = wm.isWallpaperSupported
            val allowed = wm.isSetWallpaperAllowed
            when {
                !supported -> Check(
                    "wallpaper_manager", "WallpaperManager", Status.FAIL,
                    "Setting wallpapers is not supported on this device.",
                )
                !allowed -> Check(
                    "wallpaper_manager", "WallpaperManager", Status.FAIL,
                    "Changing the wallpaper is disabled (device policy / restriction).",
                )
                else -> Check(
                    "wallpaper_manager", "WallpaperManager", Status.PASS,
                    "WallpaperManager available and changes allowed.",
                )
            }
        } catch (e: Exception) {
            Check(
                "wallpaper_manager", "WallpaperManager", Status.FAIL,
                "WallpaperManager unavailable: ${e.message}",
            )
        }
    }

    private fun livePickerCheck(): Check {
        val intent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER)
        val resolvable = intent.resolveActivity(context.packageManager) != null
        return Check(
            "live_picker",
            "Live wallpaper picker",
            if (resolvable) Status.PASS else Status.FAIL,
            if (resolvable) "System live-wallpaper picker is available."
            else "No live-wallpaper picker on this device.",
        )
    }

    private fun cameraFeatureCheck(): Check {
        val ok = context.packageManager
            .hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)
        return Check(
            "camera_feature",
            "Camera hardware",
            if (ok) Status.PASS else Status.FAIL,
            if (ok) "Device reports camera hardware."
            else "No camera hardware detected.",
        )
    }

    private fun rearCameraCheck(): Check {
        return try {
            val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val hasBack = manager.cameraIdList.any { id ->
                val facing = manager.getCameraCharacteristics(id)
                    .get(CameraCharacteristics.LENS_FACING)
                facing == CameraCharacteristics.LENS_FACING_BACK
            }
            Check(
                "rear_camera",
                "Rear camera",
                if (hasBack) Status.PASS else Status.FAIL,
                if (hasBack) "A rear-facing camera is present."
                else "No rear-facing camera found.",
            )
        } catch (e: Exception) {
            Check(
                "rear_camera", "Rear camera", Status.FAIL,
                "Could not query cameras: ${e.message}",
            )
        }
    }

    private fun cameraApiCheck(): Check {
        return try {
            val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val count = manager.cameraIdList.size
            Check(
                "camera_api",
                "Camera2 / CameraX",
                if (count > 0) Status.PASS else Status.FAIL,
                if (count > 0) "Camera2 API exposes $count camera(s); CameraX supported."
                else "Camera2 API exposes no cameras.",
            )
        } catch (e: Exception) {
            Check(
                "camera_api", "Camera2 / CameraX", Status.FAIL,
                "Camera2 service unavailable: ${e.message}",
            )
        }
    }

    private fun cameraPermissionCheck(): Check {
        val granted = context.checkSelfPermission(android.Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        // Not-yet-granted is expected before the user opts in — a WARN, not a FAIL.
        return Check(
            "camera_permission",
            "Camera permission",
            if (granted) Status.PASS else Status.WARN,
            if (granted) "Camera permission granted."
            else "Camera permission not yet granted (requested during setup).",
        )
    }

    private fun foregroundServiceCheck(): Check {
        // The camera foreground service is how we keep capture legal in the
        // background on Android 14+. The permission is normal (install-time).
        return Check(
            "foreground_service",
            "Foreground service",
            Status.PASS,
            "Foreground camera service available for background capture.",
        )
    }

    /**
     * Whether the camera can actually stay open behind the launcher.
     *
     * This genuinely cannot be proven statically - no API reports it - so the
     * honest answer before a first run is [Status.UNKNOWN], never a hopeful
     * PASS. Once the feature has actually run we know the answer for this exact
     * device, and record it via [recordRuntimeOutcome]; from then on the report
     * states the observed fact instead of a guess.
     */
    private fun backgroundCameraPolicyCheck(): Check {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return when (prefs.getInt(KEY_BACKGROUND_CAMERA, OUTCOME_UNKNOWN)) {
            OUTCOME_WORKED -> Check(
                "background_camera_policy",
                "Background camera policy",
                Status.PASS,
                "Verified on this device: the camera streamed behind the home " +
                    "screen.",
            )
            OUTCOME_BLOCKED -> Check(
                "background_camera_policy",
                "Background camera policy",
                Status.FAIL,
                "This device blocked the camera from staying open behind the " +
                    "home screen. Allowing unrestricted battery usage for this " +
                    "app sometimes resolves it.",
            )
            else -> Check(
                "background_camera_policy",
                "Background camera policy",
                Status.UNKNOWN,
                "Whether the camera stays open behind the home screen is " +
                    "verified at runtime on first start; some devices and OEMs " +
                    "block it.",
            )
        }
    }

    private fun manufacturerCheck(): Check {
        val make = Build.MANUFACTURER.lowercase()
        val aggressive = listOf(
            "xiaomi", "redmi", "poco", "oppo", "realme", "oneplus",
            "vivo", "iqoo", "huawei", "honor", "meizu", "letv", "asus",
        )
        val isAggressive = aggressive.any { make.contains(it) }
        val isSamsung = make.contains("samsung")
        return when {
            isAggressive -> Check(
                "manufacturer",
                "Manufacturer restrictions",
                Status.WARN,
                "${Build.MANUFACTURER} aggressively kills background camera " +
                    "services. Disabling battery optimization for this app is " +
                    "recommended for the wallpaper to keep running.",
            )
            isSamsung -> Check(
                "manufacturer",
                "Manufacturer restrictions",
                Status.WARN,
                "Samsung One UI may restrict background camera; allow " +
                    "unrestricted battery usage if the wallpaper stops.",
            )
            else -> Check(
                "manufacturer",
                "Manufacturer restrictions",
                Status.PASS,
                "${Build.MANUFACTURER}: no known blocking restrictions.",
            )
        }
    }

    // --- Aggregation -------------------------------------------------------

    /**
     * UNSUPPORTED if any hard capability fails; otherwise WARN if any check is a
     * warning or its outcome is only known at runtime; else fully SUPPORTED.
     */
    private fun levelOf(checks: List<Check>): Level {
        val hardBlockers = setOf(
            "live_wallpaper_feature", "wallpaper_manager", "live_picker",
            "camera_feature", "rear_camera", "camera_api",
            // Promoted to a hard blocker only once observed to fail on THIS
            // device - never assumed from the manufacturer name.
            "background_camera_policy",
        )
        if (checks.any { it.id in hardBlockers && it.status == Status.FAIL }) {
            return Level.UNSUPPORTED
        }
        val anyWarnOrUnknown = checks.any {
            it.status == Status.WARN || it.status == Status.UNKNOWN
        }
        return if (anyWarnOrUnknown) Level.SUPPORTED_WITH_WARNINGS else Level.SUPPORTED
    }

    private fun summaryFor(level: Level, checks: List<Check>): String = when (level) {
        Level.SUPPORTED ->
            "Your device fully supports the transparent wallpaper."
        Level.SUPPORTED_WITH_WARNINGS -> {
            val firstWarn = checks.firstOrNull {
                it.status == Status.WARN || it.status == Status.UNKNOWN
            }
            "Supported, with caveats. ${firstWarn?.detail ?: ""}".trim()
        }
        Level.UNSUPPORTED -> {
            val firstFail = checks.firstOrNull { it.status == Status.FAIL }
            "Not supported on this device. ${firstFail?.detail ?: ""}".trim()
        }
    }

    companion object {
        private const val PREFS = "transparent_prefs"
        private const val KEY_BACKGROUND_CAMERA = "bg_camera_outcome"

        private const val OUTCOME_UNKNOWN = 0
        private const val OUTCOME_WORKED = 1
        private const val OUTCOME_BLOCKED = 2

        /**
         * Records what actually happened when the wallpaper tried to stream
         * behind the launcher, turning the one check that cannot be answered
         * statically into an observed fact for this device.
         *
         * Called with `true` the first time frames flow while the wallpaper is
         * the live wallpaper, and with `false` when the camera is refused there
         * despite the foreground service running.
         */
        fun recordRuntimeOutcome(context: Context, worked: Boolean) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val current = prefs.getInt(KEY_BACKGROUND_CAMERA, OUTCOME_UNKNOWN)
            val next = if (worked) OUTCOME_WORKED else OUTCOME_BLOCKED
            // A success is sticky: one transient failure (camera busy because
            // another app had it) must not permanently mark a working device
            // as incompatible.
            if (current == OUTCOME_WORKED && !worked) return
            if (current == next) return
            prefs.edit().putInt(KEY_BACKGROUND_CAMERA, next).apply()
        }
    }
}
