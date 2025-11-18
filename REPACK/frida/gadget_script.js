/**
 * BioShield Frida Gadget Script
 * Hooks BiometricPrompt API calls and outputs encrypted logs
 * Compatible with script mode (auto-executes on app start)
 */

// Redirect console.log to Android logcat
console.log = function(msg) {
    try {
        Java.perform(() => {
            const Log = Java.use("android.util.Log");
            Log.i("FRIDA_BIOSHIELD", String(msg));
        });
    } catch (e) {}
};

console.log("[BioShield] Frida Gadget script loading...");

// AES-256-GCM encryption settings (matches BioShield)
const AES_KEY_B64 = "W7Yy9Np3F2e8Dqz0pY6Qv0T92oLk12BxVZtq8lZhg7s=";
const IV = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]; // 12 bytes of zeros
const LOG_PATH = "/storage/emulated/0/Download/BioShield/logs.jsonl";

/**
 * Encrypt log entry with AES-256-GCM
 */
function encryptLog(jsonString) {
    try {
        Java.perform(() => {
            const Base64 = Java.use("android.util.Base64");
            const Cipher = Java.use("javax.crypto.Cipher");
            const SecretKeySpec = Java.use("javax.crypto.spec.SecretKeySpec");
            const GCMParameterSpec = Java.use("javax.crypto.spec.GCMParameterSpec");

            // Decode key from Base64
            const keyBytes = Base64.decode(AES_KEY_B64, 2); // NO_WRAP flag
            const key = SecretKeySpec.$new(keyBytes, "AES");

            // Create IV
            const ivBytes = Java.array('byte', IV);
            const spec = GCMParameterSpec.$new(128, ivBytes);

            // Encrypt
            const cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE.value, key, spec);

            const plainBytes = Java.use("java.lang.String").$new(jsonString).getBytes("UTF-8");
            const encryptedBytes = cipher.doFinal(plainBytes);

            // Encode to Base64 (NO_WRAP to prevent line breaks)
            return Base64.encodeToString(encryptedBytes, 2); // NO_WRAP flag
        });
    } catch (e) {
        console.log("[ERROR] Encryption failed: " + e);
        return null;
    }
}

/**
 * Write encrypted log to file
 */
function writeLog(logData) {
    Java.perform(() => {
        try {
            const File = Java.use("java.io.File");
            const FileWriter = Java.use("java.io.FileWriter");
            const PrintWriter = Java.use("java.io.PrintWriter");

            // Ensure directory exists
            const dir = File.$new("/storage/emulated/0/Download/BioShield");
            if (!dir.exists()) {
                dir.mkdirs();
            }

            // Convert to JSON and encrypt
            const json = JSON.stringify(logData);
            const encrypted = encryptLog(json);

            if (encrypted) {
                // Append to log file
                const fw = FileWriter.$new(LOG_PATH, true); // append mode
                const pw = PrintWriter.$new(fw);
                pw.println(encrypted);
                pw.close();

                console.log("[BioShield] Log written: " + logData.event);
            }
        } catch (e) {
            console.log("[ERROR] Write log failed: " + e);
        }
    });
}

