System.clearProperty("ANDROID_PREFS_ROOT")
System.clearProperty("android.prefs.root")

runCatching {
    val pe = Class.forName("java.lang.ProcessEnvironment")
    for (fName in listOf("theEnvironment", "theCaseInsensitiveEnvironment")) {
        runCatching {
            val f = pe.getDeclaredField(fName)
            f.isAccessible = true
            (f.get(null) as? MutableMap<*, *>)?.keys?.removeIf { it.toString().equals("ANDROID_PREFS_ROOT", ignoreCase = true) }
        }
    }
    runCatching {
        val f = pe.getDeclaredField("theUnmodifiableEnvironment")
        f.isAccessible = true
        val unmod = f.get(null)
        if (unmod != null) {
            val mF = unmod.javaClass.getDeclaredField("m")
            mF.isAccessible = true
            (mF.get(unmod) as? MutableMap<*, *>)?.keys?.removeIf { it.toString().equals("ANDROID_PREFS_ROOT", ignoreCase = true) }
        }
    }
}

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
