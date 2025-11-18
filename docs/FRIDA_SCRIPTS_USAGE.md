# Frida Automation Scripts - Usage Guide

## Overview

Two batch scripts to automate Frida setup and app hooking:

1. **start_frida_server.bat** - Ensures frida-server is running on emulator
2. **frida_hook_app.bat** - Hooks and launches an app with Frida

---

## Script 1: start_frida_server.bat

### Purpose
Checks if frida-server is running on the emulator. If not, starts it automatically.

### Usage
```cmd
start_frida_server.bat
```

### What it does
1. Checks if frida-server is already running
2. If running, displays PID and exits
3. If not running:
   - Enables adb root access
   - Verifies frida-server binary exists at `/data/local/tmp/frida-server`
   - Starts frida-server in background
   - Verifies startup was successful

### Example Output
```
[*] Checking if frida-server is running...
[-] frida-server is not running. Starting it now...
[*] Enabling root access...
[*] Checking if frida-server binary exists on device...
[*] Starting frida-server...
[+] SUCCESS! frida-server started with PID: 5323
```

### Troubleshooting
If you get "frida-server binary not found", push it to the device first:
```cmd
adb push frida-server-x86_64 /data/local/tmp/frida-server
adb shell "chmod 755 /data/local/tmp/frida-server"
```

---

## Script 2: frida_hook_app.bat

### Purpose
Hooks an app with Frida agent and launches it in spawn mode.

### Usage

**Default (limit_test_app):**
```cmd
frida_hook_app.bat
```

**Custom package:**
```cmd
frida_hook_app.bat com.fyp.vulnerable.vulnerable_biometric_app
```

**Custom package and agent:**
```cmd
frida_hook_app.bat com.example.app path/to/custom_agent.js
```

### What it does
1. Calls `start_frida_server.bat` to ensure frida-server is running
2. Verifies the target app is installed
3. Verifies the agent script exists
4. Launches Frida with spawn mode (`-f` flag)
5. Shows live Frida console output

### Example Output
```
========================================
BioShield Frida Hook Script
========================================
[*] Target Package: com.fyp.limit.limit_test_app
[*] Agent Script: REPACK/frida/agent.js
========================================

[Step 1/4] Checking frida-server status...
[+] frida-server is already running!
[+] Process ID: 5323

[Step 2/4] Verifying app is installed...
[+] App is installed

[Step 3/4] Verifying agent script exists...
[+] Agent script found

[Step 4/4] Launching Frida in spawn mode...
[*] Command: "C:/Users/User/AppData/Roaming/Python/Python313/Scripts/frida.exe" -U -f com.fyp.limit.limit_test_app -l REPACK/frida/agent.js
[*] Press Ctrl+C to stop Frida

========================================
Frida Output:
========================================

[+] BioShield Frida agent loading (Enhanced Timing Mode)...
[+] Java.perform() started
[+] BiometricPrompt hooked with enhanced timing analysis!
...
```

### Configuration

Edit the top of `frida_hook_app.bat` to change defaults:

```batch
set FRIDA_PATH=C:/Users/User/AppData/Roaming/Python/Python313/Scripts/frida.exe
set DEFAULT_PACKAGE=com.fyp.limit.limit_test_app
set DEFAULT_AGENT=REPACK/frida/agent.js
```

---

## Quick Start Workflow

### First Time Setup
```cmd
REM 1. Push frida-server to device (one time only)
adb push frida-server-x86_64 /data/local/tmp/frida-server
adb shell "chmod 755 /data/local/tmp/frida-server"
```

### Daily Workflow

**Option 1: Use default app (limit_test_app)**
```cmd
frida_hook_app.bat
```

**Option 2: Hook different app**
```cmd
frida_hook_app.bat com.fyp.vulnerable.vulnerable_biometric_app
```

**Option 3: Just start frida-server (no hooking)**
```cmd
start_frida_server.bat
```

---

## Testing with Emulator Biometric

After Frida hooks the app, use these commands in a second terminal:

**Successful fingerprint:**
```cmd
adb emu finger touch 1
```

**Failed fingerprint:**
```cmd
adb emu finger touch 2
```

---

## Common Issues

### Issue: "frida-server is not running" every time
**Solution:** Emulator restarts clear frida-server. Just run the script again - it will auto-start it.

### Issue: "Package is not installed"
**Solution:** Install the app first:
```cmd
adb install path/to/app.apk
```

### Issue: "Agent script not found"
**Solution:** Make sure you're running the script from the BioShield directory, or provide full path to agent.js

### Issue: Frida hangs at "Spawning..."
**Solution:** Kill any existing Frida processes:
```cmd
taskkill /F /IM frida.exe
```

---

## Advanced Usage

### Run frida-server manually (persistent)
```cmd
adb root
adb shell "nohup /data/local/tmp/frida-server > /dev/null 2>&1 &"
```

### Check frida-server status manually
```cmd
adb shell "pidof frida-server"
```

### Kill frida-server
```cmd
adb shell "killall frida-server"
```

### View frida-server logs
```cmd
adb shell "cat /data/local/tmp/frida-server.log"
```

---

## Script Locations

Both scripts are located in:
```
c:\Users\User\Desktop\School\FYP\BioShield\
├── start_frida_server.bat
├── frida_hook_app.bat
└── REPACK/
    └── frida/
        └── agent.js
```

---

## Integration with BioShield Workflow

1. Start frida-server: `start_frida_server.bat`
2. Hook target app: `frida_hook_app.bat [package]`
3. App launches with Frida attached
4. Trigger biometric authentication in the app
5. Frida agent captures timing data
6. BioShield reads logs from: `/storage/emulated/0/Android/data/[package]/files/BioShield/timing.jsonl`

---

## Support

For issues or questions, check:
- [FRIDA_CALLBACK_FIX_COMPLETE.md](FRIDA_CALLBACK_FIX_COMPLETE.md) - Callback fix details
- [EMULATOR_TESTING_GUIDE.md](EMULATOR_TESTING_GUIDE.md) - Emulator testing guide
- Frida documentation: https://frida.re/docs/

---

**Last Updated:** 2025-11-15
**BioShield Version:** 1.0.0
