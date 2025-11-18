package com.fyp.bioshield.bioshield;

import android.content.Context;
import android.hardware.biometrics.BiometricPrompt;
import android.os.Build;
import android.util.Log;
import androidx.annotation.RequiresApi;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.HashMap;
import java.util.Map;

/**
 * HookEngine - Runtime patching for biometric callbacks
 * Intercepts BiometricPrompt.AuthenticationCallback methods
 * without needing Frida or root access
 */
public class HookEngine {
    private static final String TAG = "BioShield.HookEngine";
    private static HookEngine instance;

    private Context context;
    private LogStore logStore;
    private TimingTracker timingTracker;
    private boolean enabled = true;

    // Track hooked callbacks
    private Map<Object, Object> hookedCallbacks = new HashMap<>();

    private HookEngine(Context context) {
        this.context = context.getApplicationContext();
        this.logStore = LogStore.getInstance(context);
        this.timingTracker = TimingTracker.getInstance();
        Log.d(TAG, "HookEngine initialized");
    }

    public static synchronized HookEngine getInstance(Context context) {
        if (instance == null) {
            instance = new HookEngine(context);
        }
        return instance;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
        Log.d(TAG, "HookEngine " + (enabled ? "enabled" : "disabled"));
    }

    public boolean isEnabled() {
        return enabled;
    }

    /**
     * Hook a BiometricPrompt.AuthenticationCallback
     * Returns a proxy that intercepts all callback methods
     */
    @RequiresApi(api = Build.VERSION_CODES.P)
    public BiometricPrompt.AuthenticationCallback hookCallback(
            final BiometricPrompt.AuthenticationCallback original) {

        if (!enabled || original == null) {
            return original;
        }

        // Check if already hooked
        if (hookedCallbacks.containsKey(original)) {
            return (BiometricPrompt.AuthenticationCallback) hookedCallbacks.get(original);
        }

        Log.d(TAG, "Hooking BiometricPrompt.AuthenticationCallback");

        // Create proxy callback
        BiometricPrompt.AuthenticationCallback proxy =
            new BiometricPrompt.AuthenticationCallback() {

            private final String sessionId = generateSessionId();

            @Override
            public void onAuthenticationError(int errorCode, CharSequence errString) {
                long timestamp = System.currentTimeMillis();

                // Log the event
                Map<String, Object> logData = new HashMap<>();
                logData.put("event", "onAuthenticationError");
                logData.put("errorCode", errorCode);
                logData.put("errorMessage", errString != null ? errString.toString() : "");
                logData.put("timestamp", timestamp);
                logData.put("sessionId", sessionId);
                logData.put("threadId", Thread.currentThread().getId());

                logStore.log("BIOMETRIC_AUTH", logData);
                timingTracker.recordEvent("auth_error", errorCode);

                Log.d(TAG, String.format("[HOOK] onAuthenticationError: code=%d, msg=%s",
                    errorCode, errString));

                // Call original callback
                try {
                    original.onAuthenticationError(errorCode, errString);
                } catch (Exception e) {
                    Log.e(TAG, "Error in original callback", e);
                    logStore.logException("hook_callback_error", e);
                }
            }

            @Override
            public void onAuthenticationSucceeded(
                    BiometricPrompt.AuthenticationResult result) {
                long timestamp = System.currentTimeMillis();

                // Extract authentication details
                Map<String, Object> logData = new HashMap<>();
                logData.put("event", "onAuthenticationSucceeded");
                logData.put("timestamp", timestamp);
                logData.put("sessionId", sessionId);
                logData.put("threadId", Thread.currentThread().getId());

                if (result != null) {
                    logData.put("cryptoObject", result.getCryptoObject() != null);
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        logData.put("authenticationType", result.getAuthenticationType());
                    }
                }

                // Check timing for anomalies
                long duration = timingTracker.recordEvent("auth_success", 0);
                logData.put("duration_ms", duration);

                if (duration < 100) {
                    logData.put("timing_anomaly", "SUSPICIOUSLY_FAST");
                    Log.w(TAG, "⚠️ Auth succeeded too quickly: " + duration + "ms");
                }

                logStore.log("BIOMETRIC_AUTH", logData);

                Log.d(TAG, String.format("[HOOK] onAuthenticationSucceeded: duration=%dms",
                    duration));

                // Call original callback
                try {
                    original.onAuthenticationSucceeded(result);
                } catch (Exception e) {
                    Log.e(TAG, "Error in original callback", e);
                    logStore.logException("hook_callback_error", e);
                }
            }

            @Override
            public void onAuthenticationFailed() {
                long timestamp = System.currentTimeMillis();

                Map<String, Object> logData = new HashMap<>();
                logData.put("event", "onAuthenticationFailed");
                logData.put("timestamp", timestamp);
                logData.put("sessionId", sessionId);
                logData.put("threadId", Thread.currentThread().getId());

                logStore.log("BIOMETRIC_AUTH", logData);
                timingTracker.recordEvent("auth_failed", 0);

                Log.d(TAG, "[HOOK] onAuthenticationFailed");

                // Call original callback
                try {
                    original.onAuthenticationFailed();
                } catch (Exception e) {
                    Log.e(TAG, "Error in original callback", e);
                    logStore.logException("hook_callback_error", e);
                }
            }
        };

