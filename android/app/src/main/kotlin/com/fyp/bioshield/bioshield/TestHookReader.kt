package com.fyp.bioshield.bioshield

import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.util.Log

object TestHookReader {
    private const val TAG = "TestHookReader"

    fun testReadLogs(context: Context) {
        val uri = Uri.parse("content://com.fyp.vulnerable.hookprovider/logs")
        Log.d(TAG, "Testing ContentProvider access to: $uri")

        try {
            val cursor: Cursor? = context.contentResolver.query(uri, null, null, null, null)

            if (cursor == null) {
                Log.e(TAG, "Query returned null cursor")
                return
            }

            Log.d(TAG, "✓ ContentProvider accessible!")
            Log.d(TAG, "Cursor has ${cursor.count} rows")
            Log.d(TAG, "Columns: ${cursor.columnNames.joinToString(", ")}")

            val jsonColumnIndex = cursor.getColumnIndex("json")
            if (jsonColumnIndex == -1) {
                Log.e(TAG, "Column 'json' not found")
                cursor.close()
                return
            }

            var count = 0
            while (cursor.moveToNext()) {
                val jsonLine = cursor.getString(jsonColumnIndex)
                Log.d(TAG, "Log[$count]: $jsonLine")
                count++
            }

            cursor.close()
            Log.d(TAG, "✓ Successfully read $count hook logs")

        } catch (e: SecurityException) {
            Log.e(TAG, "✗ Permission denied - apps not signed with same key", e)
        } catch (e: Exception) {
            Log.e(TAG, "✗ Failed to read hook logs", e)
        }
    }
}
