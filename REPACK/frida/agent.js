/**
 * BioShield Frida Agent - Enhanced Timing Analysis
 * Works with frida-server on device
 *
 * Captures detailed timing metrics:
 * 1. Total authentication latency
 * 2. Acquisition duration (sensor ready → finger detected)
 * 3. Detection → match latency
 * 4. Failure timing pattern
 * 5. Variation over multiple attempts
 */

/**
 * BioShield Frida Agent - Shared Storage Mode
 * Logs biometric timing data to /storage/emulated/0/BioShield/logs/
 */

console.log("[+] BioShield Frida agent loading (Shared Storage Mode)...");

var timingHistory = [];
var currentAttempt = {
    authStart: 0,
    detectionStart: 0,
    attemptNumber: 0
};
var attemptCounter = 0;
var MAX_LOG_FILES = 50; // Keep only the last 50 log files

function ensureDir(path) {
    var File = Java.use("java.io.File");
    var dir = File.$new(path);
    if (!dir.exists()) {
        dir.mkdirs();
        console.log("[+] Created shared folder: " + path);
    }
    return dir;
}

function cleanupOldLogs(logDir) {
    try {
        var File = Java.use("java.io.File");
        var dir = File.$new(logDir);

        if (!dir.exists() || !dir.isDirectory()) {
            return;
        }

        var files = dir.listFiles();
        if (files === null || files.length <= MAX_LOG_FILES) {
            return; // Nothing to clean up
        }

        // Convert to JavaScript array and sort by last modified time (oldest first)
        var fileArray = [];
        for (var i = 0; i < files.length; i++) {
            var f = files[i];
            if (f.isFile() && f.getName().startsWith("timing_")) {
                fileArray.push({
                    file: f,
                    time: f.lastModified()
                });
            }
        }

        fileArray.sort(function(a, b) {
            return a.time - b.time; // Oldest first
        });

        // Delete oldest files to keep only MAX_LOG_FILES
        var toDelete = fileArray.length - MAX_LOG_FILES;
        if (toDelete > 0) {
            console.log("[*] Cleaning up " + toDelete + " old log files...");
            for (var i = 0; i < toDelete; i++) {
                try {
                    fileArray[i].file["delete"]();
                    console.log("[+] Deleted: " + fileArray[i].file.getName());
                } catch (e) {
                    console.log("[-] Failed to delete " + fileArray[i].file.getName() + ": " + e);
                }
            }
        }
    } catch (e) {
        console.log("[-] Error during log cleanup: " + e);
    }
}

function writeLog(data) {
    Java.perform(function() {
        try {
            var File = Java.use("java.io.File");
            var FileWriter = Java.use("java.io.FileWriter");

            var logDir = "/storage/emulated/0/BioShield/logs";
            var dir = ensureDir(logDir);
            var timestamp = new Date().toISOString().replace(/[:.]/g, "-");
            var logFile = File.$new(dir, "timing_" + timestamp + ".jsonl");

            var fw = FileWriter.$new(logFile, false);
            fw.write(JSON.stringify(data) + "\n");
            fw.close();
            console.log("[+] Logged authentication attempt: " + logFile.getAbsolutePath());

            // Clean up old logs after writing
            cleanupOldLogs(logDir);
        } catch (e) {
            console.log("[-] Error writing log: " + e);
        }
    });
}

function recordAttempt(success, startTime, endTime, failurePattern) {
    var totalLatency = endTime - startTime;
    var timingData = {
        timestamp: Date.now(),
        attempt: attemptCounter,
        success: success,
        totalLatency: totalLatency,
        failurePattern: failurePattern || null
    };
    timingHistory.push(timingData);
    writeLog(timingData);
}

