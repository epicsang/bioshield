# BioShield Pixel 6 - Quick Start Guide

**Fast setup for Frida Gadget testing on non-root Pixel 6**

---

## ⚡ 30-Second Quickstart

```cmd
# 1. One-time: Repack APK (already done!)
# Output: app-debug_frida.apk (120MB)

# 2. Run complete workflow
complete_workflow.bat
```

**Done!** The script will:
- Install APK
- Grant permissions
- Launch app
- Connect Frida
- Monitor logs

---

## 📋 Manual Mode (Step-by-Step)

### First Time Setup:
```cmd
# 1. Install repacked APK
install_frida_apk.bat

# 2. Connect Frida
connect_frida_gadget.bat

# 3. Monitor logs (in new window)
monitor_logs.bat
```

### After Testing:
```cmd
# View results
check_logs.bat

# Clear logs
clear_logs.bat
```

---

## 🎯 What to Expect

### When you run `install_frida_apk.bat`:
```
[+] Device connected!
[+] Installation successful!
[+] Permissions granted!
[+] Log directory ready!
[+] App launched!
```

### When you run `connect_frida_gadget.bat`:
```
[+] BioShield Frida agent loading...
[+] BiometricPrompt hooked successfully!
[+] FingerprintManager hooked successfully!
```

### When you authenticate in the app:
```
[+] BiometricPrompt.authenticate() called (Attempt #1)
[+] BiometricPrompt: Success
[+] Logged to: timing_2025-01-16T12-30-45-123Z.jsonl
```

### When you run `check_logs.bat`:
```
[*] Total log files: 15
[+] Successful authentications: 12
[+] Failed authentications: 3

Latest entry:
{"timestamp":1700000000000,"attempt":1,"success":true,"totalLatency":450}
```

---

## 📁 Key Files

| File | Purpose |
|------|---------|
| `app-debug_frida.apk` | Repacked APK with Frida Gadget (120MB) |
| `complete_workflow.bat` | Full automation (recommended) |
| `install_frida_apk.bat` | Install APK on device |
| `connect_frida_gadget.bat` | Connect Frida to app |
| `check_logs.bat` | View timing logs |
| `monitor_logs.bat` | Real-time log monitoring |
| `clear_logs.bat` | Delete logs from device |

---

## 🔧 Troubleshooting

### App won't install?
```cmd
adb uninstall com.fyp.limit.limit_test_app
install_frida_apk.bat
```

### Frida won't connect?
```cmd
# Check app is running
adb shell pidof com.fyp.limit.limit_test_app

# Launch manually
adb shell am start -n com.fyp.limit.limit_test_app/.MainActivity
```

### No logs appearing?
```cmd
# Check permissions
adb shell dumpsys package com.fyp.limit.limit_test_app | grep EXTERNAL

# Check directory
adb shell ls -lh /storage/emulated/0/BioShield/logs/
```

---

## 📊 Log Location

**On Device**: `/storage/emulated/0/BioShield/logs/`

**Local Copy**: `logs_from_device/` (after running `check_logs.bat`)

**Format**: JSONL (one JSON object per line)

**Auto-Cleanup**: Keeps last 50 files

---

## 🎬 Testing Workflow

```
1. Run complete_workflow.bat
   ↓
2. Use app on Pixel 6
   ↓
3. Trigger biometric authentication
   ↓
4. Watch Frida window for hook output
   ↓
5. Watch log monitor for new files
   ↓
6. Run check_logs.bat to analyze results
```

---

## 📞 Need Help?

- Full documentation: [PIXEL6_AUTOMATION_GUIDE.md](PIXEL6_AUTOMATION_GUIDE.md)
- Repack guide: [FRIDA_GADGET_REPACK_GUIDE.md](FRIDA_GADGET_REPACK_GUIDE.md)
- Frida package: [REPACK/frida/README.md](REPACK/frida/README.md)

---

**Version**: 1.0.0
**Device**: Pixel 6 (Non-Root)
**Last Updated**: 2025-01-16
