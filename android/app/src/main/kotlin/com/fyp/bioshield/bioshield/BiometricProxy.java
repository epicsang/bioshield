package com.fyp.bioshield.bioshield;

import android.content.Context;
import android.hardware.biometrics.BiometricPrompt;
import android.os.Build;
import android.os.CancellationSignal;
import android.util.Log;
import androidx.annotation.RequiresApi;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.Executor;

/**
 * BiometricProxy - Intercepts BiometricPrompt authentication attempts
 * Acts as a transparent wrapper around the system BiometricPrompt
 */
public class BiometricProxy {
    private static final String TAG = "BioShield.BiometricProxy";
    private static BiometricProxy instance;

    private Context context;
    private HookEngine hookEngine;
    private LogStore logStore;
    private TimingTracker timingTracker;

    private BiometricProxy(Context context) {
        this.context = context.getApplicationContext();
        this.hookEngine = HookEngine.getInstance(context);
        this.logStore = LogStore.getInstance(context);
        this.timingTracker = TimingTracker.getInstance();
        Log.d(TAG, "BiometricProxy initialized");
    }

    public static synchronized BiometricProxy getInstance(Context context) {
        if (instance == null) {
            instance = new BiometricProxy(context);
        }
        return instance;
    }

    /**
     * Wrap BiometricPrompt.authenticate() call
     * Intercepts the authentication request before it reaches the system
     */
    @RequiresApi(api = Build.VERSION_CODES.P)
    public void interceptAuthenticate(
            BiometricPrompt prompt,
            BiometricPrompt.CryptoObject crypto,
            CancellationSignal cancel,
            Executor executor,
            BiometricPrompt.AuthenticationCallback callback) {

        Log.d(TAG, "=== Biometric Authentication Intercepted ===");

        // Start timing
        timingTracker.startSession();

        // Log authentication attempt
        Map<String, Object> logData = new HashMap<>();
        logData.put("event", "auth_attempt");
        logData.put("timestamp", System.currentTimeMillis());
        logData.put("hasCrypto", crypto != null);
        logData.put("hasCancellation", cancel != null);
        logData.put("api", "BiometricPrompt");
        logData.put("sdkInt", Build.VERSION.SDK_INT);

        // Gather context information
        logData.put("packageName", context.getPackageName());
        logData.put("processName", getProcessName());

        if (crypto != null) {
            logData.put("cryptoType", getCryptoType(crypto));
        }

        logStore.log("BIOMETRIC_AUTH", logData);

        // Hook the callback to intercept results
        BiometricPrompt.AuthenticationCallback hookedCallback =
            hookEngine.hookCallback(callback);

        // Proceed with original authentication
        try {
            if (crypto != null) {
                prompt.authenticate(crypto, cancel, executor, hookedCallback);
            } else {
                prompt.authenticate(cancel, executor, hookedCallback);
            }

            Log.d(TAG, "✓ Authentication request forwarded to system");

        } catch (Exception e) {
            Log.e(TAG, "Error during authentication", e);
            logStore.logException("auth_intercept_error", e);

            // Still try to call the original callback with error
            if (callback != null) {
                callback.onAuthenticationError(
                    BiometricPrompt.BIOMETRIC_ERROR_HW_UNAVAILABLE,
                    "BioShield: " + e.getMessage()
                );
            }
        }
    }

    /**
     * Wrap AndroidX BiometricPrompt.authenticate() call
     */
    public void interceptAndroidXAuthenticate(
            androidx.biometric.BiometricPrompt prompt,
            androidx.biometric.BiometricPrompt.PromptInfo promptInfo,
            androidx.biometric.BiometricPrompt.AuthenticationCallback callback) {

        Log.d(TAG, "=== AndroidX Biometric Authentication Intercepted ===");

        timingTracker.startSession();

        // Log authentication attempt
        Map<String, Object> logData = new HashMap<>();
        logData.put("event", "auth_attempt");
        logData.put("timestamp", System.currentTimeMillis());
        logData.put("api", "androidx.biometric");
        logData.put("packageName", context.getPackageName());

        // Extract prompt info
        if (promptInfo != null) {
            logData.put("title", promptInfo.getTitle());
            logData.put("subtitle", promptInfo.getSubtitle());
            logData.put("description", promptInfo.getDescription());
            logData.put("negativeButtonText", promptInfo.getNegativeButtonText());
            logData.put("isConfirmationRequired", promptInfo.isConfirmationRequired());

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                logData.put("allowedAuthenticators", promptInfo.getAllowedAuthenticators());
            }
        }

        logStore.log("BIOMETRIC_AUTH", logData);

        // Hook the callback
        androidx.biometric.BiometricPrompt.AuthenticationCallback hookedCallback =
            hookEngine.hookAndroidXCallback(callback);

