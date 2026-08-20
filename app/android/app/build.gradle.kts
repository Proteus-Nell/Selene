import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. The keystore itself never enters the repository: this reads
// android/key.properties, which is gitignored, and which points at a .jks file
// kept outside the working tree. Losing that file means every installed copy of
// the app is stranded — Android will not accept an upgrade signed by a
// different key — so docs/RELEASE.md treats backing it up as part of the
// release, not as housekeeping.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

// Opt-in strictness for a build that is actually going to be distributed.
// Without it the release build falls back to the debug key so that CI, and
// `flutter run --release` on a fresh clone, still work. With it, a missing
// keystore fails the build rather than quietly producing an APK that no device
// will ever accept an upgrade to.
val releaseSigningRequired =
    (project.findProperty("release-signing-required") as String?)?.toBoolean() ?: false

android {
    namespace = "io.github.proteusnell.period_tracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (task AND-17). Harmless otherwise.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "io.github.proteusnell.period_tracker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 8.0. Native java.time and modern notification channels. PLAN.md 3.5.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                if (releaseSigningRequired) {
                    throw GradleException(
                        "Release signing was required but android/key.properties is missing. " +
                            "See docs/RELEASE.md, or drop -Prelease-signing-required=true to " +
                            "build an install-only APK signed with the debug key."
                    )
                }
                project.logger.warn(
                    "WARNING: android/key.properties not found; signing the release build with " +
                        "the DEBUG key. This APK must not be distributed - see docs/RELEASE.md."
                )
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
