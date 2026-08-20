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
        // HBand / Veepoo SDK requires API 19+; keep 24+ for modern BLE permissions.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("../../../../third_party/hband/android/jniLibs")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

flutter {
    source = "../.."
}

configurations.all {
    // Vendor ships gson-2.2.4.jar; avoid duplicate Maven gson classes.
    exclude(group = "com.google.code.gson", module = "gson")
}

dependencies {
    // HBand / Veepoo Android BLE SDK (vendored from HBandSDK/Android_Ble_SDK).
    val hbandCore = "../../../../third_party/hband/android/jar_core"
    val hbandBase = "../../../../third_party/hband/android/jar_base"
    implementation(files("$hbandCore/vpprotocol-2.3.80.15.aar"))
    implementation(files("$hbandCore/vpbluetooth-1.20.aar"))
    implementation(files("$hbandBase/gson-2.2.4.jar"))
    implementation(files("$hbandCore/JL_Watch_V1.13.1_11214-release.aar"))
    implementation(files("$hbandCore/jl_rcsp_V0.7.2_527-release.aar"))
    implementation(files("$hbandCore/jl_bt_ota_V1.10.0_10931-release.aar"))
    implementation(files("$hbandCore/BmpConvert_V1.6.0_10604-release.aar"))
    implementation(files("$hbandCore/abpartool-release.aar"))
    // Optional Goodix DFU stack (safe to ship; used only for Goodix OTA).
    implementation(files("$hbandBase/libcomx-0.5.jar"))
    implementation(files("$hbandBase/libble-0.5.aar"))
    implementation(files("$hbandBase/libdfu-1.5.aar"))
    implementation(files("$hbandBase/libfastdfu-0.5.aar"))

    implementation("no.nordicsemi.android:mcumgr-core:2.7.4")
    implementation("no.nordicsemi.android:mcumgr-ble:2.7.4")
    implementation("no.nordicsemi.android.support.v18:scanner:1.4.2")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.1.0")
}
