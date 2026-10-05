package com.example.video_downloader

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.CancellationException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

class AndroidDownloadPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var tools: BundledTools
    private val main = Handler(Looper.getMainLooper())
    private val workers = Executors.newCachedThreadPool()
    private val operations = ConcurrentHashMap<String, NativeOperation>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        tools = BundledTools(context)
        channel = MethodChannel(binding.binaryMessenger, "universal_downloader/android")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "cancel") {
            operations[call.argument<String>("id")]?.cancel()
            result.success(null)
            return
        }
        if (call.method == "open") {
            try {
                val uri = Uri.parse(requireNotNull(call.argument<String>("uri")))
                require(uri.scheme == "content" && uri.authority == "media")
                context.startActivity(Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, context.contentResolver.getType(uri))
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                })
                result.success(null)
            } catch (error: Exception) {
                result.error("open_failed", "No app could open this download.", error.toString())
            }
            return
        }
        if (call.method !in listOf("initialize", "run", "publish")) {
            result.notImplemented()
            return
        }
        val id = call.argument<String>("id") ?: "initialize"
        val operation = NativeOperation()
        if (operations.putIfAbsent(id, operation) != null) {
            result.error("duplicate_operation", "Operation already exists", null)
            return
        }
        workers.execute {
            try {
                val response: Any = when (call.method) {
                    "initialize" -> tools.initialize()
                    "run" -> runCommand(call, id, operation)
                    else -> DownloadPublisher(context, tools.outputDirectory).publish(
                        requireNotNull(call.argument<List<String>>("paths")), operation,
                    )
                }
                main.post { result.success(response) }
            } catch (error: Exception) {
                val code = if (error is CancellationException) "cancelled" else "runtime_error"
                main.post { result.error(code, error.message, error.toString()) }
            } finally {
                operations.remove(id)
            }
        }
    }

    private fun runCommand(call: MethodCall, id: String, operation: NativeOperation): Map<String, Any> {
        operation.checkCancelled()
        val tool = requireNotNull(call.argument<String>("tool"))
        val arguments = requireNotNull(call.argument<List<String>>("arguments"))
        require(call.argument<Map<String, String>>("environment").isNullOrEmpty()) {
            "Android tool environment is managed by the APK"
        }
        val builder = ProcessBuilder(tools.command(tool, arguments))
        builder.environment().putAll(tools.environment())
        call.argument<String>("workingDirectory")?.let { directory ->
            val working = File(directory).canonicalFile
            require(working.toPath().startsWith(tools.dataDirectory.canonicalFile.toPath()))
            builder.directory(working)
        }
        val process = builder.start()
        operation.attach(process)
        process.outputStream.close()
        val stdout = workers.submit<String> {
            process.inputStream.bufferedReader().use { reader ->
                val output = StringBuilder()
                var first = true
                reader.forEachLine { line ->
                    if (first && line.startsWith("UD_PID:")) {
                        operation.attachGroup(line.removePrefix("UD_PID:").toInt())
                    } else {
                        output.appendLine(line)
                        main.post { channel.invokeMethod("line", mapOf("id" to id, "line" to line, "stdout" to true)) }
                    }
                    first = false
                }
                output.toString()
            }
        }
        val stderr = workers.submit<String> {
            process.errorStream.bufferedReader().use { reader ->
                val output = StringBuilder()
                reader.forEachLine { line ->
                    output.appendLine(line)
                    main.post { channel.invokeMethod("line", mapOf("id" to id, "line" to line, "stdout" to false)) }
                }
                output.toString()
            }
        }
        try {
            val code = process.waitFor()
            val out = stdout.get()
            val err = stderr.get()
            operation.checkCancelled()
            return mapOf("exitCode" to code, "stdout" to out, "stderr" to err)
        } catch (error: Exception) {
            operation.checkCancelled()
            throw error
        } finally {
            if (process.isAlive) operation.cancel()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        operations.values.forEach { it.cancel() }
        workers.shutdown()
    }
}
