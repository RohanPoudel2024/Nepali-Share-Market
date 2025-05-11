plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Updated Gradle configurations to fully support embedding v2
android {
    namespace = "com.example.nepse"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
    
    // Added dependencies required for Flutter embedding v2
    dependencies {
        // Flutter embedding v2 dependencies
        implementation("androidx.annotation:annotation:1.7.1")
        implementation("androidx.lifecycle:lifecycle-runtime:2.7.0")
        implementation("androidx.activity:activity:1.8.2")
        implementation("androidx.fragment:fragment:1.5.5") 
        implementation("androidx.window:window:1.0.0")
        implementation("androidx.window:window-java:1.0.0")
        
        // Add specific support for flutter_secure_storage
        implementation("androidx.security:security-crypto:1.1.0-alpha06")
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.nepse"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
