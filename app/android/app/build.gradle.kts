import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials.
//
// Loaded from `android/key.properties`, which is gitignored and MUST NOT be
// committed. Nothing secret ever appears in this file or in any build output.
//
// Expected keys (see android/key.properties.example):
//   storeFile, storePassword, keyAlias, keyPassword
//
// `storeFile` may be absolute, or relative to the `android/` directory.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

/** Resolves `storeFile` and returns it only when the keystore actually exists. */
val resolvedKeystore: File? = keystoreProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let { path ->
        val f = File(path)
        val resolved = if (f.isAbsolute) f else rootProject.file(path)
        resolved.takeIf { it.exists() }
    }

val hasReleaseSigning = resolvedKeystore != null &&
    !keystoreProperties.getProperty("keyAlias").isNullOrBlank()

android {
    namespace = "com.backgrounds.trend4k"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // MUST match the existing Google Play listing exactly. Changing this
        // creates a NEW application on Play rather than updating the existing
        // one, and orphans every installed user's data.
        applicationId = "com.backgrounds.trend4k"
        // Android 10+ required for the wallpaper + live-wallpaper feature set.
        minSdk = 29
        // Google Play: new apps AND app updates must target API 36 from
        // Aug 31 2026 (API 35 only keeps an un-updated listing visible).
        targetSdk = 36
        // Driven by pubspec.yaml `version: <name>+<code>`, overridable per build
        // with `flutter build appbundle --build-name=... --build-number=...`.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = resolvedKeystore
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // Debug keys keep `flutter run --release` working locally. This
                // is NEVER acceptable for an uploaded artifact - the task-graph
                // guard below refuses to build a bundle without real signing.
                signingConfigs.getByName("debug")
            }
            // R8 is off deliberately. The wallpaper services, the Flutter
            // embedding and the CameraX lifecycle are all reflection- and
            // manifest-driven; enabling shrinking here without a tested
            // keep-ruleset risks stripping a WallpaperService at runtime, which
            // would only surface after release. Turn it on as its own change,
            // with its own device test.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

/**
 * Refuses to build an App Bundle that is not signed with the real upload key.
 *
 * This runs at task-graph resolution, BEFORE any task executes. An earlier
 * version hooked `bundleRelease` with `doFirst`, which fails too late:
 * `bundleRelease` is a lifecycle task, and `packageReleaseBundle` has already
 * written a debug-signed .aab to build/outputs by then. A failed build that
 * still leaves an uploadable-looking artifact on disk is worse than no guard at
 * all, so the check has to happen before the graph starts running.
 *
 * `assembleRelease` is deliberately NOT guarded, so `flutter run --release` on a
 * local device keeps working.
 */
gradle.taskGraph.whenReady {
    if (hasReleaseSigning) return@whenReady
    // Match the exact tasks that PRODUCE the .aab, by name. A loose
    // `name.contains("bundle")` also catches `...ForBundle` manifest tasks that
    // `assembleRelease` pulls in, which would wrongly block local release APK
    // builds - so the set is explicit.
    val bundleTaskNames = setOf("bundleRelease", "packageReleaseBundle", "signReleaseBundle")
    val bundleTask = allTasks.firstOrNull { it.name in bundleTaskNames }
        ?: return@whenReady

    throw GradleException(
        """
        |Release signing is not configured - refusing to build an App Bundle
        |(requested task: ${bundleTask.name}).
        |
        |Create android/key.properties (see android/key.properties.example)
        |with storeFile / storePassword / keyAlias / keyPassword pointing at
        |the UPLOAD key for applicationId com.backgrounds.trend4k.
        |
        |key.properties and *.jks are gitignored and must stay uncommitted.
        """.trimMargin()
    )
}

flutter {
    source = "../.."
}

dependencies {
    // CameraX — powers the transparent (live rear-camera) wallpaper engine.
    // 1.4.0+ required: 1.3.x ships libimage_processing_util_jni.so at 4KB
    // page alignment, failing Google Play's 16KB page-size requirement.
    val cameraxVersion = "1.5.1"
    implementation("androidx.camera:camera-core:$cameraxVersion")
    implementation("androidx.camera:camera-camera2:$cameraxVersion")
    implementation("androidx.camera:camera-lifecycle:$cameraxVersion")
    // PreviewView for the in-app live preview (PlatformView).
    implementation("androidx.camera:camera-view:$cameraxVersion")
    // Manual LifecycleOwner used to drive CameraX from the wallpaper engine.
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.6.2")

    // Guava, required explicitly for CameraX's ListenableFuture API.
    //
    // CameraX exposes `ProcessCameraProvider.getInstance()` as a
    // ListenableFuture. Guava publishes an intentionally EMPTY
    // `listenablefuture:9999.0-empty-to-avoid-conflict-with-guava` artifact so
    // the class is not duplicated when full Guava is present. video_player
    // (ExoPlayer/media3) pulls in that stub, and on the COMPILE classpath it
    // won the conflict with no real Guava alongside it - so the class
    // disappeared and every CameraX call site failed to compile.
    //
    // Declaring real Guava puts ListenableFuture back on the compile
    // classpath. Keep this while both CameraX and video_player are present.
    implementation("com.google.guava:guava:33.3.1-android")
}
