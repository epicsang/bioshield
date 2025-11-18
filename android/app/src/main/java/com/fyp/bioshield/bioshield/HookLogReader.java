package com.fyp.bioshield.bioshield;

import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.util.Log;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class HookLogReader {
    private static final String TAG = "HookLogReader";
    private static final String PROVIDER_URI = "content://com.fyp.vulnerable.hookprovider/logs";

    /**
     * Callback interface for async log reading
     */
    public interface LogsCallback {
        void onLogsLoaded(List<JSONObject> logs);
        void onError(String error);
    }

    /**
     * ASYNC version - Read hook logs on background thread (RECOMMENDED)
     * This prevents UI thread blocking and black screen issues
     */
    public static void readHookLogsAsync(Context context, String targetPackage, LogsCallback callback) {
        new Thread(() -> {
            try {
                List<JSONObject> logs = readHookLogs(context, targetPackage);
                callback.onLogsLoaded(logs);
            } catch (Exception e) {
                Log.e(TAG, "Async read failed", e);
                callback.onError("Failed to read logs: " + e.getMessage());
            }
        }).start();
    }

    /**
     * SYNC version - Read hook logs (blocks calling thread - use with caution)
     * Only use this on background threads, never on UI thread
     */
    public static List<JSONObject> readHookLogs(Context context, String targetPackage) {
        List<JSONObject> logs = new ArrayList<>();

        // Build provider URI based on target package
        String providerAuthority = targetPackage + ".hookprovider";
        Uri uri = Uri.parse("content://" + providerAuthority + "/logs");

        Log.d(TAG, "Querying hook logs from: " + uri);

        try {
            Cursor cursor = context.getContentResolver().query(uri, null, null, null, null);
            if (cursor == null) {
                Log.e(TAG, "Query returned null cursor");
                return logs;
            }

            Log.d(TAG, "Cursor has " + cursor.getCount() + " rows");

            int jsonColumnIndex = cursor.getColumnIndex("json");
            if (jsonColumnIndex == -1) {
                Log.e(TAG, "Column 'json' not found in cursor");
                cursor.close();
                return logs;
            }

            while (cursor.moveToNext()) {
                try {
                    String jsonLine = cursor.getString(jsonColumnIndex);
                    JSONObject obj = new JSONObject(jsonLine);
                    logs.add(obj);
                    Log.d(TAG, "Read log: " + jsonLine);
                } catch (Exception e) {
                    Log.e(TAG, "Failed to parse JSON line", e);
                }
            }

            cursor.close();
            Log.d(TAG, "Successfully read " + logs.size() + " hook logs");
        } catch (SecurityException e) {
            Log.e(TAG, "Permission denied - apps must be signed with same key", e);
        } catch (Exception e) {
            Log.e(TAG, "Failed to read hook logs", e);
        }

        return logs;
    }

    public static void testReadLogs(Context context) {
        List<JSONObject> logs = readHookLogs(context, "com.fyp.vulnerable.vulnerable_biometric_app");
        Log.d(TAG, "Test read: Got " + logs.size() + " logs");
        for (JSONObject log : logs) {
            Log.d(TAG, "Log: " + log.toString());
        }
    }
}
