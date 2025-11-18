# BioShield Pixel 6 Testing - Automation Guide

**Complete automation suite for Frida Gadget testing on non-root Pixel 6**

---

## 📋 Overview

This guide provides automated scripts for the entire Frida Gadget testing workflow on your Pixel 6:
1. APK repacking with embedded Frida Gadget
2. Installation and permission setup
3. Frida connection and monitoring
4. Log collection and analysis

---

## 🚀 Quick Start

### One-Command Complete Workflow:
```cmd
complete_workflow.bat
```

This launches the entire testing workflow automatically.

---

## 📦 Available Scripts

### 1. **repack_with_frida_gadget.bat**
**Purpose**: Repack APK with embedded Frida Gadget

**Usage**:
```cmd
repack_with_frida_gadget.bat app-debug.apk
```

**What it does**:
- Decompiles APK with apktool
- Injects `libfrida-gadget.so` (25MB)
- Adds Frida Gadget configuration
- Copies agent.js timing analysis script
- Rebuilds and signs APK
- Output: `app-debug_frida.apk`

**Requirements**:
- apktool.jar in `REPACK/tools/`
- libfrida-gadget.so in `REPACK/frida/`
- JDK (for jarsigner)
- Android debug keystore

---

### 2. **install_frida_apk.bat**
**Purpose**: Install repacked APK on Pixel 6

**Usage**:
```cmd
install_frida_apk.bat
```

**What it does**:
- Checks device connection
- Uninstalls old version
- Installs `app-debug_frida.apk`
- Grants storage permissions (READ/WRITE_EXTERNAL_STORAGE)
- Creates log directory: `/storage/emulated/0/BioShield/logs/`
- Launches app

**Output**:
```
[+] Installation successful!
[+] Permissions granted!
[+] Log directory ready!
[+] App launched!
```

---

### 3. **connect_frida_gadget.bat**
**Purpose**: Connect Frida to embedded Gadget

**Usage**:
```cmd
connect_frida_gadget.bat
```

**What it does**:
- Checks if app is installed and running
- Connects Frida to TCP port 27042
- Injects `REPACK/frida/agent.js`
- Displays hook output in real-time

**Expected Output**:
```
[+] BioShield Frida agent loading (Shared Storage Mode)...
[+] BiometricPrompt hooked successfully (both overloads)!
[+] FingerprintManager hooked successfully!
[+] BioShield shared storage hooks installed!
```

**When authentication happens**:
```
[+] BiometricPrompt.authenticate() called (no-crypto, Attempt #1)
[+] BiometricPrompt: Success
[+] Logged authentication attempt: /storage/emulated/0/BioShield/logs/timing_2025-01-16T12-30-45-123Z.jsonl
```

---

### 4. **check_logs.bat**
**Purpose**: View and analyze timing logs

**Usage**:
```cmd
check_logs.bat
```

**What it does**:
- Lists all log files on device
- Shows file count and sizes
- Offers to pull logs to `logs_from_device/`
- Displays latest log entry
- Shows success/failure statistics

**Sample Output**:
```
[*] Total log files: 15
[*] Latest Log Entry:
========================================
{"timestamp":1700000000000,"attempt":1,"success":true,"totalLatency":450,"failurePattern":null}
========================================

[*] Log Statistics:
[+] Successful authentications: 12
[+] Failed authentications: 3
```

---

### 5. **monitor_logs.bat**
**Purpose**: Real-time log monitoring

**Usage**:
```cmd
monitor_logs.bat
```

**What it does**:
- Continuously monitors `/storage/emulated/0/BioShield/logs/`
- Detects new log files every 2 seconds
- Displays new entries immediately
- Shows timestamp of detection

**Live Output Example**:
```
[*] Monitoring: /storage/emulated/0/BioShield/logs/
[*] Current log files: 10
[*] Waiting for new log entries...

[+] NEW LOG DETECTED! [2025-01-16 12:30:45.67]
========================================
[*] File: timing_2025-01-16T12-30-45-123Z.jsonl

{"timestamp":1700000000000,"attempt":5,"success":true,"totalLatency":432,"failurePattern":null}
========================================
```

---

### 6. **clear_logs.bat**
**Purpose**: Clear all timing logs from device

**Usage**:
```cmd
clear_logs.bat
```

**What it does**:
- Counts existing log files
- Asks for confirmation
- Deletes all `timing_*.jsonl` files
- Verifies deletion

**Safety Features**:
- Shows count before deletion
- Requires Y/N confirmation
- Only deletes files matching pattern `timing_*.jsonl`

---

### 7. **complete_workflow.bat**
**Purpose**: Full automated testing workflow

**Usage**:
```cmd
complete_workflow.bat
```

