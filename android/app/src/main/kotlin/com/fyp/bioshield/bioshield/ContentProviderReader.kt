package com.fyp.bioshield.bioshield

import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * ContentProviderReader - Reads biometric hook logs from hooked apps via ContentProvider IPC
 *
 * Architecture:
 * Vulnerable App (Hooked)
 * ├─ HookEngine intercepts biometric events
 * ├─ TimingTracker writes to local JSONL file
 * └─ HookLogProvider exposes via ContentProvider
 *     ↓ (IPC via ContentProvider)
 * BioShield App
 * └─ Reads logs from ContentProvider authority
 */
object ContentProviderReader {
    private const val TAG = "ContentProviderReader"

    /**
     * Read all logs from a hooked app's ContentProvider
     *
     * @param context Android context
     * @param authority ContentProvider authority (e.g., "com.example.app.hookprovider")
     * @param path Path to query (e.g., "logs", "timing", "general")
     * @return JSON string containing array of log events
     */
    fun readLogs(context: Context, authority: String, path: String = "data"): String {
        try {
            Log.d(TAG, "Reading logs from authority: $authority, path: /$path")

            val uri = Uri.parse("content://$authority/$path")
            val cursor: Cursor? = context.contentResolver.query(
                uri,
                null, // All columns
                null, // No selection
                null, // No selection args
                null  // No sort order
            )

            if (cursor == null) {
                Log.w(TAG, "ContentProvider query returned null cursor")
                return "[]"
            }

            val jsonArray = JSONArray()

            cursor.use {
                // Try Frida format first (single "data" column with JSONL content)
                val dataIndex = it.getColumnIndex("data")

                if (dataIndex != -1) {
                    Log.d(TAG, "Using Frida ContentProvider format (data column)")

                    if (it.moveToFirst()) {
                        val jsonlContent = it.getString(dataIndex)
                        Log.d(TAG, "Received JSONL content: ${jsonlContent.length} bytes")

                        // Parse JSONL (each line is a JSON object)
                        jsonlContent.trim().split("\n").forEach { line ->
                            if (line.isNotBlank()) {
                                try {
                                    val logEvent = JSONObject(line)
                                    jsonArray.put(logEvent)
                                } catch (e: Exception) {
                                    Log.e(TAG, "Failed to parse JSONL line: $line", e)
                                }
                            }
                        }
                    }
                } else {
                    // Fall back to old format (json column)
                    Log.d(TAG, "Using legacy ContentProvider format (json column)")
                    val jsonIndex = it.getColumnIndex("json")
                    val sourceIndex = it.getColumnIndex("source")

                    if (jsonIndex == -1) {
                        Log.e(TAG, "Neither 'data' nor 'json' column found in cursor")
                        return "[]"
                    }

                    while (it.moveToNext()) {
                        val jsonString = it.getString(jsonIndex)
                        val source = if (sourceIndex != -1) it.getString(sourceIndex) else "unknown"

                        try {
                            val logEvent = JSONObject(jsonString)
                            logEvent.put("_source", source)
                            jsonArray.put(logEvent)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to parse JSON line: $jsonString", e)
                        }
                    }
                }
            }

            Log.d(TAG, "Successfully read ${jsonArray.length()} log events")
            return jsonArray.toString()

        } catch (e: SecurityException) {
            Log.e(TAG, "Permission denied when accessing ContentProvider: ${e.message}")
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read logs from ContentProvider", e)
            throw e
        }
    }

    /**
     * Read only timing logs (enhanced 12-feature events)
     */
    fun readTimingLogs(context: Context, authority: String): String {
        return readLogs(context, authority, "timing")
    }

    /**
     * Read only general logs (LogStore events)
     */
    fun readGeneralLogs(context: Context, authority: String): String {
        return readLogs(context, authority, "general")
    }

    /**
     * Clear all logs from a hooked app's ContentProvider
     *
     * @param context Android context
     * @param authority ContentProvider authority
     * @return Number of log files deleted
     */
    fun clearLogs(context: Context, authority: String): Int {
        try {
            Log.d(TAG, "Clearing logs from authority: $authority")

            val uri = Uri.parse("content://$authority/logs")
            val deletedCount = context.contentResolver.delete(uri, null, null)

            Log.d(TAG, "Deleted $deletedCount log files")
            return deletedCount

        } catch (e: SecurityException) {
            Log.e(TAG, "Permission denied when clearing logs: ${e.message}")
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Failed to clear logs from ContentProvider", e)
            throw e
        }
    }

    /**
     * Check if a hooked app has a ContentProvider available
     *
     * @param context Android context
     * @param authority ContentProvider authority
     * @return true if ContentProvider is accessible
     */
    fun isProviderAvailable(context: Context, authority: String): Boolean {
        return try {
            val uri = Uri.parse("content://$authority/logs")
            val cursor = context.contentResolver.query(uri, null, null, null, null)
            cursor?.close()
            true
        } catch (e: Exception) {
            Log.d(TAG, "Provider not available: ${e.message}")
            false
        }
    }
}
