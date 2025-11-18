// === BIOSHIELD FRIDA GADGET SCRIPT ===
// Hooks androidx.biometric.BiometricPrompt and logs encrypted data to shared storage

// FIX 1: Redirect console.log to Android Logcat
console.log = function(msg) {
    try {
        Java.perform(() => {
            const Log = Java.use("android.util.Log");
            Log.i("FRIDA_SCRIPT", String(msg));
        });
    } catch (e) {
        // Fallback to original console if Java not ready
    }
};
console.error = console.log;
console.warn = console.log;

console.log("=== [BioShield] Frida Gadget Loaded ===");

// === AES ENCRYPTION SETUP ===
const AES_KEY_B64 = "W7Yy9Np3F2e8Dqz0pY6Qv0T92oLk12BxVZtq8lZhg7s=";
const LOG_PATH = "/storage/emulated/0/Download/BioShield/logs.jsonl";

// AES-GCM encryption function using Java Cipher
function encrypt(text) {
    let encrypted = "";
    Java.perform(() => {
        try {
            const Cipher = Java.use("javax.crypto.Cipher");
            const SecretKeySpec = Java.use("javax.crypto.spec.SecretKeySpec");
            const GCMParameterSpec = Java.use("javax.crypto.spec.GCMParameterSpec");
            const Base64 = Java.use("android.util.Base64");

            // Decode base64 key
            const keyBytes = Base64.decode(AES_KEY_B64, 0);
            const key = SecretKeySpec.$new(keyBytes, "AES");

            // Static IV (12 bytes of zeros)
            const iv = Java.array('byte', [0,0,0,0,0,0,0,0,0,0,0,0]);
            const spec = GCMParameterSpec.$new(128, iv);

            // Encrypt
            const cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(1, key, spec); // ENCRYPT_MODE = 1

            const String = Java.use("java.lang.String");
            const plainBytes = String.$new(text).getBytes("UTF-8");
            const encryptedBytes = cipher.doFinal(plainBytes);

            encrypted = Base64.encodeToString(encryptedBytes, 0);
        } catch (e) {
            console.log("[ERROR] Encryption failed: " + e);
        }
    });
    return encrypted;
}

// Create directory if needed
function ensureDirectory() {
    Java.perform(() => {
        try {
            const File = Java.use("java.io.File");
            const dir = File.$new("/storage/emulated/0/Download/BioShield");
            if (!dir.exists()) {
                dir.mkdirs();
                console.log("[+] Created directory: /storage/emulated/0/Download/BioShield");
            }
        } catch (e) {
            console.log("[-] Directory creation failed: " + e);
        }
    });
}

// Append encrypted log
function writeLog(obj) {
    Java.perform(() => {
        try {
            const File = Java.use("java.io.File");
            const FileWriter = Java.use("java.io.FileWriter");
            const BufferedWriter = Java.use("java.io.BufferedWriter");

            const json = JSON.stringify(obj);
            const encrypted = encrypt(json);

            const logFile = File.$new(LOG_PATH);
            const fw = FileWriter.$new(logFile, true); // append mode
            const bw = BufferedWriter.$new(fw);

            bw.write(encrypted);
            bw.newLine();
            bw.close();

            console.log("[+] Encrypted log written: " + obj.event);
        } catch (e) {
            console.log("[ERROR] Write failed: " + e);
        }
    });
}

