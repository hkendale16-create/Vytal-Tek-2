plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vytaltek.vytal_tek"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.vytaltek.vytal_tek"
        // QRing AAR requires minSdk 26.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            // Prefer app-packaged natives from the QRing AAR.
            useLegacyPackaging = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Official QRing Android SDK (vendored).
    implementation(files("../../../../third_party/qring/android/qring_sdk_1.0.0.60.aar"))
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.1.0")
}