Java.perform(function() {
    var SystemClock = Java.use("android.os.SystemClock");

    // --- BiometricPrompt (Android 9+) ---
    try {
        var BiometricPrompt = Java.use("android.hardware.biometrics.BiometricPrompt");

        // Helper function to create wrapped callback
        function createWrappedCallback(callback) {
            var WrappedCallback = Java.registerClass({
                name: 'com.fyp.WrappedBioCallback_' + Date.now(),
                superClass: Java.use("android.hardware.biometrics.BiometricPrompt$AuthenticationCallback"),
                methods: {
                    onAuthenticationSucceeded: function(result) {
                        var end = SystemClock.elapsedRealtime();
                        console.log("[+] BiometricPrompt: Success");
                        recordAttempt(true, currentAttempt.authStart, end);
                        return callback.onAuthenticationSucceeded(result);
                    },
                    onAuthenticationFailed: function() {
                        var end = SystemClock.elapsedRealtime();
                        console.log("[+] BiometricPrompt: Failed");
                        recordAttempt(false, currentAttempt.authStart, end, "SlowReject");
                        return callback.onAuthenticationFailed();
                    },
                    onAuthenticationError: function(code, msg) {
                        var end = SystemClock.elapsedRealtime();
                        console.log("[+] BiometricPrompt: Error " + code + " - " + msg);
                        recordAttempt(false, currentAttempt.authStart, end, "Error");
                        return callback.onAuthenticationError(code, msg);
                    },
                    onAuthenticationHelp: function(code, msg) {
                        console.log("[*] BiometricPrompt: Help " + code + " - " + msg);
                        if (currentAttempt.detectionStart === 0)
                            currentAttempt.detectionStart = SystemClock.elapsedRealtime();
                        return callback.onAuthenticationHelp(code, msg);
                    }
                }
            });
            return WrappedCallback.$new();
        }

        // Hook authenticate WITHOUT crypto (3 params)
        BiometricPrompt.authenticate.overload(
            'android.os.CancellationSignal',
            'java.util.concurrent.Executor',
            'android.hardware.biometrics.BiometricPrompt$AuthenticationCallback'
        ).implementation = function(cancel, executor, callback) {
            attemptCounter++;
            currentAttempt.authStart = SystemClock.elapsedRealtime();
            currentAttempt.attemptNumber = attemptCounter;
            console.log("[+] BiometricPrompt.authenticate() called (no-crypto, Attempt #" + attemptCounter + ")");
            return this.authenticate(cancel, executor, createWrappedCallback(callback));
        };

        // Hook authenticate WITH crypto (4 params)
        BiometricPrompt.authenticate.overload(
            'android.hardware.biometrics.BiometricPrompt$CryptoObject',
            'android.os.CancellationSignal',
            'java.util.concurrent.Executor',
            'android.hardware.biometrics.BiometricPrompt$AuthenticationCallback'
        ).implementation = function(crypto, cancel, executor, callback) {
            attemptCounter++;
            currentAttempt.authStart = SystemClock.elapsedRealtime();
            currentAttempt.attemptNumber = attemptCounter;
            console.log("[+] BiometricPrompt.authenticate() called (with-crypto, Attempt #" + attemptCounter + ")");
            return this.authenticate(crypto, cancel, executor, createWrappedCallback(callback));
        };

        console.log("[+] BiometricPrompt hooked successfully (both overloads)!");
    } catch (e) {
        console.log("[-] BiometricPrompt not available: " + e);
    }

    // --- FingerprintManager (Android 6-8) ---
    try {
        var FingerprintManager = Java.use("android.hardware.fingerprint.FingerprintManager");
        var AuthenticationCallback = Java.use("android.hardware.fingerprint.FingerprintManager$AuthenticationCallback");

        // Helper to wrap FingerprintManager callbacks
        function createWrappedFPCallback(callback) {
            var WrappedCallback = Java.registerClass({
                name: 'com.fyp.WrappedFPCallback_' + Date.now(),
                superClass: AuthenticationCallback,
                methods: {
                    onAuthenticationSucceeded: function(result) {
                        var end = SystemClock.elapsedRealtime();
                        console.log("[+] FingerprintManager: Success");
                        recordAttempt(true, currentAttempt.authStart, end);
                        return callback.onAuthenticationSucceeded(result);
                    },
                    onAuthenticationFailed: function() {
                        var end = SystemClock.elapsedRealtime();
                        console.log("[+] FingerprintManager: Failed");
                        recordAttempt(false, currentAttempt.authStart, end, "SlowReject");
                        return callback.onAuthenticationFailed();
                    },
                    onAuthenticationError: function(code, msg) {
                        var end = SystemClock.elapsedRealtime();
                        console.log("[+] FingerprintManager: Error " + code + " - " + msg);
                        recordAttempt(false, currentAttempt.authStart, end, "Error");
                        return callback.onAuthenticationError(code, msg);
                    },
                    onAuthenticationHelp: function(code, msg) {
                        console.log("[*] FingerprintManager: Help " + code + " - " + msg);
                        if (currentAttempt.detectionStart === 0)
                            currentAttempt.detectionStart = SystemClock.elapsedRealtime();
                        return callback.onAuthenticationHelp(code, msg);
                    }
                }
            });
            return WrappedCallback.$new();
        }

        // Hook authenticate WITH crypto (5 params)
        FingerprintManager.authenticate.overload(
            'android.hardware.fingerprint.FingerprintManager$CryptoObject',
            'android.os.CancellationSignal',
            'int',
            'android.hardware.fingerprint.FingerprintManager$AuthenticationCallback',
            'android.os.Handler'
        ).implementation = function(crypto, cancel, flags, callback, handler) {
            attemptCounter++;
            currentAttempt.authStart = SystemClock.elapsedRealtime();
            currentAttempt.attemptNumber = attemptCounter;
            console.log("[+] FingerprintManager.authenticate() called (with-crypto, Attempt #" + attemptCounter + ")");
            return this.authenticate(crypto, cancel, flags, createWrappedFPCallback(callback), handler);
        };

        // Hook the base AuthenticationCallback methods directly for BiometricPrompt delegation
        AuthenticationCallback.onAuthenticationSucceeded.implementation = function(result) {
            var end = SystemClock.elapsedRealtime();
            console.log("[+] FingerprintManager.AuthenticationCallback: onAuthenticationSucceeded (LEGACY FALLBACK)");
            if (currentAttempt.authStart > 0) {
                recordAttempt(true, currentAttempt.authStart, end);
            }
            return this.onAuthenticationSucceeded(result);
        };

        console.log("[+] FingerprintManager hooked successfully (with legacy fallback)!");
    } catch (e) {
        console.log("[-] FingerprintManager not available: " + e);
    }

    console.log("[+] BioShield shared storage hooks installed!");
});

