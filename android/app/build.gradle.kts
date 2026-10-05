import java.io.File
import java.security.MessageDigest
import java.net.URI
import java.nio.file.Files
import java.nio.file.StandardCopyOption

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.video_downloader"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.video_downloader"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            keepDebugSymbols += "**/*.so"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
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
    implementation("io.github.junkfood02.youtubedl-android:library:0.18.1")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1")
}

val androidToolsDirectory = layout.buildDirectory.dir("generated/androidTools/res")
android.sourceSets.getByName("main").res.srcDir(androidToolsDirectory.get().asFile)
val prepareAndroidTools by tasks.registering {
    val pin = rootProject.file("../tool/android_tools.json")
    inputs.file(pin)
    val destination = androidToolsDirectory.map { it.file("raw/ytdlp") }
    outputs.file(destination)
    doLast {
        val config = groovy.json.JsonSlurper().parse(pin) as Map<*, *>
        val extractor = config["yt-dlp"] as Map<*, *>
        val expected = extractor["sha256"] as String
        val target = destination.get().asFile
        fun checksum(file: File): String {
            val digest = MessageDigest.getInstance("SHA-256")
            file.inputStream().use { input ->
                val buffer = ByteArray(65536)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    digest.update(buffer, 0, count)
                }
            }
            return digest.digest().joinToString("") { "%02x".format(it) }
        }
        if (!target.isFile || checksum(target) != expected) {
            target.parentFile.mkdirs()
            val pending = File(target.parentFile, "ytdlp.download")
            try {
                val connection = URI(extractor["url"] as String).toURL().openConnection()
                connection.connectTimeout = 30000
                connection.readTimeout = 120000
                connection.getInputStream().use { input ->
                    pending.outputStream().use { output -> input.copyTo(output) }
                }
                check(checksum(pending) == expected) { "Android yt-dlp checksum mismatch" }
                Files.move(pending.toPath(), target.toPath(),
                    StandardCopyOption.REPLACE_EXISTING)
            } finally {
                pending.delete()
            }
        }
    }
}
tasks.named("preBuild").configure { dependsOn(prepareAndroidTools) }