// AUTO-EXECUTE: Hook BiometricPrompt when app starts
Java.perform(() => {
    console.log("[BioShield] Java.perform() executing...");

    try {
        // Hook androidx.biometric.BiometricPrompt (AndroidX library)
        const BiometricPrompt = Java.use("androidx.biometric.BiometricPrompt");
        console.log("[BioShield] Found androidx.biometric.BiometricPrompt");

        // Hook authenticate() method WITHOUT CryptoObject
        BiometricPrompt.authenticate.overload(
            'androidx.biometric.BiometricPrompt$PromptInfo'
        ).implementation = function(promptInfo) {
            const startTime = Date.now();

            console.log("[BioShield] BiometricPrompt.authenticate() called (no crypto)");

            // Get title from PromptInfo
            let title = "Unknown";
            try {
                title = promptInfo.getTitle().toString();
            } catch (e) {}

            // Log authentication start
            writeLog({
                event: "androidx_auth_started",
                timestamp: startTime,
                title: title,
                method: "BiometricPrompt"
            });

            // Call original method
            return this.authenticate(promptInfo);
        };

        // Hook authenticate() method WITH CryptoObject
        BiometricPrompt.authenticate.overload(
            'androidx.biometric.BiometricPrompt$PromptInfo',
            'androidx.biometric.BiometricPrompt$CryptoObject'
        ).implementation = function(promptInfo, cryptoObject) {
            const startTime = Date.now();

            console.log("[BioShield] BiometricPrompt.authenticate() called (with crypto)");

            let title = "Unknown";
            try {
                title = promptInfo.getTitle().toString();
            } catch (e) {}

            writeLog({
                event: "androidx_auth_started",
                timestamp: startTime,
                title: title,
                method: "BiometricPrompt",
                crypto: true
            });

            return this.authenticate(promptInfo, cryptoObject);
        };

        console.log("[BioShield] BiometricPrompt.authenticate() hooked!");

        // Hook AuthenticationCallback to capture results
        const AuthCallback = Java.use("androidx.biometric.BiometricPrompt$AuthenticationCallback");

        AuthCallback.onAuthenticationSucceeded.implementation = function(result) {
            console.log("[BioShield] Authentication SUCCEEDED");

            writeLog({
                event: "success",
                timestamp: Date.now(),
                method: "BiometricPrompt",
                success: 1
            });

            return this.onAuthenticationSucceeded(result);
        };

        AuthCallback.onAuthenticationFailed.implementation = function() {
            console.log("[BioShield] Authentication FAILED");

            writeLog({
                event: "failed",
                timestamp: Date.now(),
                method: "BiometricPrompt",
                success: 0
            });

            return this.onAuthenticationFailed();
        };

        AuthCallback.onAuthenticationError.implementation = function(errorCode, errString) {
            console.log("[BioShield] Authentication ERROR: " + errorCode + " - " + errString);

            writeLog({
                event: "error",
                timestamp: Date.now(),
                method: "BiometricPrompt",
                errorCode: errorCode,
                errorMsg: errString.toString(),
                success: 0
            });

            return this.onAuthenticationError(errorCode, errString);
        };

        console.log("[BioShield] AuthenticationCallback hooked!");

    } catch (e) {
        console.log("[ERROR] Failed to hook androidx.biometric: " + e);
    }

    // Also try to hook android.hardware.biometrics.BiometricPrompt (framework API)
    try {
        const BiometricPromptFramework = Java.use("android.hardware.biometrics.BiometricPrompt");
        console.log("[BioShield] Found android.hardware.biometrics.BiometricPrompt");

        // Hook both overloads of authenticate()
        BiometricPromptFramework.authenticate.overload(
            'android.os.CancellationSignal',
            'java.util.concurrent.Executor',
            'android.hardware.biometrics.BiometricPrompt$AuthenticationCallback'
        ).implementation = function(cancel, executor, callback) {
            console.log("[BioShield] Framework BiometricPrompt.authenticate() called (no crypto)");

            writeLog({
                event: "framework_auth_started",
                timestamp: Date.now(),
                method: "BiometricPrompt"
            });

            return this.authenticate(cancel, executor, callback);
        };

        BiometricPromptFramework.authenticate.overload(
            'android.hardware.biometrics.BiometricPrompt$CryptoObject',
            'android.os.CancellationSignal',
            'java.util.concurrent.Executor',
            'android.hardware.biometrics.BiometricPrompt$AuthenticationCallback'
        ).implementation = function(crypto, cancel, executor, callback) {
            console.log("[BioShield] Framework BiometricPrompt.authenticate() called (with crypto)");

            writeLog({
                event: "framework_auth_started",
                timestamp: Date.now(),
                method: "BiometricPrompt",
                crypto: true
            });

            return this.authenticate(crypto, cancel, executor, callback);
        };

        console.log("[BioShield] Framework BiometricPrompt hooked!");

    } catch (e) {
        console.log("[INFO] Framework BiometricPrompt not available: " + e);
    }

    console.log("[BioShield] All hooks installed successfully!");
});
