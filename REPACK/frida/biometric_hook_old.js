// assets/frida_scripts/biometric_hook.js
// Frida script to hook biometric authentication APIs and detect vulnerabilities
// This runs inside the target app via Frida Gadget

console.log("[*] Biometric Security Analysis - Frida Hook Started");

// Global storage for timing data
var timingData = [];
var biometricAttempts = 0;
var vulnerabilities = [];

// Function to send data back to main app
function sendData(type, data) {
    // This would send via local socket or file
    console.log(JSON.stringify({
        type: type,
        timestamp: Date.now(),
        data: data
    }));
}

// Hook BiometricPrompt.authenticate()
Java.perform(function() {
    console.log("[*] Hooking BiometricPrompt APIs");
    
    // Hook BiometricPrompt class
    try {
        var BiometricPrompt = Java.use("androidx.biometric.BiometricPrompt");
        
        BiometricPrompt.authenticate.overload('androidx.biometric.BiometricPrompt$PromptInfo').implementation = function(promptInfo) {
            var startTime = Date.now();
            console.log("[+] BiometricPrompt.authenticate() called");
            biometricAttempts++;
            
            sendData("biometric_start", {
                attempt: biometricAttempts,
                timestamp: startTime
            });
            
            // Call original method
            var result = this.authenticate(promptInfo);
            
            var endTime = Date.now();
            var duration = endTime - startTime;
            
            timingData.push({
                attempt: biometricAttempts,
                duration: duration,
                timestamp: startTime
            });
            
            // Analyze timing for side-channel attacks
            if (timingData.length >= 3) {
                analyzeTiming();
            }
            
            sendData("biometric_end", {
                attempt: biometricAttempts,
                duration: duration,
                timingData: timingData
            });
            
            return result;
        };
        
        console.log("[+] BiometricPrompt.authenticate() hooked successfully");
    } catch (e) {
        console.log("[-] Error hooking BiometricPrompt: " + e);
    }
    
    // Hook FingerprintManager (legacy API)
    try {
        var FingerprintManager = Java.use("android.hardware.fingerprint.FingerprintManager");
        
        FingerprintManager.authenticate.overload(
            'android.hardware.fingerprint.FingerprintManager$CryptoObject',
            'android.os.CancellationSignal',
            'int',
            'android.hardware.fingerprint.FingerprintManager$AuthenticationCallback',
            'android.os.Handler'
        ).implementation = function(crypto, cancel, flags, callback, handler) {
            console.log("[+] FingerprintManager.authenticate() called (Legacy API)");
            
            var startTime = Date.now();
            
            vulnerabilities.push({
                type: "deprecated_api",
                severity: "medium",
                message: "Using deprecated FingerprintManager API instead of BiometricPrompt"
            });
            
            sendData("vulnerability_detected", vulnerabilities[vulnerabilities.length - 1]);
            
            // Call original
            var result = this.authenticate(crypto, cancel, flags, callback, handler);
            
            var duration = Date.now() - startTime;
            sendData("legacy_auth", {
                duration: duration,
                crypto: crypto !== null
            });
            
            return result;
        };
        
        console.log("[+] FingerprintManager hooked successfully");
    } catch (e) {
        console.log("[-] FingerprintManager not available (expected on Android 10+)");
    }
    
    // Hook CryptoObject usage
    try {
        var CryptoObject = Java.use("androidx.biometric.BiometricPrompt$CryptoObject");
        var Cipher = Java.use("javax.crypto.Cipher");
        
        // Check if crypto is properly initialized
        BiometricPrompt.authenticate.overload(
            'androidx.biometric.BiometricPrompt$PromptInfo',
            'androidx.biometric.BiometricPrompt$CryptoObject'
        ).implementation = function(promptInfo, cryptoObject) {
            console.log("[+] BiometricPrompt.authenticate() with CryptoObject called");
            
            if (cryptoObject === null || cryptoObject === undefined) {
                vulnerabilities.push({
                    type: "weak_crypto",
                    severity: "high",
                    message: "Biometric authentication without cryptographic binding detected"
                });
                sendData("vulnerability_detected", vulnerabilities[vulnerabilities.length - 1]);
            } else {
                console.log("[+] CryptoObject present - good security practice");
                sendData("security_check", {
                    type: "crypto_present",
                    status: "pass"
                });
            }
            
            return this.authenticate(promptInfo, cryptoObject);
        };
    } catch (e) {
        console.log("[-] CryptoObject hooking failed: " + e);
    }
    
    // Hook AuthenticationCallback for success/failure analysis
    try {
        var AuthCallback = Java.use("androidx.biometric.BiometricPrompt$AuthenticationCallback");
        
        AuthCallback.onAuthenticationSucceeded.implementation = function(result) {
            console.log("[+] Authentication SUCCEEDED");
            var endTime = Date.now();
            
            sendData("auth_result", {
                success: true,
                timestamp: endTime,
                result: result.toString()
            });
            
            return this.onAuthenticationSucceeded(result);
        };
        
        AuthCallback.onAuthenticationFailed.implementation = function() {
            console.log("[+] Authentication FAILED");
            var endTime = Date.now();
            
            sendData("auth_result", {
                success: false,
                timestamp: endTime
            });
            
            return this.onAuthenticationFailed();
        };
        
        AuthCallback.onAuthenticationError.implementation = function(errorCode, errString) {
            console.log("[+] Authentication ERROR: " + errorCode + " - " + errString);
            
            sendData("auth_error", {
                errorCode: errorCode,
                message: errString.toString(),
                timestamp: Date.now()
            });
            
            return this.onAuthenticationError(errorCode, errString);
        };
        
        console.log("[+] AuthenticationCallback hooked successfully");
    } catch (e) {
        console.log("[-] AuthenticationCallback hook failed: " + e);
    }
});

