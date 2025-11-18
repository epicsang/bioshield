# BioShield Automated Repackaging Scripts

## Overview

These scripts automate the complete APK repackaging workflow for BioShield vulnerability scanning. They handle extraction, decompilation, Frida Gadget injection, IPC bridge injection, rebuilding, signing, and installation.

## Available Scripts

### 🐍 Python (Cross-Platform) - **RECOMMENDED**: `repackage.py`
For all platforms (Windows, macOS, Linux). Requires Python 3.7+

### 💻 Windows PowerShell: `repackage-apk.ps1`
For Windows users (PowerShell 5.1+ or PowerShell Core)

### 🐧 Linux/Mac Bash: `repackage-apk.sh`
For Unix-based systems (bash)

---

## Prerequisites

### 1. Java JDK (Required)
**Windows:**
```cmd
# Download and install from:
https://www.oracle.com/java/technologies/downloads/

# Verify installation:
java -version
jarsigner
```

**Mac:**
```bash
brew install openjdk
# Add to PATH in ~/.zshrc or ~/.bash_profile
```

**Linux:**
```bash
sudo apt-get install openjdk-17-jdk
```

### 2. APKTool (Required)
**Windows:**
```cmd
# Download apktool.bat and apktool.jar from:
https://ibotpeaches.github.io/Apktool/

# Place both files in C:\Windows or add directory to PATH
# Verify:
apktool --version
```

**Mac:**
```bash
brew install apktool
```

**Linux:**
```bash
sudo apt-get install apktool
# Or download manually and add to PATH
```

### 3. Android SDK Platform Tools (Required)
**All platforms:**
```
Download from: https://developer.android.com/studio/releases/platform-tools
Extract and add to PATH
Verify: adb --version
```

### 4. zipalign (REQUIRED - Included!)
**✅ Already included in the `scripts` folder!**

zipalign.exe is required for Android 11+ (API 30+) compatibility. The tool is already included in the scripts folder, so no additional setup is needed.

If you need to get it manually:
```bash
# Windows: Copy from Android SDK build-tools
C:\Users\<User>\AppData\Local\Android\Sdk\build-tools\<version>\zipalign.exe

# Mac/Linux: Install Android SDK Build Tools
# Then copy zipalign to the scripts folder
```

### 5. Frida Gadget (Required)
```bash
# Download from:
https://github.com/frida/frida/releases

# Get the latest version:
# frida-gadget-17.x.x-android-arm64.so.xz

# Extract and place in:
BioShield/assets/libfrida-gadget.so
# OR
BioShield/assets/frida-gadget-android-arm64.so
```

### 6. Required BioShield Files
Ensure these files exist in `BioShield/assets/`:
- `libfrida-gadget.so` (or `frida-gadget-android-arm64.so`)
- `FridaBridge.java`
- `BioShieldApplication.java`
- `frida_init.js`

---

## Features

### ✨ Interactive App Selection (NEW!)
- **Select from list**: Choose from all installed apps on your device
- **Manual entry**: Enter package name manually if needed
- **Auto-detection**: Automatically finds package directory in smali
- **Multi-dex support**: Handles apps with multiple dex files

See [INTERACTIVE_SELECTION.md](INTERACTIVE_SELECTION.md) for details.

---

## Usage

### Python (Recommended - Works on all platforms)

```bash
cd scripts
python repackage.py

# Or specify package directly:
python repackage.py com.example.app
```

### Windows PowerShell

```powershell
cd scripts
.\repackage-apk.ps1
```

### Linux/Mac Bash

```bash
cd scripts
chmod +x repackage-apk.sh
./repackage-apk.sh
```

---

## What the Script Does

### Step 0: Prerequisites Check
- ✓ Verifies ADB is installed
- ✓ Verifies APKTool is installed
- ✓ Verifies jarsigner (Java) is installed
- ✓ Checks device is connected via USB
- ✓ Lists all installed user apps
- ✓ Prompts for app selection

### Step 1: Extract APK from Device
- Queries package manager for selected app's APK location
- Pulls APK from device to computer
- Saves to: `~/Desktop/BioShield_Repackaging/{package_name}.apk`

