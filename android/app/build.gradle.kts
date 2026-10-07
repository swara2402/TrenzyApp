import java.util.Properties
import java.io.FileInputStream
import java.io.File

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is read from android/key.properties (git-ignored).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val requiredSigningProperties = listOf("storeFile", "keyAlias", "keyPassword", "storePassword")
val missingSigningProperties = requiredSigningProperties.filter {
    keystoreProperties.getProperty(it).isNullOrBlank()
}
val storeFileProp = keystoreProperties.getProperty("storeFile")?.takeIf { it.isNotBlank() }
val resolvedStoreFile = storeFileProp?.let {
    if (File(it).isAbsolute) File(it) else File(rootProject.projectDir, it)
}
val hasReleaseKeystore = keystorePropertiesFile.exists() &&
    missingSigningProperties.isEmpty() &&
    resolvedStoreFile != null &&
    resolvedStoreFile.isFile

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
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = resolvedStoreFile
            storePassword = keystoreProperties.getProperty("storePassword")
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
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

tasks.configureEach {
    if (name == "validateSigningRelease") {
        doFirst {
            check(keystorePropertiesFile.exists()) {
                "Release signing requires android/key.properties; refusing to create a debug-signed release APK."
            }
            check(missingSigningProperties.isEmpty()) {
                "Release signing is missing required android/key.properties entries: ${missingSigningProperties.joinToString()}"
            }
            check(resolvedStoreFile != null && resolvedStoreFile.isFile) {
                "Release signing keystore does not exist at the path configured by android/key.properties."
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
