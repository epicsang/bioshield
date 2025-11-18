package com.fyp.bioshield.bioshield;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.widget.TextView;

import org.json.JSONObject;

import java.util.List;

/**
 * Simple test activity to verify ContentProvider access
 * Can be launched directly without Flutter dependencies
 */
public class SimpleTestActivity extends Activity {
    private static final String TAG = "SimpleTestActivity";
    private TextView resultText;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Create simple UI
        resultText = new TextView(this);
        resultText.setPadding(40, 40, 40, 40);
        resultText.setTextSize(14);
        setContentView(resultText);

        // Test hook log reading
        testHookLogs();
    }

    private void testHookLogs() {
        StringBuilder result = new StringBuilder();
        result.append("=== BioShield Hook Log Test ===\n\n");

        try {
            // Test reading logs from vulnerable app
            String targetPackage = "com.fyp.vulnerable.vulnerable_biometric_app";
            result.append("Testing ContentProvider access...\n");
            result.append("Target: ").append(targetPackage).append("\n\n");

            List<JSONObject> logs = HookLogReader.readHookLogs(this, targetPackage);

            if (logs.isEmpty()) {
                result.append("❌ No logs found\n");
                result.append("   Make sure vulnerable app is installed\n");
            } else {
                result.append("✅ Successfully read ").append(logs.size()).append(" logs\n\n");

                for (int i = 0; i < logs.size(); i++) {
                    JSONObject log = logs.get(i);
                    result.append("--- Log ").append(i + 1).append(" ---\n");
                    result.append("Type: ").append(log.optString("type")).append("\n");
                    result.append("Code: ").append(log.optInt("code")).append("\n");
                    result.append("Elapsed: ").append(log.optLong("elapsed_ms")).append("ms\n");
                    result.append("Timestamp: ").append(log.optLong("ts")).append("\n");
                    result.append("Package: ").append(log.optString("package")).append("\n\n");
                }
            }

        } catch (SecurityException e) {
            result.append("❌ SECURITY ERROR\n");
            result.append("   Apps not signed with same keystore\n");
            result.append("   ").append(e.getMessage()).append("\n");
            Log.e(TAG, "Security error", e);

        } catch (Exception e) {
            result.append("❌ ERROR: ").append(e.getMessage()).append("\n");
            Log.e(TAG, "Test failed", e);
        }

        resultText.setText(result.toString());
        Log.d(TAG, result.toString());
    }
}
