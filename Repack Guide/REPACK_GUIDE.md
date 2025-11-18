# BioShield Frida Gadget Repack Guide

## Overview

This guide walks you through repacking any Android APK with Frida Gadget to enable biometric monitoring. The process works on **non-rooted Android 12-14 devices** and uses Frida Gadget in script mode to automatically capture biometric authentication events.

## Prerequisites

### Required Tools

1. **Java JDK** (version 8 or higher)
   - Verify: `java -version`

2. **APKTool** (latest version recommended)
   - Download: https://apktool.org/
   - Place `apktool.jar` in your tools folder

3. **Android SDK Build Tools**
   - Includes: `zipalign`, `apksigner`
   - Location: `%LOCALAPPDATA%\Android\Sdk\build-tools\<version>\`

4. **ADB (Android Debug Bridge)**
   - Verify: `adb devices`

5. **Frida Gadget Library**
   - Version: 16.5.9 (x86_64 for emulator)
   - Download: https://github.com/frida/frida/releases
   - Extract `frida-gadget-16.5.9-android-x86_64.so`

### Required Files from BioShield

Copy these files from the BioShield REPACK folder:
- `frida_biometric_script.js` - The hook script
- `scripts/patch_manifest.py` - Manifest patcher
- `scripts/patch_mainactivity.py` - MainActivity patcher (optional automation)

---

## Step-by-Step Process

### Step 1: Extract Your APK

```bash
# Navigate to your tools directory
cd c:\path\to\your\tools

