# BioShield Testing Workflow

## Architecture Overview

```
┌─────────────────────┐         ┌──────────────────────┐
│   Target App        │         │    BioShield App     │
│  (with Frida)       │         │   (Scanner)          │
├─────────────────────┤         ├──────────────────────┤
│ • Any Android app   │         │ • NO Frida needed    │
│ • Frida Gadget ✓    │         │ • Reads log files    │
│ • agent.js script   │         │ • Scans & analyzes   │
│ • Biometric auth    │         │ • Uploads to Firebase│
└──────────┬──────────┘         └──────────┬───────────┘
           │                               │
           │ Writes logs                   │ Reads logs
           ↓                               ↓
    ┌──────────────────────────────────────────┐
    │  /storage/emulated/0/BioShield/logs/     │
    │  ├── timing_2025-11-16T12-30-45.jsonl    │
    │  ├── timing_2025-11-16T12-31-12.jsonl    │
    │  └── timing_2025-11-16T12-32-03.jsonl    │
    └──────────────────────────────────────────┘
```

## Why Two Separate Apps?

### BioShield (Scanner)
- **Purpose:** Analyze biometric security of OTHER apps
- **Frida Needed?** ❌ NO
- **Installation:** Regular APK
- **Package:** `com.fyp.bioshield.bioshield`

### Target App (Test Subject)
- **Purpose:** App being tested for vulnerabilities
- **Frida Needed?** ✅ YES (injected via repack)
- **Installation:** Repacked with `./repack_with_frida_gadget.bat`
- **Package:** Any app you want to test

## Complete Testing Steps

### 1. Install BioShield (Scanner)
```bash
# Build BioShield
cd BioShield
flutter build apk --debug

# Install to device
adb -s emulator-5554 install build/app/outputs/flutter-apk/app-debug.apk
```

### 2. Create Test App with Frida

**Option A: Repack Existing App**
```bash
# Download any app APK (banking app, fintech app, etc.)
./repack_with_frida_gadget.bat target_app.apk

# Output: target_app_frida.apk
```

**Option B: Build Simple Test App**
```bash
# Create minimal Flutter app with biometric
flutter create test_biometric_app
cd test_biometric_app
flutter pub add local_auth

# Build it
flutter build apk

# Repack with Frida
cd ../BioShield
./repack_with_frida_gadget.bat ../test_biometric_app/build/app/outputs/flutter-apk/app-debug.apk
```

### 3. Install Target App
```bash
adb -s emulator-5554 install target_app_frida.apk
```

### 4. Run the Test

**Step 1: Clear old logs**
```bash
adb -s emulator-5554 shell "rm -f /storage/emulated/0/BioShield/logs/*.jsonl"
```

**Step 2: Launch target app and trigger biometric**
```bash
# Launch the app
adb -s emulator-5554 shell am start -n com.your.target.app/.MainActivity

# Trigger biometric authentication
adb -s emulator-5554 emu finger touch 1
```

**Step 3: Verify logs created**
```bash
adb -s emulator-5554 shell "ls -la /storage/emulated/0/BioShield/logs/"

# Should show:
# timing_2025-11-16T12-30-45.jsonl
```

**Step 4: View log contents**
```bash
adb -s emulator-5554 shell "cat /storage/emulated/0/BioShield/logs/timing_*.jsonl"

# Should show JSON:
# {"timestamp":1700000000,"attempt":1,"success":true,"totalLatency":234}
```

**Step 5: Open BioShield and scan**
```bash
# Launch BioShield
adb -s emulator-5554 shell am start -n com.fyp.bioshield.bioshield/...

# Tap "Scan" button
# BioShield reads logs, generates report, uploads to Firebase
```

## Expected Results

### If Everything Works:

1. ✅ Target app creates `.jsonl` files in `/storage/emulated/0/BioShield/logs/`
2. ✅ BioShield detects and reads the log files
3. ✅ Report generated with risk score
4. ✅ Data uploaded to Firebase
5. ✅ Log files deleted after scan

### Common Issues:

**Issue:** No logs created
- **Check:** Frida Gadget properly injected?
- **Check:** agent.js copied to APK assets?
- **Check:** App actually triggered biometric?
- **Solution:** Check logcat for Frida output

**Issue:** BioShield can't read logs
- **Check:** File permissions (MANAGE_EXTERNAL_STORAGE granted?)
- **Check:** Files are `.jsonl` format?
- **Solution:** Check BioShield logs for file read errors

**Issue:** Empty scan results
- **Check:** Logs contain valid JSON?
- **Check:** GadgetFileReaderService working?
- **Solution:** Add debug prints in service

## Debugging Commands

### Check Frida is running:
```bash
adb -s emulator-5554 logcat | grep -i frida

# Should show:
# [+] BioShield Frida agent loading (Shared Storage Mode)...
# [+] Hooking BiometricPrompt APIs
```

### Monitor log creation in real-time:
```bash
adb -s emulator-5554 shell "while true; do ls -la /storage/emulated/0/BioShield/logs/; sleep 2; done"
```

### Pull logs for inspection:
```bash
adb -s emulator-5554 pull /storage/emulated/0/BioShield/logs/ ./test_logs/
cat ./test_logs/*.jsonl
```

### Check BioShield logs:
```bash
adb -s emulator-5554 logcat | grep GadgetFileReader
adb -s emulator-5554 logcat | grep ComprehensiveScan
```

## File Structure

### Target App (with Frida)
```
target_app_frida.apk
├── lib/arm64-v8a/
│   └── libfrida-gadget.so          # Frida library
├── assets/
│   ├── frida-agent.js              # Our hooks
│   └── frida-gadget.config         # Config
└── AndroidManifest.xml
```

### Shared Storage
```
/storage/emulated/0/BioShield/
├── README.txt
└── logs/
    ├── timing_2025-11-16T12-30-45.jsonl  ← Target app writes
    ├── timing_2025-11-16T12-31-12.jsonl
    └── timing_2025-11-16T12-32-03.jsonl
                    ↑
                    BioShield reads & deletes
```

## Summary

**Key Points:**
1. BioShield = Scanner (NO Frida)
2. Target App = Test subject (WITH Frida)
3. Communication = File-based (shared storage)
4. Workflow = Write logs → Read logs → Delete logs

**One-Command Test:**
```bash
# Install both apps
adb install bio shield_regular.apk
adb install target_app_frida.apk

# Trigger biometric
adb shell am start -n target.app/.MainActivity
adb emu finger touch 1

# Verify
adb shell ls /storage/emulated/0/BioShield/logs/

# Scan with BioShield
# (open app and tap Scan button)
```
