import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin debe ir después de Android y Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    // FlutterFire / Google Services
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.whoami_app"

    // SDK requerido por tus plugins
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    // Compatibilidad con Java 17 y desugaring
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
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Firma de release usando android/key.properties
    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties["storeFile"] as String
            storeFile = rootProject.file(storeFilePath)  // Asegúrate de que el path sea correcto
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
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
    // Desugaring moderno (requerido por flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Soporte biométrico (para local_auth)
    implementation("androidx.biometric:biometric:1.2.0-alpha05")

    // WorkManager (para futuras tareas en background)
    implementation("androidx.work:work-runtime-ktx:2.9.0")
}
