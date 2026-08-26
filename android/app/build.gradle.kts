import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    // ИСПРАВЛЕНО: Теперь соответствует твоему google-services.json
    namespace = "com.iqmarket.app" 
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.iqmarket.app" 
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                val properties = Properties()
                properties.load(FileInputStream(keystorePropertiesFile))
                val storeProp = properties.getProperty("storeFile") ?: "upload-keystore.jks"
                val resolvedFile = when {
                    file(storeProp).exists() -> file(storeProp)
                    rootProject.file(storeProp).exists() -> rootProject.file(storeProp)
                    file("upload-keystore.jks").exists() -> file("upload-keystore.jks")
                    rootProject.file("upload-keystore.jks").exists() -> rootProject.file("upload-keystore.jks")
                    else -> file(storeProp)
                }
                storeFile = resolvedFile
                storePassword = properties.getProperty("storePassword")?.takeIf { it.isNotBlank() } ?: "iqmarket2026"
                keyAlias = properties.getProperty("keyAlias")?.takeIf { it.isNotBlank() } ?: "upload"
                keyPassword = properties.getProperty("keyPassword")?.takeIf { it.isNotBlank() } ?: "iqmarket2026"
            }
        }
    }

    buildTypes {
        release {
            // В CI key.properties отсутствует (в .gitignore) — падаем на debug-подпись,
            // чтобы CI мог собрать тестовый APK. Локально key.properties есть, поведение не меняется.
            signingConfig = if (rootProject.file("key.properties").exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
