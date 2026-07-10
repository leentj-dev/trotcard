import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
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
    namespace = "dev.leentj.trot_card"
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
        applicationId = "dev.leentj.trot_card"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "트로트 카드"
        // AdMob: Google 테스트 App ID. 실제 AdMob 앱 등록 후 교체.
        manifestPlaceholders["admobAppId"] =
            "ca-app-pub-3940256099942544~3347511713"
    }

    signingConfigs {
        if (hasKeystore) {
            create("trot") {
                keyAlias = keystoreProperties["trotKeyAlias"] as String
                keyPassword = keystoreProperties["trotKeyPassword"] as String
                storeFile = file(keystoreProperties["trotStoreFile"] as String)
                storePassword = keystoreProperties["trotStorePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 릴리스 키가 있으면 사용, 없으면 디버그 서명으로 폴백해 `flutter run` 동작.
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("trot")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
