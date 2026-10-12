package com.example.video_downloader

import android.content.Context
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import java.io.File

class BundledTools(private val context: Context) {
    private val binaries = File(context.applicationInfo.nativeLibraryDir)
    private val base = File(context.noBackupFilesDir, "youtubedl-android")
    val dataDirectory = File(context.filesDir, "universal_downloader")
    val outputDirectory = File(dataDirectory, "output")
    val python = File(binaries, "libpython.so")
    val quickJs = File(binaries, "libqjs.so")
    val ffmpeg = File(binaries, "libffmpeg.so")
    private val ffprobe = File(binaries, "libffprobe.so")
    private val ytdlp = File(base, "yt-dlp/yt-dlp")

    @Synchronized
    fun initialize(): Map<String, String> {
        YoutubeDL.init(context)
        FFmpeg.init(context)
        for (file in listOf(python, quickJs, ffmpeg, ffprobe)) {
            check(file.isFile && file.canExecute()) { "Missing APK tool: ${file.name}" }
        }
        outputDirectory.mkdirs()
        context.resources.openRawResource(com.yausername.youtubedl_android.R.raw.ytdlp).use { source ->
            ytdlp.outputStream().use { target -> source.copyTo(target) }
        }
        return mapOf(
            "dataDirectory" to dataDirectory.absolutePath,
            "quickJs" to quickJs.absolutePath,
            "ffmpeg" to ffmpeg.absolutePath,
        )
    }

    fun command(tool: String, arguments: List<String>): List<String> {
        val command = when (tool) {
            "yt-dlp" -> listOf(python.absolutePath, ytdlp.absolutePath)
            "python" -> listOf(python.absolutePath)
            "quickjs" -> listOf(quickJs.absolutePath)
            "ffmpeg" -> listOf(ffmpeg.absolutePath)
            "ffprobe" -> listOf(ffprobe.absolutePath)
            else -> throw IllegalArgumentException("Unknown bundled tool: $tool")
        }
        return listOf(
            python.absolutePath, "-c",
            "import os,sys; os.setsid(); print('UD_PID:'+str(os.getpid()),flush=True); os.execv(sys.argv[1],sys.argv[1:])",
        ) + command + arguments
    }

    fun environment(): Map<String, String> {
        val packages = File(base, "packages")
        val pythonHome = File(packages, "python/usr")
        return mapOf(
            "LD_LIBRARY_PATH" to "${File(pythonHome, "lib")}:${File(packages, "ffmpeg/usr/lib")}:${binaries}",
            "SSL_CERT_FILE" to File(pythonHome, "etc/tls/cert.pem").absolutePath,
            "PYTHONHOME" to pythonHome.absolutePath,
            "HOME" to dataDirectory.absolutePath,
            "TMPDIR" to context.cacheDir.absolutePath,
            "PATH" to "${System.getenv("PATH")}:${binaries.absolutePath}",
        )
    }
}
