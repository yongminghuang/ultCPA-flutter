plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val signingValues = mapOf(
    "path" to System.getenv("ULTCPA_KEYSTORE_PATH"),
    "storePassword" to System.getenv("ULTCPA_KEYSTORE_PASSWORD"),
    "keyAlias" to System.getenv("ULTCPA_KEY_ALIAS"),
    "keyPassword" to System.getenv("ULTCPA_KEY_PASSWORD"),
)
val hasLegacySigning = signingValues.values.all { !it.isNullOrBlank() }

android {
    namespace = "com.xmzj.ult.agg"
    compileSdk = 34

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
            "Release signing requires ULTCPA_KEYSTORE_PATH, " +
                "ULTCPA_KEYSTORE_PASSWORD, ULTCPA_KEY_ALIAS, and " +
                "ULTCPA_KEY_PASSWORD",
        )
    }
}

flutter {
    source = "../.."
}
