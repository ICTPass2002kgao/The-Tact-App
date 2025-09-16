
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
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
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
        targetSdk = flutter.targetSdkVersion
        versionCode = 5
        versionName = "1.0.4"
    }

    configurations.all {
        resolutionStrategy {
            force("com.stripe:financial-connections:21.20.2")
            force("com.stripe:financial-connections-core:21.20.2")
        }
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
    
    implementation("com.stripe:stripe-android:21.20.2") { // Use the latest desired version
        exclude(group = "com.stripe", module = "financial-connections")
    }
}