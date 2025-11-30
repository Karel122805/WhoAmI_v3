plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin debe ir después de Android y Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    // FlutterFire / Google Services
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.whoami_app"

    // ✅ Actualiza a SDK 36 (requerido por tus plugins)
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    // ✅ Compatibilidad con Java 17 y desugaring
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.whoami_app"
        minSdk = 24            // Flutter requiere mínimo 21, pero tus plugins usan >=24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 🔧 Configura build types
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Desugaring moderno (requerido por flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // ✅ Soporte biométrico (para local_auth)
    implementation("androidx.biometric:biometric:1.2.0-alpha05")

    // ✅ WorkManager (para futuras tareas en background)
    implementation("androidx.work:work-runtime-ktx:2.9.0")
}
