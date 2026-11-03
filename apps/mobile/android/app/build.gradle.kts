import java.util.Base64
import org.gradle.api.DefaultTask
import org.gradle.api.file.DirectoryProperty
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.OutputDirectory
import org.gradle.api.tasks.TaskAction

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter supplies the same ignored configuration file for CLI and Android Studio.
// Decode only the Android SDK credential here. Never log dart-defines or keys.
val waydayDefines = providers.gradleProperty("dart-defines")
    .orNull.orEmpty().split(",")
    .mapNotNull { encoded ->
        runCatching { String(Base64.getDecoder().decode(encoded), Charsets.UTF_8) }.getOrNull()
    }
    .mapNotNull { value -> value.indexOf('=').takeIf { it > 0 }?.let { value.substring(0, it) to value.substring(it + 1) } }
    .toMap()
val googleMapsAndroidApiKey = waydayDefines["GOOGLE_MAPS_ANDROID_API_KEY"].orEmpty()
val publicBuild = waydayDefines["WAYDAY_PUBLIC_BUILD"] == "true"
val publicTest = waydayDefines["WAYDAY_PUBLIC_TEST"] == "true"
if (publicTest) {
    require(publicBuild) { "The isolated public test requires server-backed access." }
    require(providers.gradleProperty("WAYDAY_MAP_TEST").orNull != "true") { "Public verification and private map fixtures must remain separate." }
    val testTarget = providers.gradleProperty("target").orNull.orEmpty().replace('\\', '/')
    require(listOf("lib/main_public_test.dart", "lib/main.dart").any { testTarget == it || testTarget.endsWith("/$it") }) {
        "The isolated public test requires an explicit connection-check or full-app entry point."
    }
}
if (publicBuild) {
    require(listOf("GEMINI_API_KEY", "GOOGLE_ROUTES_API_KEY", "GEOAPIFY_API_KEY", "LOCATIONIQ_API_KEY").none { !waydayDefines[it].isNullOrBlank() }) {
        "Public builds must not contain private provider build defines."
    }
}
if (gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }) {
    require(publicBuild) { "Release builds require WAYDAY_PUBLIC_BUILD=true and server-backed provider access." }
}
fun buildString(value: String) = "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r") + "\""

android {
    namespace = "dev.wayday.wayday"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    buildFeatures { buildConfig = true }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.wayday.wayday"
        if (publicTest) applicationIdSuffix = ".publictest"
        manifestPlaceholders["waydayAppLabel"] = if (publicTest) "Wayday Test" else "Wayday"
        manifestPlaceholders["waydaySourceCommit"] = waydayDefines["WAYDAY_SOURCE_COMMIT"] ?: "local"
        manifestPlaceholders["waydayReleaseProfile"] = waydayDefines["WAYDAY_RELEASE_PROFILE_SHA"] ?: "local"
        buildConfigField("boolean", "WAYDAY_PUBLIC_BUILD", publicBuild.toString())
        for (key in listOf("WAYDAY_GATEWAY_URL", "WAYDAY_FIREBASE_APP_ID", "WAYDAY_FIREBASE_API_KEY", "WAYDAY_FIREBASE_PROJECT_ID", "WAYDAY_RECAPTCHA_SITE_KEY")) {
            buildConfigField("String", key, buildString(waydayDefines[key].orEmpty()))
        }
        manifestPlaceholders["waydayGoogleMapsApiKey"] = googleMapsAndroidApiKey
        // Flutter integration tests uninstall their target by default. Isolate
        // the memory-only map harness from the owner's installed personal data.
        // Dart normalizes Windows environment keys to uppercase.
        if (providers.gradleProperty("WAYDAY_MAP_TEST").orNull == "true") {
            applicationIdSuffix = ".maptest"
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (System.getenv("WAYDAY_RELEASE_STORE_FILE") != null) {
            create("waydayRelease") {
                storeFile = file(System.getenv("WAYDAY_RELEASE_STORE_FILE"))
                storePassword = System.getenv("WAYDAY_RELEASE_STORE_PASSWORD")
                keyAlias = System.getenv("WAYDAY_RELEASE_KEY_ALIAS")
                keyPassword = System.getenv("WAYDAY_RELEASE_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        release {
            proguardFiles("proguard-rules.pro")
            // No silent debug signing. CI verification uses a disposable test key;
            // public publication requires the separately protected release key.
            signingConfig = signingConfigs.findByName("waydayRelease")
        }
    }
}

abstract class BundleWaydayPlacesFont : DefaultTask() {
    @get:InputFile abstract val fontFile: RegularFileProperty
    @get:OutputDirectory abstract val outputDirectory: DirectoryProperty
    @TaskAction fun bundle() {
        val fontDirectory = outputDirectory.get().dir("font").asFile
        fontDirectory.mkdirs()
        fontFile.get().asFile.copyTo(fontDirectory.resolve("figtree.ttf"), overwrite = true)
    }
}
val bundleWaydayPlacesFont = tasks.register<BundleWaydayPlacesFont>("bundleWaydayPlacesFont") {
    fontFile.set(layout.projectDirectory.file("../../assets/fonts/Figtree.ttf"))
    outputDirectory.set(layout.buildDirectory.dir("generated/wayday-fonts"))
}
androidComponents.onVariants { variant ->
    variant.sources.res?.addGeneratedSourceDirectory(bundleWaydayPlacesFont, BundleWaydayPlacesFont::outputDirectory)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Navigation embeds the Google Maps classes. Places UI Kit must use that copy
// rather than adding a second play-services-maps implementation.
configurations.configureEach {
    exclude(group = "com.google.android.gms", module = "play-services-maps")
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:35.1.0"))
    implementation("com.google.firebase:firebase-appcheck-recaptcha")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.5")
    // Match google_navigation_flutter 0.11.2: native Places bridge also imports LatLng.
    implementation("com.google.android.libraries.navigation:navigation:7.9.0")
    implementation("com.google.android.libraries.places:places:6.0.2")
    implementation("com.google.android.material:material:1.13.0")
    // Navigation core only: keep Flutter's pinned OpenGL map renderer.
    // 5.0.1 requires compile SDK 37; this integration retains the current SDK.
    implementation("org.maplibre.navigation:navigation-core-android:5.0.0") {
        exclude(group = "org.maplibre.gl", module = "android-sdk")
    }
    // 13.7.1 fixes PMTiles asset byte ranges and queries during map detachment.
    // Keep this paired with maplibre_gl 0.27.1 until a verified plugin upgrade.
    implementation("org.maplibre.gl:android-sdk-opengl") {
        version { strictly("13.7.1") }
    }
}