// Timing analysis function for side-channel detection
function analyzeTiming() {
    if (timingData.length < 3) return;
    
    var durations = timingData.map(function(d) { return d.duration; });
    var avg = durations.reduce(function(a, b) { return a + b; }) / durations.length;
    var variance = durations.reduce(function(sum, d) { 
        return sum + Math.pow(d - avg, 2); 
    }, 0) / durations.length;
    var stdDev = Math.sqrt(variance);
    
    console.log("[*] Timing Analysis - Avg: " + avg + "ms, StdDev: " + stdDev + "ms");
    
    // Check for timing side-channel vulnerability
    if (stdDev > 50) {
        vulnerabilities.push({
            type: "timing_side_channel",
            severity: "high",
            message: "High timing variance detected (" + stdDev.toFixed(2) + "ms) - potential side-channel leak",
            statistics: {
                average: avg,
                stdDev: stdDev,
                samples: timingData.length
            }
        });
        sendData("vulnerability_detected", vulnerabilities[vulnerabilities.length - 1]);
    }
    
    sendData("timing_analysis", {
        average: avg,
        stdDev: stdDev,
        variance: variance,
        samples: timingData.length,
        data: timingData
    });
}

// Hook sensor access for deeper analysis
Java.perform(function() {
    try {
        var SensorManager = Java.use("android.hardware.SensorManager");
        
        SensorManager.registerListener.overload(
            'android.hardware.SensorEventListener',
            'android.hardware.Sensor',
            'int'
        ).implementation = function(listener, sensor, rate) {
            var sensorType = sensor.getType();
            console.log("[+] Sensor registered: Type=" + sensorType + ", Rate=" + rate);
            
            // Check if biometric sensors are accessed properly
            sendData("sensor_access", {
                type: sensorType,
                rate: rate,
                timestamp: Date.now()
            });
            
            return this.registerListener(listener, sensor, rate);
        };
    } catch (e) {
        console.log("[-] SensorManager hook failed: " + e);
    }
});

console.log("[*] All hooks installed. Monitoring biometric authentication...");