# Decompile the APK
java -jar apktool.jar d "PATH_TO_YOUR_APP.apk" -o temp_repack
```

**Placeholders:**
- `PATH_TO_YOUR_APP.apk` → Your target APK file path
- `temp_repack` → Output folder name (can be changed)

**Expected output:**
```
I: Using Apktool 2.x.x
I: Loading resource table...
I: Decoding AndroidManifest.xml with resources...
I: Regular manifest package...
I: Decoding file-resources...
I: Decoding values */* XMLs...
I: Baksmaling classes.dex...
I: Copying assets and libs...
I: Copying unknown files...
I: Copying original files...
```

---

### Step 2: Prepare Frida Gadget Files

Create the native library structure and place all 3 required files:

```bash
cd temp_repack
mkdir -p lib\x86_64
```

Now place these **3 files** in `temp_repack\lib\x86_64\`:

#### File 1: `libfrida-gadget.so`
- **Source**: Rename `frida-gadget-16.5.9-android-x86_64.so` to `libfrida-gadget.so`
- **Size**: ~28 MB
- **Purpose**: The Frida Gadget library itself

#### File 2: `libfrida-gadget.config.so`
- **Content**: Create this file with the following JSON:

```json
{
  "interaction": {
    "type": "script",
    "path": "libfrida-gadget.script.so",
    "on_load": "init"
  }
}
```

**Critical notes:**
- File MUST end with `.so` extension (Android only extracts `.so` files)
- The `"on_load": "init"` parameter is REQUIRED to auto-execute the script
- The `"path"` must match the script filename exactly

#### File 3: `libfrida-gadget.script.so`
- **Source**: Copy the entire contents of `frida_biometric_script.js`
- **Purpose**: Contains all BiometricPrompt hooks and encryption logic

**Verification:**
```bash
dir temp_repack\lib\x86_64
```

You should see exactly **3 files**, all ending in `.so`:
```
libfrida-gadget.so
libfrida-gadget.config.so
libfrida-gadget.script.so
```

---

### Step 3: Modify AndroidManifest.xml

#### Option A: Automatic (Recommended)

```bash
python scripts\patch_manifest.py temp_repack\AndroidManifest.xml
```

#### Option B: Manual

Open `temp_repack\AndroidManifest.xml` and find the `<application` tag. Add the `extractNativeLibs` attribute:

**Before:**
```xml
<application
    android:label="YOUR_APP_NAME"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher">
```

**After:**
```xml
<application
    android:label="YOUR_APP_NAME"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:extractNativeLibs="true">
```

**Why this matters:** Without `extractNativeLibs="true"`, Android won't extract the Frida Gadget library files to disk, and the app will crash when trying to load them.

---

### Step 4: Inject Frida Gadget Loader into MainActivity

#### Finding MainActivity

Your app's MainActivity is typically located at:
```
temp_repack\smali_classes<N>\<package_path>\MainActivity.smali
```

**Example paths:**
- `temp_repack\smali_classes9\com\fyp\limit\limit_test_app\MainActivity.smali`
- `temp_repack\smali\com\yourcompany\yourapp\MainActivity.smali`

**How to find it:**
1. Check your package name in `AndroidManifest.xml` (look for `package="com.example.app"`)
2. Convert dots to backslashes: `com.example.app` → `com\example\app`
3. Search in `smali*` folders for `<package_path>\MainActivity.smali`

#### Option A: Automatic Injection (Recommended)

```bash
python scripts\patch_mainactivity.py temp_repack\smali_classes9\PACKAGE_PATH\MainActivity.smali
```

**Placeholder:**
- `PACKAGE_PATH` → Your package path (e.g., `com\fyp\limit\limit_test_app`)

#### Option B: Manual Injection

Open `MainActivity.smali` and find the constructor method:

```smali
.method public constructor <init>()V
    .locals X
```

**Where X is any number (e.g., `.locals 2`).**

Immediately after the `invoke-direct` line (the super constructor call), insert this code:

```smali
    # Load Frida Gadget
    const-string v0, "FRIDA_LOADER"
    const-string v1, "Attempting to load frida-gadget"
    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    const-string v1, "frida-gadget"
    :try_start
    invoke-static {v1}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V
    const-string v1, "SUCCESS: Frida Gadget loaded"
    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch_block

    goto :end

    :catch_block
    move-exception v1
    invoke-virtual {v1}, Ljava/lang/Throwable;->printStackTrace()V
    invoke-virtual {v1}, Ljava/lang/Throwable;->toString()Ljava/lang/String;
    move-result-object v1
    invoke-static {v0, v1}, Landroid/util/Log;->e(Ljava/lang/String;Ljava/lang/String;)I

    :end
```

**IMPORTANT:** Ensure `.locals` is at least `.locals 2` to accommodate the two local variables (v0, v1) we're using.

**Complete example:**

```smali
.method public constructor <init>()V
    .locals 2

    .line 5
    invoke-direct {p0}, Lio/flutter/embedding/android/FlutterFragmentActivity;-><init>()V

    # Load Frida Gadget
    const-string v0, "FRIDA_LOADER"
    const-string v1, "Attempting to load frida-gadget"
    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    const-string v1, "frida-gadget"
    :try_start
    invoke-static {v1}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V
    const-string v1, "SUCCESS: Frida Gadget loaded"
    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch_block

    goto :end

    :catch_block
    move-exception v1
    invoke-virtual {v1}, Ljava/lang/Throwable;->printStackTrace()V
    invoke-virtual {v1}, Ljava/lang/Throwable;->toString()Ljava/lang/String;
    move-result-object v1
    invoke-static {v0, v1}, Landroid/util/Log;->e(Ljava/lang/String;Ljava/lang/String;)I

    :end

    return-void
.end method
```

---

### Step 5: Recompile the APK

```bash
java -jar apktool.jar b temp_repack -o YOUR_APP_repacked.apk
```

**Placeholders:**
- `temp_repack` → Your decompiled folder name
- `YOUR_APP_repacked.apk` → Output filename (e.g., `myapp_with_frida.apk`)

**Expected output:**
```
I: Using Apktool 2.x.x
I: Checking whether sources has changed...
I: Smaling smali folder into classes.dex...
I: Checking whether resources has changed...
I: Building resources...
I: Building apk file...
I: Copying unknown files/dir...
```

**Common error:** If you see build errors, check:
- Smali syntax in MainActivity (proper indentation, matching labels)
- AndroidManifest.xml is valid XML
- All required resource files are present

---

### Step 6: Sign the APK

Android requires all APKs to be signed before installation.

#### Using Debug Keystore (for testing)

```bash
# Set your path to apksigner
set APKSIGNER="C:\Users\USER_NAME\AppData\Local\Android\Sdk\build-tools\35.0.0\apksigner.bat"

# Sign the APK
%APKSIGNER% sign --ks "C:\Users\USER_NAME\.android\debug.keystore" --ks-pass pass:android --key-pass pass:android --min-sdk-version 21 --out YOUR_APP_final.apk YOUR_APP_repacked.apk
```

**Placeholders:**
- `USER_NAME` → Your Windows username
- `35.0.0` → Your build-tools version (check `%LOCALAPPDATA%\Android\Sdk\build-tools\`)
- `YOUR_APP_final.apk` → Final signed APK name
- `YOUR_APP_repacked.apk` → Input APK from Step 5

**Note:** The debug keystore password is always `android` for both keystore and key.

#### Verify the signature

```bash
%APKSIGNER% verify --verbose YOUR_APP_final.apk
```

Expected output:
```
Verifies
Verified using v1 scheme (JAR signing): true
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): true
```

---

### Step 7: Install and Test

#### Install the APK

```bash
# Uninstall old version first (if exists)
adb uninstall PACKAGE_NAME

# Install the repacked APK
adb install YOUR_APP_final.apk
```

**Placeholders:**
- `PACKAGE_NAME` → Your app's package name (e.g., `com.fyp.limit.limit_test_app`)
- `YOUR_APP_final.apk` → Your signed APK from Step 6

#### Monitor Frida Gadget Loading

In a separate terminal window, start logcat BEFORE launching the app:

```bash
adb logcat -c                    # Clear old logs
adb logcat | findstr "FRIDA"     # Filter for Frida messages
```

#### Launch the app

Tap the app icon on your device/emulator.

#### Expected logcat output

If everything is working correctly, you should see:

```
I FRIDA_LOADER: Attempting to load frida-gadget
I FRIDA_LOADER: SUCCESS: Frida Gadget loaded
I FRIDA_SCRIPT: === [BioShield] Frida Gadget Loaded ===
I FRIDA_SCRIPT: === [BioShield] init() called, stage: early ===
I FRIDA_SCRIPT: === [BioShield] Java.perform OK ===
I FRIDA_SCRIPT: [OK] Hooked BiometricPrompt constructor
I FRIDA_SCRIPT: [OK] Hooked authenticate() methods
I FRIDA_SCRIPT: [OK] Hooked AuthenticationCallback
I FRIDA_SCRIPT: === [BioShield] Biometric Hooks Active ===
I FRIDA_SCRIPT: === [BioShield] Script loaded and ready ===
```

#### Test Biometric Authentication

1. Trigger a biometric authentication prompt in the app
2. Use your fingerprint or face to authenticate
3. Watch logcat for hook events:

```
I FRIDA_SCRIPT: [BiometricPrompt] Constructor called
I FRIDA_SCRIPT: [BiometricPrompt] authenticate(info) called
I FRIDA_SCRIPT:    [PromptInfo]
I FRIDA_SCRIPT:       Title: Authenticate
I FRIDA_SCRIPT: [Callback] onAuthenticationSucceeded
I FRIDA_SCRIPT: [+] Encrypted log written: success
```

#### Check Log Files

Frida Gadget writes encrypted logs to:
```
/storage/emulated/0/Download/BioShield/logs.jsonl
```

Pull the logs to inspect:
```bash
adb pull /storage/emulated/0/Download/BioShield/logs.jsonl
```

Each line contains AES-256-GCM encrypted JSON with biometric event data.

---

## Troubleshooting

### App crashes immediately on launch

**Symptom:** App crashes with `UnsatisfiedLinkError: dlopen failed`

**Causes:**
1. Missing `android:extractNativeLibs="true"` in AndroidManifest.xml
2. Wrong CPU architecture (you used x86_64 but device is ARM)
3. Frida Gadget files not in correct location

**Fix:**
- Verify AndroidManifest.xml has `extractNativeLibs="true"`
- Match Frida Gadget architecture to your device:
  - Emulator: x86_64
  - Physical device: arm64-v8a (most modern phones)
- Verify files are in `lib/<arch>/` folder

### Frida Gadget loads but no hooks execute

**Symptom:** You see "SUCCESS: Frida Gadget loaded" but no script messages

**Causes:**
1. Missing `"on_load": "init"` in config
2. Script syntax errors preventing initialization
3. Wrong script path in config

**Fix:**
- Verify `libfrida-gadget.config.so` contains `"on_load": "init"`
- Check logcat for JavaScript errors
- Ensure script filename in config matches actual filename exactly

### Hooks installed but no events captured

**Symptom:** Hooks show as installed but no callback events logged

**Causes:**
1. App uses a different biometric API (not androidx.biometric)
2. Authentication timeout before you can test
3. Fingerprint not registered on device

**Fix:**
- Search smali files for "BiometricPrompt" to confirm which API is used
- Increase timeout in app code or test immediately
- Register a fingerprint in device settings

### Installation blocked by Play Protect

**Symptom:** "App blocked by Play Protect"

**Fix:**
- Tap "Install anyway" in the dialog
- Or disable Play Protect in Play Store settings (not recommended for production devices)

### Signature conflicts

**Symptom:** "INSTALL_FAILED_UPDATE_INCOMPATIBLE"

**Fix:**
- Uninstall the original app first: `adb uninstall PACKAGE_NAME`
- Different keystore was used; you must uninstall before reinstalling

---

## Architecture-Specific Notes

### For ARM64 Devices (Most Physical Phones)

Replace `x86_64` with `arm64-v8a` throughout:

1. Download: `frida-gadget-16.5.9-android-arm64.so`
2. Create folder: `temp_repack\lib\arm64-v8a\`
3. Place files in: `lib\arm64-v8a\libfrida-gadget.so` (etc.)

### For Multi-Architecture Support

Place Frida Gadget in multiple architecture folders:
```
lib\
  arm64-v8a\
    libfrida-gadget.so
    libfrida-gadget.config.so
    libfrida-gadget.script.so
  armeabi-v7a\
    libfrida-gadget.so
    libfrida-gadget.config.so
    libfrida-gadget.script.so
  x86_64\
    libfrida-gadget.so
    libfrida-gadget.config.so
    libfrida-gadget.script.so
```

**Note:** Download the appropriate Frida Gadget binary for each architecture.

---

## Security Considerations

### Encryption Key

The script uses a hardcoded AES-256 key:
```javascript
const AES_KEY_B64 = "W7Yy9Np3F2e8Dqz0pY6Qv0T92oLk12BxVZtq8lZhg7s=";
```

**For production use:**
- Generate a unique key per deployment
- Store the key securely in BioShield, not in the repacked app
- Consider using Android Keystore for key management

### Log Storage

Logs are written to public Downloads folder:
```
/storage/emulated/0/Download/BioShield/logs.jsonl
```

**Considerations:**
- Any app with storage permission can read these logs
- Logs are encrypted but visible to file managers
- Consider using app-private storage for sensitive deployments

### App Distribution

**Never distribute repacked apps without authorization:**
- Only repack apps you own or have permission to modify
- This is for security research and testing purposes only
- Respect app licensing and terms of service

---

## Customization

### Modifying the Hook Script

Edit `libfrida-gadget.script.so` to customize behavior:

**Change log path:**
```javascript
const LOG_PATH = "/storage/emulated/0/Download/YOUR_FOLDER/logs.jsonl";
```

**Add custom data to logs:**
```javascript
writeLog({
    event: "success",
    timestamp: Date.now(),
    customField: "your_data",
    success: 1
});
```

**Hook additional classes:**
```javascript
Java.perform(() => {
    const YourClass = Java.use("com.example.YourClass");
    YourClass.yourMethod.implementation = function() {
        console.log("Method called!");
        return this.yourMethod();
    };
});
```

### Using Listen Mode Instead of Script Mode

If you want to attach Frida CLI instead of auto-running the script:

**Change config to:**
```json
{
  "interaction": {
    "type": "listen",
    "address": "127.0.0.1",
    "port": 27042,
    "on_port_conflict": "fail"
  }
}
```

Then connect via:
```bash
frida -U -n YOUR_APP_NAME -l frida_biometric_script.js
```

---

## File Checklist

Before repacking, ensure you have:

- [ ] Original APK file
- [ ] apktool.jar
- [ ] Frida Gadget `.so` file (correct architecture)
- [ ] frida_biometric_script.js
- [ ] patch_manifest.py
- [ ] Access to Android SDK build-tools
- [ ] ADB installed and device connected

After repacking, verify:

- [ ] `temp_repack\lib\<arch>\` contains exactly 3 `.so` files
- [ ] AndroidManifest.xml has `extractNativeLibs="true"`
- [ ] MainActivity.smali has Frida loader code
- [ ] APK recompiled without errors
- [ ] APK signed successfully
- [ ] APK installs on device
- [ ] Logcat shows "SUCCESS: Frida Gadget loaded"
- [ ] Logcat shows all hooks installed
- [ ] Biometric events are captured

---

## Quick Reference Commands

```bash
# Full workflow
java -jar apktool.jar d YOUR_APP.apk -o temp_repack
# [Modify files as per guide]
java -jar apktool.jar b temp_repack -o YOUR_APP_repacked.apk
apksigner sign --ks debug.keystore --ks-pass pass:android --key-pass pass:android --out YOUR_APP_final.apk YOUR_APP_repacked.apk
adb install YOUR_APP_final.apk

# Monitoring
adb logcat -c && adb logcat | findstr "FRIDA"

# Pull logs
adb pull /storage/emulated/0/Download/BioShield/logs.jsonl
```

---

## Support

For issues or questions:
1. Check logcat for detailed error messages
2. Verify all file placements match this guide exactly
3. Ensure Frida Gadget architecture matches your device
4. Review the troubleshooting section above

---

**Last Updated:** 2025-11-16
**Frida Gadget Version:** 16.5.9
**Tested On:** Android 12-14 (API 31-34)