### Step 2: Decompile APK
- Uses APKTool to decompile APK
- Extracts all resources, manifest, and smali code
- Output: `~/Desktop/BioShield_Repackaging/decompiled/`

### Step 3: Inject Frida Gadget
- Creates `lib/arm64-v8a/` directory
- Copies `libfrida-gadget.so` into APK

### Step 4: Inject Frida Scripts
- Copies `frida_init.js` to `assets/`
- Creates `libfrida-gadget.config.so` (gadget configuration)

### Step 5: Inject IPC Bridge
- Automatically locates package directory in smali (supports multidex)
- Searches: smali/, smali_classes2/, smali_classes3/, smali_classes4/
- Injects `FridaBridge.java` (with package name replacement)
- Injects `BioShieldApplication.java` (with package name replacement)

### Step 6: Modify AndroidManifest.xml
- Backs up original manifest
- Changes `android:name=".Application"` to `android:name=".BioShieldApplication"`
- This ensures custom Application class loads on app start

### Step 7: Rebuild APK
- Uses APKTool to rebuild modified APK
- Output: `~/Desktop/BioShield_Repackaging/repackaged.apk`

### Step 8: Sign APK
- Signs APK with debug keystore (`~/.android/debug.keystore`)
- Generates debug keystore if it doesn't exist
- Verifies signature

### Step 9: Install on Device
- Uninstalls original app (to avoid signature conflicts)
- Installs repackaged APK via ADB

---

## Configuration

You can modify the package name in the script:

**Windows (`repackage-apk.bat`):**
```batch
set PACKAGE_NAME=com.your.target.app
```

**Linux/Mac (`repackage-apk.sh`):**
```bash
PACKAGE_NAME="com.your.target.app"
```

---

## Output Files

All files are saved to: `~/Desktop/BioShield_Repackaging/`

```
BioShield_Repackaging/
├── vulnerable_app.apk          # Original APK from device
├── repackaged.apk              # Final repackaged APK (signed)
└── decompiled/                 # Decompiled APK contents
    ├── AndroidManifest.xml     # Modified manifest
    ├── AndroidManifest.xml.backup  # Original backup
    ├── assets/
    │   ├── frida_init.js       # Frida hooks
    │   └── libfrida-gadget.config.so  # Gadget config
    ├── lib/arm64-v8a/
    │   └── libfrida-gadget.so  # Frida Gadget library
    └── smali/com/fyp/vulnerable/vulnerable_biometric_app/
        ├── FridaBridge.java    # IPC bridge
        └── BioShieldApplication.java  # Custom Application
```

---

## Testing the Repackaged App

### 1. Launch BioShield
```bash
adb shell am start -n com.fyp.bioshield.bioshield/.MainActivity
```

### 2. Monitor Logs
```bash
# Clear logs
adb logcat -c

# Watch for Frida/BioShield messages
adb logcat | grep -E "BioShield|Frida|FridaBridge"
```

### 3. Launch Repackaged App
Open the repackaged app on your device.

**Expected Logs:**
```
I Frida: Frida Gadget loaded successfully!
D FridaBridge: FridaBridge initialized
[BioShield] Frida init script loading...
[BioShield] FridaBridge loaded successfully!
[BioShield] BiometricPrompt hooks installed
[BioShield] Initialization complete!
```

### 4. Trigger Biometric Authentication
In the repackaged app, tap "Authenticate" and use your fingerprint.

**Expected Logs:**
```
[BioShield] BiometricPrompt.authenticate() called
[BioShield] Authentication SUCCEEDED (duration: 850ms)
[BioShield] Generating report with IPC bridge...
[BioShield] Sending 15234 bytes to BioShield...
D FridaBridge: Sent data to BioShield

D BioShield: Received vulnerability data broadcast!
D BioShield: Scan data received from com.fyp.vulnerable.vulnerable_biometric_app (15234 bytes)
D BioShield: Scan data forwarded to Flutter

[ScanReceiver] Processing scan data
[ScanReceiver] Parsed scan result successfully
[ScanReceiver] Scan saved to Firestore successfully!
```

### 5. Check BioShield Dashboard
Switch back to BioShield app and see the instant scan results!

---