**What it does**:
1. Calls `install_frida_apk.bat` (installs APK)
2. Waits for user to interact with app
3. Opens Frida connection in new window
4. Opens log monitor in new window
5. Provides testing instructions

**Workflow Stages**:
```
STEP 1: Installing Frida-repacked APK ✓
STEP 2: Manual Testing Required (user interaction)
STEP 3: Connecting Frida ✓
STEP 4: Starting Log Monitor ✓
```

**Result**: 3 command windows running:
- Main workflow window (instructions)
- Frida connection window (hook output)
- Log monitor window (real-time logs)

---

## 📊 Log File Format

### File Naming:
```
timing_2025-01-16T12-30-45-123Z.jsonl
```
- ISO 8601 timestamp
- JSONL format (one JSON object per line)

### Log Entry Structure:
```json
{
  "timestamp": 1700000000000,
  "attempt": 1,
  "success": true,
  "totalLatency": 450,
  "failurePattern": null
}
```

**Fields**:
- `timestamp`: Unix milliseconds
- `attempt`: Authentication attempt number
- `success`: Boolean (true = authenticated, false = rejected)
- `totalLatency`: Time from auth start to result (milliseconds)
- `failurePattern`: `null`, `"SlowReject"`, or `"Error"`

---

## 🔧 Configuration Files

### Frida Gadget Config
**Location**: `temp_repack/assets/frida-gadget.config` (embedded in APK)

```json
{
  "interaction": {
    "type": "listen",
    "address": "0.0.0.0",
    "port": 27042
  },
  "runtime": "v8",
  "scripts": [
    {
      "path": "agent.js"
    }
  ]
}
```

**Key Settings**:
- **type**: `listen` (TCP listener mode for non-root)
- **port**: 27042 (default Frida Gadget port)
- **scripts**: Auto-loads `agent.js` from APK assets

### Agent Script
**Location**: `REPACK/frida/agent.js`

**Features**:
- Hooks BiometricPrompt (both overloads)
- Hooks FingerprintManager (legacy fallback)
- Logs to shared storage
- Auto-cleanup (keeps last 50 logs)
- Timing analysis (auth start → result)

**Configuration Variables**:
```javascript
var MAX_LOG_FILES = 50;  // Auto-cleanup threshold
var logDir = "/storage/emulated/0/BioShield/logs";  // Log path
```

---

## 📖 Complete Testing Workflow

### First-Time Setup (One-Time):

1. **Repack APK**:
   ```cmd
   repack_with_frida_gadget.bat build/app/outputs/flutter-apk/app-debug.apk
   ```
   Output: `app-debug_frida.apk`

2. **Connect Pixel 6**:
   - Enable USB debugging
   - Verify: `adb devices`

### Every Testing Session:

**Option A: Automated (Recommended)**
```cmd
complete_workflow.bat
```

**Option B: Manual Step-by-Step**
```cmd
# 1. Install
install_frida_apk.bat

# 2. Connect Frida
connect_frida_gadget.bat

# 3. Monitor logs (in separate window)
monitor_logs.bat

# 4. After testing, check results
check_logs.bat
```

---

## 🐛 Troubleshooting

### APK Won't Install
**Error**: `INSTALL_FAILED_UPDATE_INCOMPATIBLE`

**Solution**:
```cmd
adb uninstall com.fyp.limit.limit_test_app
```
Then re-run `install_frida_apk.bat`

---

### Frida Won't Connect
**Error**: `Failed to attach: unable to find process with name 'com.fyp.limit.limit_test_app'`

**Check**:
1. Is app running? `adb shell pidof com.fyp.limit.limit_test_app`
2. Is app installed? `adb shell pm list packages | grep limit`
3. Launch manually: `adb shell am start -n com.fyp.limit.limit_test_app/.MainActivity`

---

### Hooks Not Triggering
**Symptom**: Frida connects, but no output when authenticating

**Check logcat**:
```cmd
adb logcat | grep -i biometric
adb logcat | grep -i frida
```

**Verify Gadget loaded**:
```cmd
adb logcat | grep -i "System.loadLibrary"
```

**Common causes**:
- App using different authentication API
- Gadget not loaded (smali injection needed)
- App has Frida detection

---

### No Logs Written
**Symptom**: Authentication works, but no files in `/storage/emulated/0/BioShield/logs/`

**Check permissions**:
```cmd
adb shell dumpsys package com.fyp.limit.limit_test_app | grep -i "READ_EXTERNAL\|WRITE_EXTERNAL"
```

**Manually grant**:
```cmd
adb shell pm grant com.fyp.limit.limit_test_app android.permission.READ_EXTERNAL_STORAGE
adb shell pm grant com.fyp.limit.limit_test_app android.permission.WRITE_EXTERNAL_STORAGE
```

