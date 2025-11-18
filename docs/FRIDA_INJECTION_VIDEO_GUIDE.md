# Frida Injection Video Presentation Guide
**BioShield - Biometric Security Analysis**
**Date**: 2025-11-15

---

## Overview

This guide provides step-by-step instructions for demonstrating Frida injection and biometric timing analysis in your video presentation.

---

## Prerequisites Checklist

### Software Requirements
- ✅ Python 3.13 installed
- ✅ Frida tools installed (`pip install frida-tools`)
- ✅ ADB (Android Debug Bridge) configured
- ✅ Android Emulator (Pixel 6 API 35) or physical device with root access

### Files Required
- ✅ Enhanced Frida agent: `REPACK/frida/agent.js`
- ✅ Target vulnerable app APK
- ✅ Frida server binary for your device architecture

### Device Setup
- ✅ Device rooted (or emulator with root)
- ✅ Frida server running on device
- ✅ USB debugging enabled
- ✅ ADB connection established

---

## Part 1: Environment Setup (2-3 minutes)

### Step 1: Verify ADB Connection

```bash
# Check connected devices
adb devices
```

**Expected Output**:
```
List of devices attached
emulator-5554    device
```

**Talking Points**:
- "First, I'll verify my Android emulator is connected via ADB"
- "We can see the Pixel 6 API 35 emulator is ready"

---

### Step 2: Start Frida Server on Device

```bash
# Push frida-server to device
adb push frida-server-x86_64 /data/local/tmp/frida-server

# Make it executable
adb shell chmod 755 /data/local/tmp/frida-server

# Start frida-server as root
adb shell "su -c '/data/local/tmp/frida-server &'"
```

**Talking Points**:
- "Next, I'll push the Frida server to the device"
- "This allows us to inject JavaScript code into running Android processes"
- "The server runs with root privileges to hook system-level APIs"

---

### Step 3: Verify Frida is Running

```bash
# List running processes via Frida
frida-ps -U
```

**Expected Output**:
```
PID  Name
---  -----------------------
1234 com.android.systemui
5678 com.google.android.gms
...
```

**Talking Points**:
- "Frida is now successfully connected to the device"
- "We can see all running processes on the Android system"

---

## Part 2: Install Vulnerable Test App (1-2 minutes)

### Step 4: Install the Target App

```bash
# Uninstall previous version (if exists)
adb uninstall com.fyp.vulnerable.vulnerable_biometric_app

# Install the vulnerable app
adb install vulnerable_biometric_app.apk
```

**Talking Points**:
- "I'm installing a vulnerable biometric app for demonstration"
- "This app uses BiometricPrompt API for fingerprint authentication"
- "We'll analyze its timing characteristics to detect security flaws"

---

### Step 5: Launch the App

```bash
# Launch the app
adb shell am start -n com.fyp.vulnerable.vulnerable_biometric_app/.MainActivity
```

**Show on Screen**:
- App launches with biometric authentication screen
- Point out the fingerprint icon

---

## Part 3: Frida Injection with Enhanced Timing Analysis (5-7 minutes)

### Step 6: Inject Enhanced Frida Agent

```bash
# Navigate to project directory
cd c:\Users\User\Desktop\School\FYP\BioShield

# Inject Frida agent with timing hooks
frida -U -f com.fyp.vulnerable.vulnerable_biometric_app -l REPACK/frida/agent.js --no-pause
```

**Expected Console Output**:
```
[+] BioShield Frida agent loading (Enhanced Timing Mode)...
[+] Java.perform() started
[+] BiometricPrompt hooked with enhanced timing analysis!
[+] FingerprintManager hooked with enhanced timing analysis!
[+] DELETE_LOG broadcast receiver registered
[+] Timing data will be written to shared storage
[+] File location: /storage/emulated/0/Android/data/com.fyp.vulnerable.vulnerable_biometric_app/files/logs/timing.jsonl
[+] ✓ BioShield hooks installed successfully!
```

**Talking Points**:
- "I'm now injecting our enhanced Frida agent into the running app"
- "The agent hooks BiometricPrompt API calls to capture detailed timing metrics"
- "Notice the hooks are installed successfully - we're ready to intercept biometric authentication"

---

### Step 7: Trigger Biometric Authentication (Attempt #1)

**On the Emulator**:
- Click "Authenticate with Fingerprint" button
- Use emulator fingerprint simulation (successful authentication)

