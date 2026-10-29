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
val googleMapsAndroidApiKey = providers.gradleProperty("dart-defines")
    .orNull.orEmpty().split(",")
    .mapNotNull { encoded ->
        runCatching { String(Base64.getDecoder().decode(encoded), Charsets.UTF_8) }.getOrNull()
    }
    .lastOrNull { it.startsWith("GOOGLE_MAPS_ANDROID_API_KEY=") }
    ?.substringAfter("=").orEmpty()

android {
    namespace = "dev.wayday.wayday"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.wayday.wayday"
        manifestPlaceholders["waydayGoogleMapsApiKey"] = googleMapsAndroidApiKey
        // Flutter integration tests uninstall their target by default. Isolate
        // the memory-only map harness from the owner's installed personal data.
        // Dart normalizes Windows environment keys to uppercase.
        if (providers.gradleProperty("WAYDAY_MAP_TEST").orNull == "true") {
            applicationIdSuffix = ".maptest"
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
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

dependencies {
    implementation("com.google.android.libraries.places:places:6.0.2")
    implementation("com.google.android.material:material:1.13.0")
    // 13.7.1 fixes PMTiles asset byte ranges and queries during map detachment.
    // Keep this paired with maplibre_gl 0.27.1 until a verified plugin upgrade.
    implementation("org.maplibre.gl:android-sdk-opengl") {
        version { strictly("13.7.1") }
    }
}
