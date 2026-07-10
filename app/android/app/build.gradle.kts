import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "dev.leentj.kpop_hangul"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Overridden per product flavor below.
        applicationId = "dev.leentj.kpop_hangul"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystore) {
            create("kpop") {
                keyAlias = keystoreProperties["kpopKeyAlias"] as String
                keyPassword = keystoreProperties["kpopKeyPassword"] as String
                storeFile = file(keystoreProperties["kpopStoreFile"] as String)
                storePassword = keystoreProperties["kpopStorePassword"] as String
            }
            create("jpop") {
                keyAlias = keystoreProperties["jpopKeyAlias"] as String
                keyPassword = keystoreProperties["jpopKeyPassword"] as String
                storeFile = file(keystoreProperties["jpopStoreFile"] as String)
                storePassword = keystoreProperties["jpopStorePassword"] as String
            }
        }
    }

    flavorDimensions += "app"
    productFlavors {
        create("kpop") {
            dimension = "app"
            applicationId = "dev.leentj.kpop_hangul"
            manifestPlaceholders["appLabel"] = "K-pop Hangul"
            manifestPlaceholders["admobAppId"] =
                "ca-app-pub-6232115093331648~5603947943"
            if (hasKeystore) signingConfig = signingConfigs.getByName("kpop")
        }
        create("jpop") {
            dimension = "app"
            applicationId = "dev.leentj.jpop_kana"
            manifestPlaceholders["appLabel"] = "J-pop Kana"
            // jpop has no AdMob app yet — keep Google's test App ID.
            manifestPlaceholders["admobAppId"] =
                "ca-app-pub-3940256099942544~3347511713"
            if (hasKeystore) signingConfig = signingConfigs.getByName("jpop")
        }
    }

    buildTypes {
        release {
            // Per-flavor release keys apply when key.properties exists;
            // otherwise fall back to debug signing so `flutter run` still works.
            if (!hasKeystore) {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