**Check directory exists**:
```cmd
adb shell ls -ld /storage/emulated/0/BioShield/logs/
```

**Create manually if needed**:
```cmd
adb shell mkdir -p /storage/emulated/0/BioShield/logs
```

---

### Gadget Not Loading
**Symptom**: App crashes on launch or Frida Gadget doesn't start

**Check logcat for crashes**:
```cmd
adb logcat *:E | grep -i frida
```

**Verify library in APK**:
```cmd
unzip -l app-debug_frida.apk | grep frida
```

**Expected**:
```
 25678864  lib/arm64-v8a/libfrida-gadget.so
    11809  assets/frida-agent.js
      182  assets/frida-gadget.config
```

**If missing**: Re-run `repack_with_frida_gadget.bat`

---

## 🔒 Security Notes

### ⚠️ Important Warnings:

1. **Testing Only**: Repacked APKs are for authorized testing only
2. **Non-Production**: Never use on production devices without authorization
3. **Educational Purpose**: Part of BioShield FYP research project
4. **Debug Keys**: APK signed with publicly-known debug keystore
5. **Detection**: Most security apps will detect Frida Gadget

### Best Practices:

- Keep original APK backup
- Test on dedicated device (Pixel 6)
- Document all findings
- Delete logs after analysis
- Use version control for agent.js modifications

---

## 📝 Workflow Summary

```
┌─────────────────────────────────────┐
│  1. Repack APK (one-time setup)    │
│     repack_with_frida_gadget.bat    │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│  2. Install on Pixel 6              │
│     install_frida_apk.bat           │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│  3. Connect Frida                   │
│     connect_frida_gadget.bat        │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│  4. Test Authentication             │
│     (Manual - use app on phone)     │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│  5. Monitor/Check Logs              │
│     monitor_logs.bat / check_logs.bat│
└─────────────────────────────────────┘
```

---

## 📁 File Structure

```
BioShield/
├── app-debug_frida.apk              # Repacked APK (output)
├── complete_workflow.bat            # Full automation
├── install_frida_apk.bat            # Install & setup
├── connect_frida_gadget.bat         # Frida connection
├── check_logs.bat                   # Log analysis
├── monitor_logs.bat                 # Real-time monitoring
├── clear_logs.bat                   # Log cleanup
├── repack_with_frida_gadget.bat     # APK repack script
├── PIXEL6_AUTOMATION_GUIDE.md       # This file
├── REPACK/
│   ├── frida/
│   │   ├── libfrida-gadget.so       # Gadget library (25MB)
│   │   ├── agent.js                 # Timing analysis script
│   │   ├── gadget-config.json       # Gadget configuration
│   │   └── README.md                # Frida package docs
│   └── tools/
│       └── apktool.jar              # APK decompile/rebuild
└── logs_from_device/                # Downloaded logs (local)
```

---

## 🎯 Expected Results

### Successful Setup:
1. ✅ APK installs without errors
2. ✅ App launches normally
3. ✅ Frida connects and shows hooks installed
4. ✅ Authentication triggers hook output
5. ✅ Logs written to device storage
6. ✅ Auto-cleanup keeps last 50 files

### Sample Success Output:

**Frida Connection Window**:
```
[+] BioShield Frida agent loading (Shared Storage Mode)...
[+] BiometricPrompt hooked successfully (both overloads)!
[+] FingerprintManager hooked successfully (with legacy fallback)!
[+] BioShield shared storage hooks installed!

[+] BiometricPrompt.authenticate() called (no-crypto, Attempt #1)
[+] BiometricPrompt: Success
[+] Logged authentication attempt: /storage/emulated/0/BioShield/logs/timing_2025-01-16T12-30-45-123Z.jsonl
```

**Log Monitor Window**:
```
[+] NEW LOG DETECTED! [2025-01-16 12:30:45.67]
========================================
{"timestamp":1700000000000,"attempt":1,"success":true,"totalLatency":450,"failurePattern":null}
========================================
```

---

## 📚 Additional Resources

- [FRIDA_GADGET_REPACK_GUIDE.md](FRIDA_GADGET_REPACK_GUIDE.md) - Detailed manual repack guide
- [REPACK/frida/README.md](REPACK/frida/README.md) - Frida package documentation
- [Frida Official Docs](https://frida.re/docs/home/)
- [Android Biometric API](https://developer.android.com/training/sign-in/biometric-auth)

---

**Version**: 1.0.0
**Last Updated**: 2025-01-16
**Author**: BioShield Team
**Device**: Pixel 6 (Non-Root, Android 13)
