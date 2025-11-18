package com.fyp.bioshield.bioshield

import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Method channel handler for reading timing files from shared storage
 */
class SharedStorageChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "readSharedTimingFile" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    readSharedTimingFile(packageName, result)
                } else {
                    result.error("INVALID_ARGUMENT", "packageName is required", null)
                }
            }
            "deleteSharedTimingFile" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    deleteSharedTimingFile(packageName, result)
                } else {
                    result.error("INVALID_ARGUMENT", "packageName is required", null)
                }
            }
            "sendDeleteLogBroadcast" -> {
                sendDeleteLogBroadcast(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Read timing.jsonl from shared storage
     * Path: /storage/emulated/0/Android/data/[packageName]/files/logs/timing.jsonl
     */
    private fun readSharedTimingFile(packageName: String, result: MethodChannel.Result) {
        try {
            val file = File("/storage/emulated/0/Android/data/$packageName/files/logs/timing.jsonl")

            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "timing.jsonl not found for package: $packageName", null)
                return
            }

            val contents = file.readText()
            result.success(contents)
        } catch (e: Exception) {
            result.error("READ_ERROR", "Failed to read timing file: ${e.message}", null)
        }
    }

    /**
     * Delete timing.jsonl from shared storage after successful upload
     */
    private fun deleteSharedTimingFile(packageName: String, result: MethodChannel.Result) {
        try {
            val file = File("/storage/emulated/0/Android/data/$packageName/files/logs/timing.jsonl")

            if (!file.exists()) {
                result.success(false)
                return
            }

            val deleted = file.delete()
            result.success(deleted)
        } catch (e: Exception) {
            result.error("DELETE_ERROR", "Failed to delete timing file: ${e.message}", null)
        }
    }

    /**
     * Send DELETE_LOG broadcast to Frida agent
     */
    private fun sendDeleteLogBroadcast(result: MethodChannel.Result) {
        try {
            val intent = Intent("com.bioshield.DELETE_LOG")
            context.sendBroadcast(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("BROADCAST_ERROR", "Failed to send DELETE_LOG broadcast: ${e.message}", null)
        }
    }
}