        // Proceed with authentication
        try {
            prompt.authenticate(promptInfo, hookedCallback);
            Log.d(TAG, "✓ AndroidX authentication request forwarded");

        } catch (Exception e) {
            Log.e(TAG, "Error during AndroidX authentication", e);
            logStore.logException("androidx_auth_intercept_error", e);
        }
    }

    /**
     * Wrap AndroidX BiometricPrompt.authenticate() with CryptoObject
     */
    public void interceptAndroidXAuthenticateWithCrypto(
            androidx.biometric.BiometricPrompt prompt,
            androidx.biometric.BiometricPrompt.PromptInfo promptInfo,
            androidx.biometric.BiometricPrompt.CryptoObject crypto,
            androidx.biometric.BiometricPrompt.AuthenticationCallback callback) {

        Log.d(TAG, "=== AndroidX Biometric Authentication (with Crypto) Intercepted ===");

        timingTracker.startSession();

        Map<String, Object> logData = new HashMap<>();
        logData.put("event", "auth_attempt");
        logData.put("timestamp", System.currentTimeMillis());
        logData.put("hasCrypto", true);
        logData.put("api", "androidx.biometric");
        logData.put("packageName", context.getPackageName());

        if (crypto != null) {
            logData.put("cryptoType", getAndroidXCryptoType(crypto));
        }

        if (promptInfo != null) {
            logData.put("title", promptInfo.getTitle());
            logData.put("negativeButtonText", promptInfo.getNegativeButtonText());
        }

        logStore.log("BIOMETRIC_AUTH", logData);

        // Hook the callback
        androidx.biometric.BiometricPrompt.AuthenticationCallback hookedCallback =
            hookEngine.hookAndroidXCallback(callback);

        // Proceed with authentication
        try {
            prompt.authenticate(promptInfo, crypto, hookedCallback);
            Log.d(TAG, "✓ AndroidX authentication (crypto) request forwarded");

        } catch (Exception e) {
            Log.e(TAG, "Error during AndroidX crypto authentication", e);
            logStore.logException("androidx_crypto_auth_intercept_error", e);
        }
    }

    /**
     * Monitor BiometricPrompt builder calls
     */
    @RequiresApi(api = Build.VERSION_CODES.P)
    public void logPromptBuilder(BiometricPrompt.Builder builder) {
        Map<String, Object> logData = new HashMap<>();
        logData.put("event", "prompt_builder");
        logData.put("timestamp", System.currentTimeMillis());
        logData.put("api", "BiometricPrompt");

        logStore.log("BIOMETRIC_CONFIG", logData);
        Log.d(TAG, "BiometricPrompt.Builder detected");
    }

    /**
     * Monitor AndroidX BiometricPrompt.PromptInfo.Builder
     */
    public void logAndroidXPromptBuilder(
            androidx.biometric.BiometricPrompt.PromptInfo.Builder builder) {

        Map<String, Object> logData = new HashMap<>();
        logData.put("event", "prompt_builder");
        logData.put("timestamp", System.currentTimeMillis());
        logData.put("api", "androidx.biometric");

        logStore.log("BIOMETRIC_CONFIG", logData);
        Log.d(TAG, "AndroidX BiometricPrompt.PromptInfo.Builder detected");
    }

    /**
     * Get crypto object type
     */
    @RequiresApi(api = Build.VERSION_CODES.P)
    private String getCryptoType(BiometricPrompt.CryptoObject crypto) {
        if (crypto.getCipher() != null) return "Cipher";
        if (crypto.getSignature() != null) return "Signature";
        if (crypto.getMac() != null) return "Mac";
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (crypto.getIdentityCredential() != null) return "IdentityCredential";
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (crypto.getPresentationSession() != null) return "PresentationSession";
        }
        return "Unknown";
    }

    /**
     * Get AndroidX crypto object type
     */
    private String getAndroidXCryptoType(androidx.biometric.BiometricPrompt.CryptoObject crypto) {
        if (crypto.getCipher() != null) return "Cipher";
        if (crypto.getSignature() != null) return "Signature";
        if (crypto.getMac() != null) return "Mac";
        return "Unknown";
    }

    /**
     * Get process name
     */
    private String getProcessName() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                return android.app.Application.getProcessName();
            }
        } catch (Exception e) {
            // Fallback
        }
        return "unknown";
    }

    /**
     * Get proxy statistics
     */
    public Map<String, Object> getStats() {
        Map<String, Object> stats = new HashMap<>();
        stats.put("logCount", logStore.getLogCount());
        stats.put("sessionCount", timingTracker.getSessionCount());
        stats.put("hookEngineStats", hookEngine.getStats());
        return stats;
    }
}