## Troubleshooting

### Issue: "ADB not found"
**Solution:**
- Download Android SDK Platform Tools
- Add to PATH environment variable
- Restart terminal/command prompt

### Issue: "APKTool not found"
**Solution:**
- Install APKTool using package manager or download manually
- Add to PATH
- On Windows, ensure both `apktool.bat` and `apktool.jar` are in the same directory

### Issue: "jarsigner not found"
**Solution:**
- Install Java JDK (not just JRE)
- Add `JAVA_HOME/bin` to PATH
- Verify: `jarsigner` should display help

### Issue: "No device connected"
**Solution:**
- Enable USB debugging on Android device
- Connect via USB cable
- Accept USB debugging prompt on device
- Verify with: `adb devices`

### Issue: "Package not found on device"
**Solution:**
- Install the target app first
- Verify package name is correct
- Check with: `adb shell pm list packages | grep vulnerable`

### Issue: "Failed to decompile APK"
**Solution:**
- Update APKTool to latest version
- Some apps use advanced obfuscation
- Try: `apktool d app.apk -o output --only-main-classes`

### Issue: "Could not find package directory in smali"
**Solution:**
- Check if app uses multidex (multiple smali directories)
- Look in `smali_classes2/`, `smali_classes3/`, etc.
- Modify script to search all smali directories

### Issue: "Installation failed: INSTALL_FAILED_UPDATE_INCOMPATIBLE"
**Solution:**
- Uninstall original app first
- Script should do this automatically, but you can manually:
  ```bash
  adb uninstall com.fyp.vulnerable.vulnerable_biometric_app
  ```

### Issue: "App crashes on launch"
**Solution:**
- Check logcat for errors: `adb logcat | grep -E "FATAL|AndroidRuntime"`
- Verify Frida Gadget is correct architecture (arm64-v8a)
- Ensure Java files have correct package name

### Issue: "No data received in BioShield"
**Solution:**
- Ensure BioShield is running in background
- Check app actually uses BiometricPrompt API (not legacy FingerprintManager)
- Verify FridaBridge is initialized: `adb logcat | grep FridaBridge`
- Try authenticating multiple times

---

## Advanced Usage

### Repackage Different App

Edit the script and change:
```bash
PACKAGE_NAME="com.example.different.app"
```

Then run the script again.

### Keep Decompiled Files

By default, the script keeps all decompiled files in:
`~/Desktop/BioShield_Repackaging/decompiled/`

You can manually inspect or modify these files before rebuilding.

### Manual Rebuild

If you modify decompiled files manually:
```bash
# Rebuild
apktool b ~/Desktop/BioShield_Repackaging/decompiled -o custom.apk

# Sign
jarsigner -keystore ~/.android/debug.keystore -storepass android custom.apk androiddebugkey

# Install
adb install -r custom.apk
```

---

## Performance

**Typical execution time:**
- Small apps (< 50MB): 1-2 minutes
- Medium apps (50-100MB): 2-4 minutes
- Large apps (> 100MB): 4-8 minutes

**Bottlenecks:**
- APK decompilation (30-40% of time)
- APK rebuild (40-50% of time)
- APK signing (10-15% of time)

---

## Security Notes

⚠️ **Important:**
- Only repackage apps you own or have permission to test
- Never distribute repackaged apps
- Use on test devices only
- Debug-signed APKs are for testing only
- Keep repackaged APKs secure

---

## Related Documentation

- [MANUAL_REPACKAGING_STEPS.md](../MANUAL_REPACKAGING_STEPS.md) - Manual step-by-step guide
- [REPACKAGING_STATUS.md](../REPACKAGING_STATUS.md) - Technical explanation
- [FRIDA_GADGET_IPC_GUIDE.md](../FRIDA_GADGET_IPC_GUIDE.md) - IPC architecture
- [TESTING_CHECKLIST.md](../TESTING_CHECKLIST.md) - Complete testing guide

---

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review logcat output: `adb logcat`
3. Check APKTool logs in script output
4. Verify all prerequisites are installed

---

**Created:** 2025-01-13
**Version:** 1.0.0
**Status:** ✅ Ready for use

🎉 **Happy repackaging!**
