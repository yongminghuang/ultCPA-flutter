import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localSigningProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.exists()) {
        propertiesFile.inputStream().use(::load)
    }
}
val signingValues = mapOf(
    "path" to (localSigningProperties.getProperty("storeFile")
        ?: System.getenv("ULTCPA_KEYSTORE_PATH")),
    "storePassword" to (localSigningProperties.getProperty("storePassword")
        ?: System.getenv("ULTCPA_KEYSTORE_PASSWORD")),
    "keyAlias" to (localSigningProperties.getProperty("keyAlias")
        ?: System.getenv("ULTCPA_KEY_ALIAS")),
    "keyPassword" to (localSigningProperties.getProperty("keyPassword")
        ?: System.getenv("ULTCPA_KEY_PASSWORD")),
)
val hasLegacySigning = signingValues.values.all { !it.isNullOrBlank() }

android {
    namespace = "com.xmzj.ult.agg"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        applicationId = "com.xmzj.ult.agg"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = 26071018
        versionName = "1.2.5"
    }

    flavorDimensions += "channel"
    productFlavors {
        listOf(
            "dev", "dev_prod", "douyin",
            "honor", "oppo", "vivo", "mi", "qihoo", "baidu",
            "tencent", "aliapp", "lenovo", "huawei", "meizu", "qnm",
            "kuaishou",
        ).forEach { channelName ->
            create(channelName) {
                dimension = "channel"
                val channelLabel = if (channelName == "dev_prod") "dev" else channelName
                buildConfigField("String", "ULTCPA_CHANNEL", "\"$channelLabel\"")
                manifestPlaceholders["ULTCPA_CHANNEL"] = channelLabel
            }
        }
    }

    signingConfigs {
        create("legacyRelease") {
            if (hasLegacySigning) {
                storeFile = file(signingValues.getValue("path")!!)
                storePassword = signingValues.getValue("storePassword")
                keyAlias = signingValues.getValue("keyAlias")
                keyPassword = signingValues.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            if (hasLegacySigning) {
                signingConfig = signingConfigs.getByName("legacyRelease")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any {
        it.name.contains("Release", ignoreCase = true)
    }
    if (releaseRequested && !hasLegacySigning) {
        throw GradleException(
            "Release signing requires android/key.properties or the " +
                "ULTCPA_KEYSTORE_PATH, ULTCPA_KEYSTORE_PASSWORD, " +
                "ULTCPA_KEY_ALIAS, and ULTCPA_KEY_PASSWORD environment variables",
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.tencent:mmkv-static:1.2.8")
    implementation("com.tencent.mm.opensdk:wechat-sdk-android:6.8.30")
    implementation("com.alipay.sdk:alipaysdk-android:15.8.42@aar")
}