        // Store the hooked callback
        hookedCallbacks.put(original, proxy);

        return proxy;
    }

    /**
     * Hook androidx.biometric.BiometricPrompt.AuthenticationCallback
     * (For AndroidX compatibility)
     */
    public androidx.biometric.BiometricPrompt.AuthenticationCallback hookAndroidXCallback(
            final androidx.biometric.BiometricPrompt.AuthenticationCallback original) {

        if (!enabled || original == null) {
            return original;
        }

        // Check if already hooked
        if (hookedCallbacks.containsKey(original)) {
            return (androidx.biometric.BiometricPrompt.AuthenticationCallback)
                hookedCallbacks.get(original);
        }

        Log.d(TAG, "Hooking AndroidX BiometricPrompt.AuthenticationCallback");

        androidx.biometric.BiometricPrompt.AuthenticationCallback proxy =
            new androidx.biometric.BiometricPrompt.AuthenticationCallback() {

            private final String sessionId = generateSessionId();

            @Override
            public void onAuthenticationError(int errorCode, CharSequence errString) {
                long timestamp = System.currentTimeMillis();

                Map<String, Object> logData = new HashMap<>();
                logData.put("event", "onAuthenticationError");
                logData.put("errorCode", errorCode);
                logData.put("errorMessage", errString != null ? errString.toString() : "");
                logData.put("timestamp", timestamp);
                logData.put("sessionId", sessionId);
                logData.put("api", "androidx");

                logStore.log("BIOMETRIC_AUTH", logData);
                timingTracker.recordEvent("auth_error", errorCode);

                Log.d(TAG, String.format("[HOOK-X] onAuthenticationError: code=%d, msg=%s",
                    errorCode, errString));

                original.onAuthenticationError(errorCode, errString);
            }

            @Override
            public void onAuthenticationSucceeded(
                    androidx.biometric.BiometricPrompt.AuthenticationResult result) {
                long timestamp = System.currentTimeMillis();

                Map<String, Object> logData = new HashMap<>();
                logData.put("event", "onAuthenticationSucceeded");
                logData.put("timestamp", timestamp);
                logData.put("sessionId", sessionId);
                logData.put("api", "androidx");

                if (result != null) {
                    logData.put("cryptoObject", result.getCryptoObject() != null);
                    logData.put("authenticationType", result.getAuthenticationType());
                }

                long duration = timingTracker.recordEvent("auth_success", 0);
                logData.put("duration_ms", duration);

                if (duration < 100) {
                    logData.put("timing_anomaly", "SUSPICIOUSLY_FAST");
                }

                logStore.log("BIOMETRIC_AUTH", logData);

                Log.d(TAG, String.format("[HOOK-X] onAuthenticationSucceeded: duration=%dms",
                    duration));

                original.onAuthenticationSucceeded(result);
            }

            @Override
            public void onAuthenticationFailed() {
                long timestamp = System.currentTimeMillis();

                Map<String, Object> logData = new HashMap<>();
                logData.put("event", "onAuthenticationFailed");
                logData.put("timestamp", timestamp);
                logData.put("sessionId", sessionId);
                logData.put("api", "androidx");

                logStore.log("BIOMETRIC_AUTH", logData);
                timingTracker.recordEvent("auth_failed", 0);

                Log.d(TAG, "[HOOK-X] onAuthenticationFailed");

                original.onAuthenticationFailed();
            }
        };

        hookedCallbacks.put(original, proxy);
        return proxy;
    }

    /**
     * Clear all hooks
     */
    public void clearHooks() {
        hookedCallbacks.clear();
        Log.d(TAG, "All hooks cleared");
    }

    /**
     * Generate unique session ID for tracking
     */
    private String generateSessionId() {
        return "session_" + System.currentTimeMillis() + "_" +
            Thread.currentThread().getId();
    }

    /**
     * Get hook statistics
     */
    public Map<String, Object> getStats() {
        Map<String, Object> stats = new HashMap<>();
        stats.put("enabled", enabled);
        stats.put("hookedCallbacks", hookedCallbacks.size());
        stats.put("logCount", logStore.getLogCount());
        stats.put("timingEvents", timingTracker.getEventCount());
        return stats;
    }
}