**Expected Frida Console Output**:
```
[+] BiometricPrompt.authenticate() called (Attempt #1)
[*] Sensor help event: Finger detected (code: 1)
[+] Detailed timing data written:
    Total latency: 856ms
    Acquisition: 245ms
    Detection→Match: 611ms
    File: /storage/emulated/0/Android/data/.../timing.jsonl
[+] AUTH_DONE broadcast sent to BioShield
```

**Talking Points**:
- "Watch the console - Frida immediately intercepts the BiometricPrompt.authenticate() call"
- "We capture the **total latency** of 856 milliseconds"
- "**Acquisition duration** - the time from sensor ready to finger detected: 245ms"
- "**Detection to match latency** - the template matching phase: 611ms"
- "All timing data is written to a JSONL file for analysis"

---

### Step 8: Trigger Multiple Attempts (Attempts #2-5)

**On the Emulator**:
- Trigger authentication 4 more times
- Mix successful and failed attempts

**Expected Frida Console Output (Attempt #3)**:
```
[+] BiometricPrompt.authenticate() called (Attempt #3)
[*] Sensor help event: Finger detected (code: 1)
[+] Detailed timing data written:
    Total latency: 872ms
    Acquisition: 250ms
    Detection→Match: 622ms
    File: /storage/emulated/0/Android/data/.../timing.jsonl
[+] Timing variation analysis (3 samples):
    Total latency StdDev: 127.82ms
    Acquisition StdDev: 34.56ms
[+] AUTH_DONE broadcast sent to BioShield
```

**Talking Points**:
- "After the third attempt, Frida begins statistical analysis"
- "The **standard deviation** of 127.82ms shows timing variation across attempts"
- "This variation analysis helps detect timing side-channels and replay attacks"

---

### Step 9: Demonstrate Failure Timing Pattern

**On the Emulator**:
- Use wrong fingerprint (or simulate failed attempt)

**Expected Frida Console Output**:
```
[+] BiometricPrompt.authenticate() called (Attempt #4)
[*] Sensor help event: Finger detected (code: 1)
[!] Authentication FAILED - Timing pattern:
    Total: 342ms
    Pattern: Quick Reject
[+] Detailed timing data written:
    Total latency: 342ms
    Acquisition: 137ms
    Detection→Match: 205ms
```

**Talking Points**:
- "Notice the failed authentication has a **quick reject pattern** (342ms)"
- "This is suspicious - normally rejection takes longer due to template matching"
- "Quick rejection patterns can indicate bypass vulnerabilities or incomplete validation"

---

## Part 4: View Captured Timing Data (2-3 minutes)

### Step 10: Retrieve Timing Data from Device

```bash
# Pull the timing.jsonl file from device
adb pull /storage/emulated/0/Android/data/com.fyp.vulnerable.vulnerable_biometric_app/files/logs/timing.jsonl
```

**Talking Points**:
- "Let's retrieve the captured timing data from the device"
- "This JSONL file contains all authentication attempts with detailed metrics"

---

### Step 11: Display Timing Data

```bash
# View the timing data
cat timing.jsonl | head -20
```

**Expected JSON Output**:
```json
{
  "type": "TIMING",
  "timestamp": 1699876543210,
  "phase": "authenticate",
  "event": "success",
  "success": true,
  "attemptNumber": 3,
  "totalLatency": 856,
  "acquisitionDuration": 245,
  "detectionToMatchLatency": 611,
  "authStart": 123456,
  "authEnd": 124312,
  "timingBreakdown": {
    "sensorReady": 0,
    "fingerDetected": 245,
    "matching": 611,
    "total": 856
  },
  "statistics": {
    "samples": 3,
    "totalLatency": {
      "avg": 856.4,
      "stdDev": 127.8,
      "min": 720,
      "max": 1042
    }
  },
  "packageName": "com.fyp.vulnerable.vulnerable_biometric_app"
}
```

**Talking Points**:
- "Here's the detailed JSON output for each authentication attempt"
- "Notice the **5 must-have timing metrics** we capture:"
  1. **totalLatency**: Complete authentication time (856ms)
  2. **acquisitionDuration**: Sensor to finger detection (245ms)
  3. **detectionToMatchLatency**: Template matching time (611ms)
  4. **failurePattern**: Quick/Normal/Slow rejection classification
  5. **statistics**: Variation analysis across multiple attempts

---

## Part 5: BioShield App Analysis (3-4 minutes)

### Step 12: Open BioShield App

**On the Emulator**:
- Launch BioShield app
- Navigate to "Biometric Analyzer" page

**Talking Points**:
- "Now let's analyze this data using BioShield's ML-powered analyzer"
- "The app automatically finds the latest timing.jsonl file from Downloads"

---

### Step 13: Analyze Timing Data

**In BioShield App**:
- Click "Analyze Latest Biometric JSON" button
- Wait for analysis to complete

**Expected Output on Screen**:
```
Risk Score: 37 / 100

Timing Analysis:
  Total Latency: 856ms
  Acquisition: 245ms
  Detection→Match: 611ms

  Variation Analysis:
    Samples: 5
    StdDev: 127.82ms

Weaknesses:
• None detected - timing patterns are normal

Recommendations:
• Continue monitoring for timing anomalies
• Implement constant-time comparisons
```

**Talking Points**:
- "The analyzer evaluates all 5 timing metrics"
- "This app shows a **low risk score** of 37/100"
- "The timing patterns appear normal with acceptable variation"
- "If we had detected anomalies, the risk score would be higher"

---

### Step 14: Demonstrate Vulnerability Detection

**For Demo**: Show a pre-analyzed vulnerable app result

**Expected Vulnerable Output**:
```
Risk Score: 78 / 100

Timing Analysis:
  Total Latency: 145ms
  Acquisition: 12ms
  Detection→Match: 43ms

  Variation Analysis:
    Samples: 5
    StdDev: 3.2ms

Weaknesses:
• Suspiciously short total latency (145ms) - possible bypass
• Instant finger acquisition (12ms) - possible bypass
• Instant biometric match (43ms) - possible spoof
• Suspiciously consistent timing (StdDev: 3.2ms) - possible replay attack

Recommendations:
• Review timing to detect possible replay or bypass attacks
• Implement liveness detection and verify sensor feedback
• Add anti-spoofing measures and verify template matching
• Add random delays and nonce-based challenges
```

**Talking Points**:
- "Here's an example of a **vulnerable app** with a high risk score of 78/100"
- "Notice the **instant timing** - only 145ms total latency"
- "**Acquisition in 12ms** - the sensor barely registered the fingerprint"
- "**Very low variation** (3.2ms stdDev) - indicates possible replay attack"
- "BioShield provides specific recommendations to fix each vulnerability"

---

## Part 6: Key Features Demonstration (2-3 minutes)

### Step 15: Highlight Enhanced Timing Metrics

**Show on Screen** (Split view):
- **Left**: Frida console with real-time hooks
- **Right**: BioShield analyzer showing timing breakdown

**Talking Points**:
"Our enhanced Frida agent captures **5 critical timing metrics**:

1. **Total Authentication Latency**
   - Measures complete auth flow
   - Detects bypass attempts (<200ms)
   - Flags timeout issues (>3000ms)

2. **Acquisition Duration**
   - Sensor ready → finger detected
   - Instant acquisition (<50ms) = bypass
   - Shows sensor validation quality

3. **Detection → Match Latency**
   - Template matching time
   - Instant match (<100ms) = spoof
   - Indicates biometric processing strength

4. **Failure Timing Pattern**
   - Quick Reject: <300ms (suspicious)
   - Normal Reject: 300-1000ms (expected)
   - Slow Reject: >1000ms (timeout)

5. **Variation Over Multiple Attempts**
   - High variation (>500ms stdDev) = side-channel
   - Low variation (<10ms stdDev) = replay attack
   - Normal: 10-500ms stdDev"

---

### Step 16: Show API Detection Feature

**In Frida Console**:
```
[+] FingerprintManager.authenticate() called (Legacy API - Attempt #1)
```

**In BioShield Analyzer**:
```
Weaknesses:
• Using deprecated FingerprintManager API

Recommendations:
• Migrate to BiometricPrompt API for better security
```

**Talking Points**:
- "Our agent also detects if apps use the **deprecated FingerprintManager API**"
- "Modern apps should use BiometricPrompt for enhanced security"
- "BioShield flags this as a weakness with upgrade recommendations"

---

## Part 7: Cleanup & Conclusion (1 minute)

### Step 17: Stop Frida Agent

```bash
# Press Ctrl+C to stop Frida
^C
[*] Detaching from process...
```

**Talking Points**:
- "That concludes the Frida injection demonstration"
- "We successfully hooked biometric APIs and captured detailed timing metrics"

---

### Step 18: Summary of Capabilities

**Show Summary Slide**:

**BioShield Enhanced Timing Analysis**:
- ✅ Real-time Frida injection into biometric apps
- ✅ Hooks BiometricPrompt & FingerprintManager APIs
- ✅ Captures 5 must-have timing metrics
- ✅ Statistical analysis across multiple attempts
- ✅ Detects 5 vulnerability patterns:
  1. Timing side-channels
  2. Replay attacks
  3. Bypass attempts
  4. Spoof detection
  5. API deprecation

**Results**:
- Timing data exported to JSONL
- ML-powered risk scoring
- Actionable security recommendations
- Free vs Premium analysis tiers

---

## Quick Reference Commands

### Complete Workflow (Copy-Paste Ready)

```bash
# 1. Check device connection
adb devices

# 2. Start frida-server (if not running)
adb shell "su -c '/data/local/tmp/frida-server &'"

# 3. Verify Frida connection
frida-ps -U

# 4. Install vulnerable app
adb install vulnerable_biometric_app.apk

# 5. Inject Frida agent
cd c:\Users\User\Desktop\School\FYP\BioShield
frida -U -f com.fyp.vulnerable.vulnerable_biometric_app -l REPACK/frida/agent.js --no-pause

# 6. (Trigger biometric authentication in app)

# 7. Pull timing data
adb pull /storage/emulated/0/Android/data/com.fyp.vulnerable.vulnerable_biometric_app/files/logs/timing.jsonl

# 8. View timing data
cat timing.jsonl
```

---

## Troubleshooting

### Issue: "Frida server not running"
**Solution**:
```bash
adb shell "su -c 'killall frida-server'"
adb shell "su -c '/data/local/tmp/frida-server &'"
```

### Issue: "Process not found"
**Solution**:
```bash
# Launch app first
adb shell am start -n com.fyp.vulnerable.vulnerable_biometric_app/.MainActivity

# Then inject
frida -U com.fyp.vulnerable.vulnerable_biometric_app -l REPACK/frida/agent.js
```

### Issue: "Permission denied writing timing.jsonl"
**Solution**:
```bash
# Grant storage permissions
adb shell pm grant com.fyp.vulnerable.vulnerable_biometric_app android.permission.WRITE_EXTERNAL_STORAGE
adb shell pm grant com.fyp.vulnerable.vulnerable_biometric_app android.permission.READ_EXTERNAL_STORAGE
```

---

## Presentation Tips

### Camera Setup
1. **Screen Recording**: Use OBS Studio or similar
2. **Split View**: Show emulator + terminal side-by-side
3. **Font Size**: Increase terminal font to 16pt+ for visibility

### Pacing
- Speak clearly and slowly
- Pause after each major step
- Allow 2-3 seconds for outputs to display
- Point out key metrics in real-time

### Emphasis Points
- Highlight the **5 must-have timing metrics** repeatedly
- Show the **before/after** comparison (vulnerable vs secure)
- Demonstrate **real-time detection** capabilities
- Explain **practical security implications**

### Visual Aids
- Use arrows or highlights to point at important console output
- Zoom in on timing values
- Color-code: Red = vulnerable, Green = secure

---

## Estimated Timeline

| Section | Duration | Content |
|---------|----------|---------|
| **Part 1**: Environment Setup | 2-3 min | ADB, Frida server, verification |
| **Part 2**: Install App | 1-2 min | APK installation and launch |
| **Part 3**: Frida Injection | 5-7 min | Hook installation, authentication attempts |
| **Part 4**: View Timing Data | 2-3 min | Pull and display JSON data |
| **Part 5**: BioShield Analysis | 3-4 min | Risk scoring and recommendations |
| **Part 6**: Key Features | 2-3 min | Highlight timing metrics and detection |
| **Part 7**: Conclusion | 1 min | Summary and cleanup |
| **Total** | **16-23 minutes** | Full demonstration |

---

## Success Checklist

Before recording, ensure:
- ✅ Frida agent loads without errors
- ✅ Hooks install successfully (BiometricPrompt + FingerprintManager)
- ✅ Timing data writes to shared storage
- ✅ All 5 timing metrics captured correctly
- ✅ Statistical analysis appears after 2+ attempts
- ✅ BioShield analyzer can read timing.jsonl
- ✅ Risk scoring displays properly
- ✅ Recommendations engine works

---

**Good luck with your presentation!**
