plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.digitization_platform"
    compileSdk = flutter.compileSdkVersion
    // NOT where dartcv4's own NDK version is pinned - that's a separate
    // native-assets build (see pubspec.yaml's hooks.user_defines.dartcv4.
    // android.ndk_version), unaffected by this Gradle-level setting.
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.digitization_platform"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Same CameraX release the `camera_android_camerax` plugin itself pins
// (android/build.gradle there) — declared explicitly because the plugin
// brings these in as `implementation`, which keeps them off :app's own
// compile classpath even though they're merged into the APK at runtime.
// MainActivity's lens-role detection needs to call these APIs directly.
val cameraxVersion = "1.3.4"

dependencies {
    implementation("androidx.camera:camera-core:$cameraxVersion")
    implementation("androidx.camera:camera-camera2:$cameraxVersion")
    implementation("androidx.camera:camera-lifecycle:$cameraxVersion")
    // ProcessCameraProvider.getInstance() returns a Guava ListenableFuture —
    // CameraX depends on it as `implementation` too, so it's on the merged
    // APK classpath already but not :app's own compile classpath.
    implementation("com.google.guava:guava:33.0.0-android")
}

// dartcv4's native-assets build hook is pinned to a specific NDK side-by-side
// install (see pubspec.yaml -> hooks.user_defines.dartcv4.android.ndk_version)
// that's independent of the `ndkVersion` Gradle setting above. The Flutter
// tool only *looks for* that NDK during compileFlutterBuild*, it never
// installs it - so any machine whose SDK doesn't already have this exact
// version fails with "Failed to find NDK version: <version>" partway through
// the build. Installing it here keeps that self-healing regardless of which
// CI (or developer machine) runs the build, instead of depending on a
// dashboard-only pre-build step that isn't in version control.
val dartcv4NdkVersion = "26.3.11579264" // keep in sync with pubspec.yaml

val ensureDartcv4Ndk by tasks.registering(Exec::class) {
    group = "build setup"
    description = "Installs the NDK version dartcv4's native-assets build hook is pinned to, if missing."

    val androidHome = System.getenv("ANDROID_HOME") ?: System.getenv("ANDROID_SDK_ROOT")
    onlyIf { androidHome != null && !file("$androidHome/ndk/$dartcv4NdkVersion").exists() }

    doFirst {
        if (androidHome == null) {
            throw GradleException(
                "ANDROID_HOME/ANDROID_SDK_ROOT is not set; can't install NDK $dartcv4NdkVersion for dartcv4."
            )
        }
    }

    val isWindows = System.getProperty("os.name").lowercase().contains("windows")
    val sdkmanagerName = if (isWindows) "sdkmanager.bat" else "sdkmanager"
    val sdkmanagerPath = listOf(
        "$androidHome/cmdline-tools/latest/bin/$sdkmanagerName",
        "$androidHome/tools/bin/$sdkmanagerName",
    ).firstOrNull { file(it).exists() } ?: sdkmanagerName

    commandLine(sdkmanagerPath, "--install", "ndk;$dartcv4NdkVersion")
}

tasks.matching { it.name.startsWith("compileFlutterBuild") }.configureEach {
    dependsOn(ensureDartcv4Ndk)
}
