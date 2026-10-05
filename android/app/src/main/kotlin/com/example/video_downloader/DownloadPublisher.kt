package com.example.video_downloader

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import java.io.File
import java.util.UUID

class DownloadPublisher(private val context: Context, private val outputDirectory: File) {
    fun publish(paths: List<String>, operation: NativeOperation): String {
        require(paths.isNotEmpty()) { "No files to publish" }
        val files = paths.map { path ->
            File(path).canonicalFile.also {
                require(it.parentFile == outputDirectory.canonicalFile && it.isFile) {
                    "Only completed app downloads can be published"
                }
            }
        }
        val resolver = context.contentResolver
        val folderName = files.first().nameWithoutExtension.take(80) + "_" + UUID.randomUUID().toString().take(8)
        val folder = "${Environment.DIRECTORY_DOWNLOADS}/UniversalDownloader/$folderName/"
        val pending = mutableListOf<Uri>()
        try {
            for (file in files) {
                operation.checkCancelled()
                val mime = when (file.extension.lowercase()) {
                    "mkv" -> "video/x-matroska"
                    "vtt" -> "text/vtt"
                    "srt" -> "application/x-subrip"
                    else -> MimeTypeMap.getSingleton().getMimeTypeFromExtension(file.extension.lowercase())
                        ?: "application/octet-stream"
                }
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, file.name)
                    put(MediaStore.Downloads.MIME_TYPE, mime)
                    put(MediaStore.Downloads.RELATIVE_PATH, folder)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val uri = checkNotNull(resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values))
                pending.add(uri)
                file.inputStream().use { source ->
                    checkNotNull(resolver.openOutputStream(uri)).use { target ->
                        val buffer = ByteArray(256 * 1024)
                        while (true) {
                            operation.checkCancelled()
                            val count = source.read(buffer)
                            if (count < 0) break
                            target.write(buffer, 0, count)
                        }
                        target.flush()
                    }
                }
            }
            operation.commit {
                for (uri in pending) {
                    val values = ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }
                    check(resolver.update(uri, values, null, null) == 1) { "Could not publish download" }
                }
            }
            return pending.first().toString()
        } catch (error: Exception) {
            for (uri in pending) {
                try { resolver.delete(uri, null, null) } catch (_: Exception) { }
            }
            throw error
        }
    }
}
