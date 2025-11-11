import java.util.Properties
import java.io.FileInputStream

fun getKeystoreProperties(key: String): String {
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()

    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    } else {
        throw GradleException("keystore.properties file not found.")
    }

    return keystoreProperties.getProperty(key)
        ?: throw GradleException("Key '$key' not found in keystore.properties.")
}

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.thetact.ttact"
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
        applicationId = "com.thetact.ttact"
        minSdk = 27
        targetSdk = 35
        versionCode = 20
        versionName = "1.0.20"
        
        // FIXED: Kotlin DSL syntax for manifestPlaceholders
        manifestPlaceholders["com.google.android.gms.permission.AD_ID"] = "true"
    }
 
    // --- START: CUSTOM CODE FOR RELEASE SIGNING ---
    signingConfigs {
        create("release") {
            storeFile = file(getKeystoreProperties("storeFile"))
            storePassword = getKeystoreProperties("storePassword")
            keyAlias = getKeystoreProperties("keyAlias")
            keyPassword = getKeystoreProperties("keyPassword")
        }
    }
    // --- END: CUSTOM CODE FOR RELEASE SIGNING ---

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isShrinkResources = true
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies { 
    // FIXED: Kotlin DSL syntax for dependencies
    implementation("com.google.android.gms:play-services-ads:22.6.0")
}