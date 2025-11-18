package com.fyp.bioshield.bioshield

import android.os.FileObserver
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

/**
 * Native FileObserver implementation for real-time Frida event monitoring
 * Uses Android's FileObserver API for instant file creation notifications
 */
class FileObserverChannel(private val eventSink: EventChannel.EventSink?) {

    private var fileObserver: FileObserver? = null
    private var watchPath: String? = null

    /**
     * Start watching a directory for new file creation events
     */
    fun startWatching(path: String) {
        // Stop existing observer if any
        stopWatching()

        watchPath = path

        // Ensure directory exists
        val dir = File(path)
        if (!dir.exists()) {
            dir.mkdirs()
        }

        // Create FileObserver for CREATE events only
        fileObserver = object : FileObserver(path, CREATE) {
            override fun onEvent(event: Int, filename: String?) {
                if (event == CREATE && filename != null && filename.endsWith(".json")) {
                    // New JSON file created - notify Flutter
                    val filePath = "$path/$filename"

                    // Read and parse the file
                    try {
                        val file = File(filePath)
                        val contents = file.readText()

                        // Send to Flutter via EventChannel
                        eventSink?.success(mapOf(
                            "type" to "file_created",
                            "path" to filePath,
                            "filename" to filename,
                            "contents" to contents,
                            "timestamp" to System.currentTimeMillis()
                        ))

                        // Optionally delete processed file to prevent clutter
                        // file.delete()

                    } catch (e: Exception) {
                        eventSink?.error("READ_ERROR", "Failed to read file: ${e.message}", null)
                    }
                }
            }
        }

        fileObserver?.startWatching()
    }

    /**
     * Stop watching the directory
     */
    fun stopWatching() {
        fileObserver?.stopWatching()
        fileObserver = null
        watchPath = null
    }

    /**
     * Check if currently watching
     */
    fun isWatching(): Boolean {
        return fileObserver != null
    }
}

/**
 * Method channel handler for FileObserver control
 */
class FileObserverMethodHandler(private val observerChannel: FileObserverChannel) : MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startWatching" -> {
                val path = call.argument<String>("path")
                if (path != null) {
                    observerChannel.startWatching(path)
                    result.success(true)
                } else {
                    result.error("INVALID_PATH", "Path is required", null)
                }
            }
            "stopWatching" -> {
                observerChannel.stopWatching()
                result.success(true)
            }
            "isWatching" -> {
                result.success(observerChannel.isWatching())
            }
            else -> {
                result.notImplemented()
            }
        }
    }
}