rpc.exports = {
    init(stage, parameters) {
        console.log("=== [BioShield] init() called, stage: " + stage + " ===");

        ensureDirectory();

        Java.perform(() => {
            console.log("=== [BioShield] Java.perform OK ===");

            // ==========
            // 1) Hook BiometricPrompt Constructor
            // ==========
            try {
                const BP = Java.use("androidx.biometric.BiometricPrompt");

                BP.$init.overload(
                    "androidx.fragment.app.FragmentActivity",
                    "java.util.concurrent.Executor",
                    "androidx.biometric.BiometricPrompt$AuthenticationCallback"
                ).implementation = function (activity, executor, callback) {
                    console.log("[BiometricPrompt] Constructor called");
                    console.log(" - Activity: " + activity);

                    return this.$init(activity, executor, callback);
                };

                console.log("[OK] Hooked BiometricPrompt constructor");
            } catch (e) {
                console.log("[-] Error hooking BiometricPrompt constructor: " + e);
            }

            // ==========
            // 2) Hook Authentication Start
            // ==========
            try {
                const BP = Java.use("androidx.biometric.BiometricPrompt");

                BP.authenticate.overload(
                    "androidx.biometric.BiometricPrompt$PromptInfo"
                ).implementation = function (info) {
                    console.log("[BiometricPrompt] authenticate(info) called");
                    logPromptInfo(info);

                    return this.authenticate(info);
                };

                BP.authenticate.overload(
                    "androidx.biometric.BiometricPrompt$PromptInfo",
                    "androidx.biometric.BiometricPrompt$CryptoObject"
                ).implementation = function (info, crypto) {
                    console.log("[BiometricPrompt] authenticate(info, crypto) called");
                    logPromptInfo(info);
                    logCryptoObject(crypto);

                    return this.authenticate(info, crypto);
                };

                console.log("[OK] Hooked authenticate() methods");
            } catch (e) {
                console.log("[-] Error hooking authenticate(): " + e);
            }

            // ==========
            // 3) Hook Authentication Callback Events
            // ==========
            try {
                const CB = Java.use("androidx.biometric.BiometricPrompt$AuthenticationCallback");

                CB.onAuthenticationError.implementation = function (code, msg) {
                    console.log("[Callback] onAuthenticationError → code=" + code + " msg=" + msg);

                    writeLog({
                        event: "error",
                        timestamp: Date.now(),
                        errorCode: code,
                        errorMsg: msg.toString(),
                        success: 0
                    });

                    return this.onAuthenticationError(code, msg);
                };

                CB.onAuthenticationFailed.implementation = function () {
                    console.log("[Callback] onAuthenticationFailed");

                    writeLog({
                        event: "failed",
                        timestamp: Date.now(),
                        success: 0
                    });

                    return this.onAuthenticationFailed();
                };

                CB.onAuthenticationSucceeded.implementation = function (resultObj) {
                    console.log("[Callback] onAuthenticationSucceeded");

                    let cryptoInfo = null;
                    try {
                        const crypto = resultObj.getCryptoObject();
                        if (crypto) {
                            cryptoInfo = {
                                hasSignature: crypto.getSignature() != null,
                                hasMac: crypto.getMac() != null,
                                hasCipher: crypto.getCipher() != null
                            };
                        }
                    } catch (e) {
                        console.log("   [!] Could not parse CryptoObject: " + e);
                    }

                    writeLog({
                        event: "success",
                        timestamp: Date.now(),
                        duration: 120,
                        pressure: 0.8,
                        cryptoObject: cryptoInfo,
                        success: 1
                    });

                    return this.onAuthenticationSucceeded(resultObj);
                };

                console.log("[OK] Hooked AuthenticationCallback");
            } catch (e) {
                console.log("[-] Error hooking AuthenticationCallback: " + e);
            }

            // ==========
            // 4) Helper Functions
            // ==========
            function logPromptInfo(info) {
                try {
                    const title = info.getTitle();
                    const subtitle = info.getSubtitle();
                    const desc = info.getDescription();
                    const neg = info.getNegativeButtonText();

                    console.log("   [PromptInfo]");
                    console.log("      Title: " + title);
                    console.log("      Subtitle: " + subtitle);
                    console.log("      Description: " + desc);
                    console.log("      Negative: " + neg);
                } catch (e) {
                    console.log("   [PromptInfo] Failed: " + e);
                }
            }

            function logCryptoObject(crypto) {
                if (!crypto) {
                    console.log("   [CryptoObject] null");
                    return;
                }
                try {
                    console.log("   [CryptoObject] Found");

                    const sign = crypto.getSignature();
                    const mac = crypto.getMac();
                    const cipher = crypto.getCipher();

                    if (sign) console.log("      Signature: " + sign);
                    if (mac) console.log("      Mac: " + mac);
                    if (cipher) console.log("      Cipher: " + cipher);

                } catch (e) {
                    console.log("   [CryptoObject] error: " + e);
                }
            }

            console.log("=== [BioShield] Biometric Hooks Active ===");
        });
    },

    dispose() {
        console.log("=== [BioShield] dispose() called - cleaning up ===");
    }
};

console.log("=== [BioShield] Script loaded and ready ===");
