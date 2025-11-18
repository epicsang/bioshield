# Frida Gadget Repack Guide
**BioShield - Embedding Frida into APK**

## 📋 Prerequisites

### Required Tools:
1. **apktool** - APK decompile/rebuild tool
   - Download: https://apktool.org/
   - Add to PATH or place in project folder

2. **JDK** (Java Development Kit)
   - For `jarsigner` and `keytool`
   - Download: https://www.oracle.com/java/technologies/downloads/

3. **Frida Gadget Library**
   - Download from: https://github.com/frida/frida/releases
   - Get: `frida-gadget-*-android-arm64.so` (for Pixel 6)
   - Rename to: `libfrida-gadget.so`
   - Place in: `REPACK/frida/`

### Verify Installation:
```cmd
apktool --version
jarsigner
keytool
```

---

## 🚀 Quick Start (Automated)

### Step 1: Download Frida Gadget
```cmd
REM Download frida-gadget-17.5.1-android-arm64.so from GitHub releases
REM Rename to libfrida-gadget.so
REM Place in REPACK/frida/
```

### Step 2: Run Repack Script
```cmd
repack_with_frida_gadget.bat app-release.apk
```

### Step 3: Install on Device
```cmd
adb uninstall com.fyp.limit.limit_test_app
adb install -r app-release_frida.apk
```

### Step 4: Connect Frida
```cmd
frida -U -n com.fyp.limit.limit_test_app -l REPACK/frida/agent.js
```

---

## 🔧 Manual Repack (Step-by-Step)

### 1. Decompile APK
```cmd
apktool d app-release.apk -o temp_repack
```

### 2. Copy Frida Gadget Library
```cmd
mkdir temp_repack\lib\arm64-v8a
copy REPACK\frida\libfrida-gadget.so temp_repack\lib\arm64-v8a\
```

### 3. Add Gadget Configuration
Create `temp_repack/assets/frida-gadget.config`:
```json
{
  "interaction": {
    "type": "listen",
    "address": "0.0.0.0",
    "port": 27042
  },
  "runtime": "v8"
}
```

### 4. Copy Agent Script (Optional)
```cmd
copy REPACK\frida\agent.js temp_repack\assets\frida-agent.js
```

To auto-load the script, update config:
```json
{
  "interaction": {
    "type": "script",
    "path": "frida-agent.js"
  },
  "runtime": "v8"
}
```

### 5. Modify App to Load Gadget
**Option A: Manual Smali Injection (Advanced)**

Find the MainActivity smali file:
```
temp_repack/smali/com/fyp/limit/limit_test_app/MainActivity.smali
```

Add this in the constructor or onCreate:
```smali
const-string v0, "frida-gadget"
invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V
```

**Option B: Use Frida Gadget Auto-Load (Easier)**

The gadget can auto-load if placed in the correct lib folder. No smali modification needed, but less reliable.

### 6. Rebuild APK
```cmd
apktool b temp_repack -o app-release_frida.apk
```

### 7. Sign APK
```cmd
jarsigner -keystore %USERPROFILE%\.android\debug.keystore ^
  -storepass android ^
  -keypass android ^
  app-release_frida.apk ^
  androiddebugkey
```

### 8. Verify Signature
```cmd
jarsigner -verify -verbose -certs app-release_frida.apk
```

### 9. Install APK
```cmd
adb uninstall com.fyp.limit.limit_test_app
adb install -r app-release_frida.apk
```

---

## 🎯 Usage After Repack

### Method 1: Auto-Load Agent (Script Mode)
If you configured gadget with `"type": "script"`:
```cmd
REM Just launch the app - agent.js runs automatically
adb shell am start -n com.fyp.limit.limit_test_app/.MainActivity
```

### Method 2: Remote Injection (Listen Mode)
If you configured gadget with `"type": "listen"`:
```cmd
REM Launch app
adb shell am start -n com.fyp.limit.limit_test_app/.MainActivity

REM Connect Frida and inject agent.js
frida -U -n com.fyp.limit.limit_test_app -l REPACK/frida/agent.js --no-pause
```

### Method 3: TCP Port Forward (For Remote Debugging)
```cmd
adb forward tcp:27042 tcp:27042
frida -H localhost:27042 -l REPACK/frida/agent.js
```

---

## 🐛 Troubleshooting

### APK Won't Install
**Error:** `INSTALL_FAILED_UPDATE_INCOMPATIBLE`
```cmd
REM Uninstall original app first
adb uninstall com.fyp.limit.limit_test_app
```

### Gadget Library Not Loading
**Check logcat:**
```cmd
adb logcat | grep -i frida
adb logcat | grep -i "System.loadLibrary"
```

**Common causes:**
- Wrong architecture (need arm64-v8a for Pixel 6)
- Library not in correct folder
- Smali injection in wrong method

### Port Already in Use
**Error:** `Address already in use`
```cmd
REM Change port in frida-gadget.config
"port": 27043
```

### App Crashes on Launch
**Check logcat:**
```cmd
adb logcat *:E | grep -i frida
```

**Common fixes:**
- Ensure gadget version matches frida-tools version
- Check smali syntax if manually injected
- Verify gadget-config.json is valid JSON

### Agent Script Not Loading
**Check:**
1. File exists: `assets/frida-agent.js`
2. Config points to correct path
3. No syntax errors in agent.js

```cmd
REM Test agent.js syntax
node -c REPACK/frida/agent.js
```

---

## 📊 Verification Checklist

After repacking, verify:

- [ ] APK file size increased (Gadget is ~40MB)
- [ ] `lib/arm64-v8a/libfrida-gadget.so` exists in APK
- [ ] `assets/frida-gadget.config` exists in APK
- [ ] `assets/frida-agent.js` exists (if using script mode)
- [ ] APK installs without errors
- [ ] App launches without crashes
- [ ] Frida connects successfully
- [ ] Agent hooks trigger on biometric auth

**Check APK contents:**
```cmd
unzip -l app-release_frida.apk | grep frida
```

---

## 🔒 Security Considerations

### ⚠️ IMPORTANT WARNINGS:

1. **Repacked APKs are for testing only**
   - Do not distribute repacked APKs
   - Use only on authorized test devices
   - Only for educational/research purposes

2. **Debug Keys are Insecure**
   - Default Android debug keystore is publicly known
   - Never use for production apps
   - Anyone can re-sign with the same key

3. **Frida Detection**
   - Many apps detect Frida Gadget
   - Repacked APKs will fail SafetyNet/Play Integrity
   - Use only on test apps you own

### Best Practices:

- Keep original APK backup
- Test on emulator first
- Document all modifications
- Use version control for scripts

---

## 📖 Additional Resources

- [Frida Documentation](https://frida.re/docs/home/)
- [APKTool Documentation](https://apktool.org/docs/the-basics/)
- [Android Code Signing Guide](https://developer.android.com/studio/publish/app-signing)
- [Frida Gadget Configuration](https://frida.re/docs/gadget/)

---

## 🔄 Comparison: Server vs Gadget

| Feature | Frida Server | Frida Gadget |
|---------|-------------|--------------|
| **Requires Root** | Yes | No |
| **APK Modification** | No | Yes |
| **Auto-Load** | No | Optional |
| **Detection Risk** | Lower | Higher |
| **Setup Complexity** | Easy | Complex |
| **Best For** | Dev/Testing | Non-Root Testing |

---

**Version**: 1.0.0
**Last Updated**: 2025-01-16
**Author**: BioShield Team
