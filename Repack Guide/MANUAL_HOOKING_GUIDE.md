# Manual Frida Gadget Hooking Guide

This guide teaches you how to manually hook Android biometric authentication using Frida Gadget without automation scripts. Perfect for understanding the internals or customizing the process.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Understanding the Architecture](#understanding-the-architecture)
3. [Step-by-Step Manual Process](#step-by-step-manual-process)
4. [Writing Custom Hooks](#writing-custom-hooks)
5. [Advanced Hooking Techniques](#advanced-hooking-techniques)
6. [Debugging Your Hooks](#debugging-your-hooks)
7. [Common Patterns](#common-patterns)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, you should have:

- ✅ Basic understanding of JavaScript
- ✅ Familiarity with Android architecture (Activities, APIs)
- ✅ Knowledge of smali bytecode (helpful but not required)
- ✅ APKTool installed and working
- ✅ Android device/emulator with root access
- ✅ ADB (Android Debug Bridge) set up
- ✅ Text editor for editing smali files

**Tools Needed:**
- [Frida Gadget](https://github.com/frida/frida/releases) (appropriate architecture)
- [APKTool](https://apktool.org/)
- Android SDK Build Tools (apksigner, zipalign)
- Text editor (VS Code, Sublime Text, etc.)

---

## Understanding the Architecture

### How Frida Gadget Works

```
┌─────────────────────────────────────────────┐
│          Android Application                │
├─────────────────────────────────────────────┤
│  MainActivity.smali                         │
│  ┌──────────────────────────────┐          │
│  │  System.loadLibrary("frida-gadget") │  │
│  └────────────┬─────────────────┘          │
│               ↓                             │
│  ┌─────────────────────────────────┐       │
│  │  libfrida-gadget.so              │       │
│  │  (Frida Runtime)                 │       │
│  └────────────┬─────────────────────┘       │
│               ↓                             │
│  ┌─────────────────────────────────┐       │
│  │  libfrida-gadget.config.so       │       │
│  │  (Configuration)                 │       │
│  └────────────┬─────────────────────┘       │
│               ↓                             │
│  ┌─────────────────────────────────┐       │
│  │  libfrida-gadget.script.so       │       │
│  │  (Your JavaScript Hooks)         │       │
│  └──────────────────────────────────┘       │
└─────────────────────────────────────────────┘
```

### The Three Files

1. **libfrida-gadget.so**: The Frida runtime engine
2. **libfrida-gadget.config.so**: JSON configuration (tells Gadget what to do)
3. **libfrida-gadget.script.so**: Your JavaScript hook code

---

## Step-by-Step Manual Process

### Step 1: Decompile the APK

```bash
# Navigate to your working directory
cd /path/to/your/workspace

# Decompile the target APK
apktool d app.apk -o app_decompiled
```

**What this does:**
- Extracts the APK contents
- Converts DEX bytecode to smali
- Creates an editable project structure

---

### Step 2: Locate MainActivity

```bash
# Find MainActivity.smali
cd app_decompiled
find . -name "MainActivity.smali"
```

**Common locations:**
- `smali/com/company/app/MainActivity.smali`
- `smali_classes2/com/company/app/MainActivity.smali`
- `smali_classes3/com/company/app/MainActivity.smali`

**Pro tip:** If you can't find it, check `AndroidManifest.xml`:

```xml
<activity android:name=".MainActivity">
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
</activity>
```

---

### Step 3: Inject Gadget Loader (Manual Method)

Open `MainActivity.smali` in your text editor and find the `onCreate` method:

```smali
.method protected onCreate(Landroid/os/Bundle;)V
    .locals 1
    .param p1, "savedInstanceState"    # Landroid/os/Bundle;

    .line 15
    invoke-super {p0, p1}, Landroidx/appcompat/app/AppCompatActivity;->onCreate(Landroid/os/Bundle;)V

    # YOUR CODE GOES HERE

    .line 16
    const v0, 0x7f0b001c
    invoke-virtual {p0, v0}, Lcom/example/app/MainActivity;->setContentView(I)V

    return-void
.end method
```

**Add the Gadget loader AFTER `invoke-super` but BEFORE any other code:**

```smali
.method protected onCreate(Landroid/os/Bundle;)V
    .locals 1
    .param p1, "savedInstanceState"    # Landroid/os/Bundle;

    .line 15
    invoke-super {p0, p1}, Landroidx/appcompat/app/AppCompatActivity;->onCreate(Landroid/os/Bundle;)V

    # ===== FRIDA GADGET LOADER START =====
    const-string v0, "frida-gadget"
    invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V
    # ===== FRIDA GADGET LOADER END =====

    .line 16
    const v0, 0x7f0b001c
    invoke-virtual {p0, v0}, Lcom/example/app/MainActivity;->setContentView(I)V

    return-void
.end method
```

**What this does:**
- `const-string v0, "frida-gadget"` → Loads string "frida-gadget" into register v0
- `invoke-static {v0}, Ljava/lang/System;->loadLibrary(...)` → Calls `System.loadLibrary("frida-gadget")`

**⚠️ Critical:** Must be placed in `onCreate()` and executed early!

---

### Step 4: Modify AndroidManifest.xml

Find the `<application>` tag in `AndroidManifest.xml`:

```xml
<application
    android:name=".MyApplication"
    android:allowBackup="true"
    android:icon="@mipmap/ic_launcher"
    android:label="@string/app_name"
    android:theme="@style/AppTheme">
```

**Add `android:extractNativeLibs="true"`:**

```xml
<application
    android:name=".MyApplication"
    android:allowBackup="true"
    android:icon="@mipmap/ic_launcher"
    android:label="@string/app_name"
    android:theme="@style/AppTheme"
    android:extractNativeLibs="true">
```

**Why?** Android 9+ doesn't extract `.so` files by default. This forces extraction so Gadget can load.

---

### Step 5: Prepare Frida Gadget Files

#### 5a. Download Frida Gadget

```bash
# For Android emulator (x86_64)
wget https://github.com/frida/frida/releases/download/16.5.9/frida-gadget-16.5.9-android-x86_64.so.xz
xz -d frida-gadget-16.5.9-android-x86_64.so.xz
mv frida-gadget-16.5.9-android-x86_64.so libfrida-gadget.so

# For physical device (arm64)
wget https://github.com/frida/frida/releases/download/16.5.9/frida-gadget-16.5.9-android-arm64.so.xz
xz -d frida-gadget-16.5.9-android-arm64.so.xz
mv frida-gadget-16.5.9-android-arm64.so libfrida-gadget.so
```

#### 5b. Create Configuration File

Create `libfrida-gadget.config.so` (yes, with `.so` extension):

```json
{
  "interaction": {
    "type": "script",
    "path": "libfrida-gadget.script.so",
    "on_load": "init"
  }
}
```

**Configuration Breakdown:**
- `"type": "script"` → Load a script file
- `"path": "libfrida-gadget.script.so"` → Script filename
- `"on_load": "init"` → Call `init()` function when loaded

---

### Step 6: Write Your Hook Script

Create `libfrida-gadget.script.so` (yes, with `.so` extension):

```javascript
// ===== BioShield Biometric Hook =====
// Hooks androidx.biometric.BiometricPrompt

function init() {
    console.log("=== [BioShield] init() called ===");

    // Wait for Java to be ready
    Java.perform(function() {
        console.log("[BioShield] Java.perform() started");

        try {
            // Get BiometricPrompt class
            var BiometricPrompt = Java.use('androidx.biometric.BiometricPrompt');
            console.log("[OK] Found BiometricPrompt class");

            // Hook authenticate() method
            BiometricPrompt.authenticate.overload(
                'androidx.biometric.BiometricPrompt$PromptInfo'
            ).implementation = function(promptInfo) {
                console.log("[HOOK] BiometricPrompt.authenticate() called");
                console.log("  PromptInfo: " + promptInfo);

                // Get timestamp
                var timestamp = new Date().toISOString();
                console.log("  Timestamp: " + timestamp);

                // Call original method
                var result = this.authenticate(promptInfo);

                return result;
            };

            console.log("[OK] Hooked BiometricPrompt.authenticate()");

            // Hook AuthenticationCallback
            var Callback = Java.use('androidx.biometric.BiometricPrompt$AuthenticationCallback');

            // Hook onAuthenticationSucceeded
            Callback.onAuthenticationSucceeded.implementation = function(result) {
                console.log("[EVENT] ✓ Authentication SUCCEEDED");
                console.log("  Result: " + result);

                // Log to file
                logEvent({
                    event: 'SUCCESS',
                    timestamp: new Date().toISOString(),
                    result: String(result)
                });

                // Call original
                this.onAuthenticationSucceeded(result);
            };

            // Hook onAuthenticationFailed
            Callback.onAuthenticationFailed.implementation = function() {
                console.log("[EVENT] ✗ Authentication FAILED");

                logEvent({
                    event: 'FAILED',
                    timestamp: new Date().toISOString()
                });

                this.onAuthenticationFailed();
            };

            // Hook onAuthenticationError
            Callback.onAuthenticationError.implementation = function(errorCode, errString) {
                console.log("[EVENT] ⚠ Authentication ERROR");
                console.log("  Code: " + errorCode);
                console.log("  Message: " + errString);

                logEvent({
                    event: 'ERROR',
                    timestamp: new Date().toISOString(),
                    errorCode: errorCode,
                    errorMessage: String(errString)
                });

                this.onAuthenticationError(errorCode, errString);
            };

            console.log("=== [BioShield] Hooks Active ===");

        } catch (error) {
            console.error("[ERROR] Hook failed: " + error);
        }
    });
}

// Helper function to log events to file
function logEvent(data) {
    var File = Java.use('java.io.File');
    var FileWriter = Java.use('java.io.FileWriter');

    try {
        // Create directory
        var dir = File.$new('/storage/emulated/0/Download/BioShield');
        if (!dir.exists()) {
            dir.mkdirs();
        }

        // Create log file
        var logFile = File.$new(dir, 'logs.jsonl');
        var writer = FileWriter.$new(logFile, true); // append mode

        // Write JSON line
        writer.write(JSON.stringify(data) + '\n');
        writer.close();

        console.log("[LOG] Written to: " + logFile.getAbsolutePath());
    } catch (e) {
        console.error("[ERROR] Log write failed: " + e);
    }
}

// Export init function
rpc.exports = {
    init: init
};
```

**Key Concepts:**

1. **`Java.perform()`** → Ensures Java VM is ready
2. **`Java.use()`** → Gets a Java class reference
3. **`.implementation`** → Replaces method implementation
4. **`this.originalMethod()`** → Calls the original method

---

### Step 7: Place Files in Correct Location

```bash
cd app_decompiled

# Determine architecture (check existing libs)
ls lib/

# For x86_64 emulator
mkdir -p lib/x86_64
cp /path/to/libfrida-gadget.so lib/x86_64/
cp /path/to/libfrida-gadget.config.so lib/x86_64/
cp /path/to/libfrida-gadget.script.so lib/x86_64/

# For arm64 device
mkdir -p lib/arm64-v8a
cp /path/to/libfrida-gadget.so lib/arm64-v8a/
cp /path/to/libfrida-gadget.config.so lib/arm64-v8a/
cp /path/to/libfrida-gadget.script.so lib/arm64-v8a/
```

**⚠️ Critical:** All three files MUST end with `.so` extension!

---

### Step 8: Rebuild and Sign APK

```bash
# Rebuild APK
apktool b app_decompiled -o app_repacked.apk

# Align APK (required for Android)
zipalign -f -v 4 app_repacked.apk app_aligned.apk

# Sign APK with debug keystore
apksigner sign --ks ~/.android/debug.keystore \
    --ks-pass pass:android \
    --key-pass pass:android \
    --min-sdk-version 21 \
    --out app_final.apk \
    app_aligned.apk

# Verify signature
apksigner verify app_final.apk
```

---

### Step 9: Install and Test

```bash
# Uninstall old version
adb uninstall com.example.app

# Install new version
adb install app_final.apk

# Monitor logs
adb logcat | grep -E "FRIDA|BioShield"
```

**Expected Output:**

```
I FRIDA: Frida Gadget loaded
I BioShield: === [BioShield] init() called ===
I BioShield: [BioShield] Java.perform() started
I BioShield: [OK] Found BiometricPrompt class
I BioShield: [OK] Hooked BiometricPrompt.authenticate()
I BioShield: === [BioShield] Hooks Active ===
```

**When you trigger biometric authentication:**

```
I BioShield: [HOOK] BiometricPrompt.authenticate() called
I BioShield: [EVENT] ✓ Authentication SUCCEEDED
I BioShield: [LOG] Written to: /storage/emulated/0/Download/BioShield/logs.jsonl
```

---

## Writing Custom Hooks

### Basic Hook Template

```javascript
Java.perform(function() {
    var ClassName = Java.use('com.example.ClassName');

    ClassName.methodName.implementation = function(arg1, arg2) {
        console.log("methodName called with: " + arg1 + ", " + arg2);

        // Call original
        var result = this.methodName(arg1, arg2);

        console.log("methodName returned: " + result);
        return result;
    };
});
```

### Overloading Methods

If a method has multiple signatures, specify the overload:

```javascript
// Method with no arguments
ClassName.methodName.overload().implementation = function() {
    console.log("No-arg version called");
    return this.methodName();
};

// Method with String argument
ClassName.methodName.overload('java.lang.String').implementation = function(str) {
    console.log("String version called: " + str);
    return this.methodName(str);
};

// Method with multiple arguments
ClassName.methodName.overload('int', 'java.lang.String').implementation = function(num, str) {
    console.log("Multi-arg version called");
    return this.methodName(num, str);
};
```

### Modifying Return Values

```javascript
ClassName.isAuthenticated.implementation = function() {
    console.log("isAuthenticated called");

    // Call original
    var originalResult = this.isAuthenticated();
    console.log("Original result: " + originalResult);

    // Force return true (bypass authentication)
    return true;
};
```

**⚠️ Warning:** Bypassing security is for testing only!

---

## Advanced Hooking Techniques

### 1. Hooking Constructors

```javascript
var BiometricPrompt = Java.use('androidx.biometric.BiometricPrompt');

BiometricPrompt.$init.overload(
    'androidx.fragment.app.FragmentActivity',
    'androidx.biometric.BiometricPrompt$AuthenticationCallback'
).implementation = function(activity, callback) {
    console.log("[CONSTRUCTOR] BiometricPrompt created");
    console.log("  Activity: " + activity);
    console.log("  Callback: " + callback);

    // Call original constructor
    this.$init(activity, callback);
};
```

### 2. Tracing All Methods

```javascript
function traceClass(className) {
    var targetClass = Java.use(className);
    var methods = targetClass.class.getDeclaredMethods();

    methods.forEach(function(method) {
        var methodName = method.getName();
        console.log("[TRACE] Found method: " + methodName);

        // Hook each method
        try {
            targetClass[methodName].implementation = function() {
                console.log("[CALL] " + className + "." + methodName);
                return this[methodName].apply(this, arguments);
            };
        } catch (e) {
            // Some methods can't be hooked (overloaded, etc.)
        }
    });
}

// Use it
traceClass('androidx.biometric.BiometricPrompt');
```

### 3. Reading/Writing Fields

```javascript
var instance = Java.cast(someObject, Java.use('com.example.ClassName'));

// Read field
var value = instance.fieldName.value;
console.log("Field value: " + value);

// Write field
instance.fieldName.value = "new value";
```

### 4. Calling Private Methods

```javascript
var ClassName = Java.use('com.example.ClassName');

// Get the method using reflection
var privateMethod = ClassName.class.getDeclaredMethod(
    'privateMethodName',
    [Java.use('java.lang.String').class]
);
privateMethod.setAccessible(true);

// Call it
privateMethod.invoke(instance, Java.use('java.lang.String').$new("argument"));
```

---

## Debugging Your Hooks

### 1. Check if Gadget Loaded

```bash
adb logcat | grep -i "frida"
```

**Expected:**
```
I FRIDA: Frida Gadget loaded successfully
```

**If missing:** Gadget didn't load. Check:
- Did you inject `System.loadLibrary("frida-gadget")` in MainActivity?
- Is `libfrida-gadget.so` in the correct `lib/` folder?
- Did you set `android:extractNativeLibs="true"`?

### 2. Check if Script Loaded

```bash
adb logcat | grep -i "bioshield\|init"
```

**Expected:**
```
I BioShield: === [BioShield] init() called ===
```

**If missing:** Script didn't load. Check:
- Does `libfrida-gadget.config.so` exist?
- Does it have `"on_load": "init"`?
- Is `libfrida-gadget.script.so` in the same folder?

### 3. Check Hook Execution

```bash
adb logcat | grep -E "HOOK|EVENT"
```

**Expected** (when you trigger biometric):
```
I BioShield: [HOOK] BiometricPrompt.authenticate() called
I BioShield: [EVENT] ✓ Authentication SUCCEEDED
```

**If missing:** Hooks didn't trigger. Check:
- Is the app using `androidx.biometric.BiometricPrompt`?
- Did Java.perform() complete successfully?
- Are there JavaScript errors in logcat?

### 4. Verbose Logging

Add this to your script for detailed debugging:

```javascript
console.log("=== DETAILED DEBUG INFO ===");
console.log("Process: " + Process.id);
console.log("Thread: " + Process.getCurrentThreadId());
console.log("Java runtime: " + Java.available);

Java.perform(function() {
    console.log("Java.vm: " + Java.vm);
    console.log("Available classes: " + Java.enumerateLoadedClassesSync().slice(0, 10));
});
```

---

## Common Patterns

### Pattern 1: Timing Attack Detection

```javascript
var startTime = 0;

BiometricPrompt.authenticate.implementation = function(promptInfo) {
    startTime = Date.now();
    console.log("[START] Auth started at: " + startTime);

    return this.authenticate(promptInfo);
};

Callback.onAuthenticationSucceeded.implementation = function(result) {
    var endTime = Date.now();
    var duration = endTime - startTime;

    console.log("[TIMING] Auth took: " + duration + "ms");

    if (duration < 100) {
        console.log("[ALERT] Suspiciously fast authentication!");
    }

    this.onAuthenticationSucceeded(result);
};
```

### Pattern 2: Replay Attack Detection

```javascript
var usedNonces = new Set();

BiometricPrompt.authenticate.implementation = function(promptInfo) {
    var nonce = Java.use('java.util.UUID').randomUUID().toString();

    if (usedNonces.has(nonce)) {
        console.log("[ALERT] Replay attack detected!");
    }

    usedNonces.add(nonce);
    console.log("[NONCE] Using: " + nonce);

    return this.authenticate(promptInfo);
};
```

### Pattern 3: Encrypted Logging

```javascript
function encryptLog(data) {
    var Cipher = Java.use('javax.crypto.Cipher');
    var SecretKeySpec = Java.use('javax.crypto.spec.SecretKeySpec');
    var IvParameterSpec = Java.use('javax.crypto.spec.IvParameterSpec');

    var key = "0123456789abcdef0123456789abcdef"; // 32 bytes
    var iv = "0123456789abcdef"; // 16 bytes

    var secretKey = SecretKeySpec.$new(
        Java.array('byte', key.split('').map(c => c.charCodeAt(0))),
        "AES"
    );

    var ivSpec = IvParameterSpec.$new(
        Java.array('byte', iv.split('').map(c => c.charCodeAt(0)))
    );

    var cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
    cipher.init(Cipher.ENCRYPT_MODE.value, secretKey, ivSpec);

    var encrypted = cipher.doFinal(
        Java.array('byte', JSON.stringify(data).split('').map(c => c.charCodeAt(0)))
    );

    return encrypted;
}
```

---

## Troubleshooting

### Problem: App crashes on startup

**Symptoms:**
```
E AndroidRuntime: FATAL EXCEPTION: main
E AndroidRuntime: java.lang.UnsatisfiedLinkError: dlopen failed
```

**Solutions:**
1. Check `android:extractNativeLibs="true"` in manifest
2. Verify `.so` files are in correct architecture folder
3. Ensure all 3 files end with `.so` extension

---

### Problem: Gadget loads but script doesn't run

**Symptoms:**
```
I FRIDA: Frida Gadget loaded
(but no [BioShield] logs)
```

**Solutions:**
1. Check `libfrida-gadget.config.so` has correct JSON
2. Verify `"on_load": "init"` is present
3. Check script has `function init() {...}`
4. Look for JavaScript errors in logcat

---

### Problem: Hooks don't trigger

**Symptoms:**
```
I BioShield: === [BioShield] Hooks Active ===
(but no [HOOK] or [EVENT] logs when using biometric)
```

**Solutions:**
1. App might use different biometric API (check for `FingerprintManager`, `BiometricManager`)
2. Check class name is correct: `androidx.biometric.BiometricPrompt`
3. Device might not have fingerprint enrolled
4. Add logging to verify Java.perform() completed

---

### Problem: "Class not found" error

**Symptoms:**
```
E BioShield: [ERROR] Hook failed: Error: java.lang.ClassNotFoundException
```

**Solutions:**
1. Class might not be loaded yet - try `Java.choose()` or `Java.enumerateLoadedClasses()`
2. Check spelling/package name
3. Class might be obfuscated - use APK analysis tool to find real name
4. Add delay: `setTimeout(function() { /* hook here */ }, 2000);`

---

## Next Steps

Now that you understand manual hooking:

1. **Customize the script** for your specific needs
2. **Add encryption** to protect logged data
3. **Implement side-channel detection** (timing, replay attacks)
4. **Create reusable hook modules** for different APIs
5. **Learn smali editing** for deeper modifications

For a complete automated solution, see [REPACK_GUIDE.md](REPACK_GUIDE.md).

---

**Questions?** Check the [main README](README.md) or refer to the [Frida documentation](https://frida.re/docs/).

**Version:** 1.0
**Last Updated:** 2025-01-20
**Author:** BioShield Team
