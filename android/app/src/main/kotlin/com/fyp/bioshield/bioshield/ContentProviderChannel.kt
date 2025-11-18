package com.fyp.bioshield.bioshield

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * ContentProviderChannel - MethodChannel handler for ContentProvider IPC
 *
 * Handles Flutter method calls for reading logs from hooked apps via ContentProvider
 */
class ContentProviderChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "ContentProviderChannel"
        const val CHANNEL_NAME = "com.fyp.bioshield/contentprovider"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "readLogs" -> {
                val authority = call.argument<String>("authority")
                val path = call.argument<String>("path") ?: "logs"

                if (authority == null) {
                    result.error("INVALID_ARGS", "Authority is required", null)
                    return
                }

                try {
                    val logs = ContentProviderReader.readLogs(context, authority, path)
                    result.success(logs)
                    Log.d(TAG, "Successfully read logs from $authority/$path")
                } catch (e: SecurityException) {
                    result.error("PERMISSION_DENIED",
                        "Permission denied: ${e.message}", null)
                } catch (e: Exception) {
                    result.error("READ_ERROR",
                        "Failed to read logs: ${e.message}", null)
                }
            }

            "readTimingLogs" -> {
                val authority = call.argument<String>("authority")

                if (authority == null) {
                    result.error("INVALID_ARGS", "Authority is required", null)
                    return
                }

                try {
                    val logs = ContentProviderReader.readTimingLogs(context, authority)
                    result.success(logs)
                    Log.d(TAG, "Successfully read timing logs from $authority")
                } catch (e: Exception) {
                    result.error("READ_ERROR",
                        "Failed to read timing logs: ${e.message}", null)
                }
            }

            "readGeneralLogs" -> {
                val authority = call.argument<String>("authority")

                if (authority == null) {
                    result.error("INVALID_ARGS", "Authority is required", null)
                    return
                }

                try {
                    val logs = ContentProviderReader.readGeneralLogs(context, authority)
                    result.success(logs)
                    Log.d(TAG, "Successfully read general logs from $authority")
                } catch (e: Exception) {
                    result.error("READ_ERROR",
                        "Failed to read general logs: ${e.message}", null)
                }
            }

            "clearLogs" -> {
                val authority = call.argument<String>("authority")

                if (authority == null) {
                    result.error("INVALID_ARGS", "Authority is required", null)
                    return
                }

                try {
                    val deletedCount = ContentProviderReader.clearLogs(context, authority)
                    result.success(deletedCount)
                    Log.d(TAG, "Cleared $deletedCount log files from $authority")
                } catch (e: SecurityException) {
                    result.error("PERMISSION_DENIED",
                        "Permission denied: ${e.message}", null)
                } catch (e: Exception) {
                    result.error("CLEAR_ERROR",
                        "Failed to clear logs: ${e.message}", null)
                }
            }

            "isProviderAvailable" -> {
                val authority = call.argument<String>("authority")

                if (authority == null) {
                    result.error("INVALID_ARGS", "Authority is required", null)
                    return
                }

                try {
                    val available = ContentProviderReader.isProviderAvailable(context, authority)
                    result.success(available)
                } catch (e: Exception) {
                    result.success(false)
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }
}
