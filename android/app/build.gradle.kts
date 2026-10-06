import java.util.Properties
import java.io.FileInputStream
import java.io.File

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is read from android/key.properties (git-ignored). When the
// file or keystore is absent the release build falls back to the debug signing
// config so `flutter run --release` and CI build checks keep working.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val storeFileProp = keystoreProperties["storeFile"]?.toString()?.takeIf { it.isNotBlank() }
val resolvedStoreFile = storeFileProp?.let {
    if (File(it).isAbsolute) File(it) else File(rootProject.projectDir, it)
}
val hasReleaseKeystore = keystorePropertiesFile.exists() &&
    resolvedStoreFile != null && resolvedStoreFile.exists()

android {
    namespace = "com.example.trenzy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"]?.toString()
                keyPassword = keystoreProperties["keyPassword"]?.toString()
                storeFile = resolvedStoreFile
                storePassword = keystoreProperties["storePassword"]?.toString()
            }
        }
    }

    defaultConfig {
        // Unique store applicationId (matches the Firebase-registered Android
        // package com.trenzy.trenzy). The internal R-class `namespace` stays
        // com.example.trenzy so MainActivity resolution is unaffected.
        applicationId = "com.trenzy.trenzy"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Sign with the release keystore when android/key.properties + the
            // keystore exist; otherwise fall back to debug so builds never break.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
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
