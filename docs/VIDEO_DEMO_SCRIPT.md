# BioShield FYP - Complete Video Demonstration Script

## 🎬 Video Structure (15-20 minutes total)

### Part 1: Introduction (2 minutes)
### Part 2: Frida Gadget Repack Demo (5 minutes)
### Part 3: Side-Channel Attack Detection (5 minutes)
### Part 4: Free Tier Limitations (3 minutes)
### Part 5: Conclusion (2 minutes)

---

## 🎥 PART 1: Introduction (2 minutes)

**On Screen:** PowerPoint title slide

**Narration:**
"Welcome to my Final Year Project presentation on BioShield - an Android biometric security analyzer that detects vulnerabilities and side-channel attacks in real-time.

The system consists of three main components:
1. Frida Gadget - for hooking biometric APIs
2. Machine Learning models - for spoof and anomaly detection
3. Side-channel analysis - for detecting timing attacks

Today, I'll demonstrate the complete workflow from repacking an app with Frida Gadget to detecting sophisticated timing attacks."

**Visuals:**
- Architecture diagram
- System flow chart
- Key features list

---

## 🎥 PART 2: Frida Gadget Repack Demo (5 minutes)

### Step 1: Show Original App (30 seconds)

**On Screen:** biometric_test_app running normally

**Narration:**
"Here's our test application. It's a simple biometric authentication app with four security levels - Perfect, Good, Weak, and Vulnerable. Currently, it's running without any monitoring."

**Actions:**
- Open app
- Click through test buttons
- Show normal authentication

---

### Step 2: Run Automated Repack Script (3 minutes)

**On Screen:** Command prompt with AUTOMATED_REPACK_DEMO.bat

**Narration:**
"To monitor this app, we need to inject Frida Gadget. I've created an automated script that performs all the necessary steps."

**Actions:**
```cmd
cd C:\Users\User\Desktop\School\FYP\BioShield\REPACK
AUTOMATED_REPACK_DEMO.bat app-debug.apk
```

**Narration while script runs:**
"The script is now:
1. Decompiling the APK using apktool
2. Injecting the Frida Gadget library into lib/x86_64
3. Modifying the MainActivity to load Frida on startup
4. Recompiling the modified APK
5. Signing it with our debug keystore
6. Installing it to the device"

**Show on screen:**
- Each step completing with [OK] messages
- File sizes, progress indicators
- Final "SUCCESS" message

---

### Step 3: Verify Frida Loaded (1 minute)

**On Screen:** Split screen - App + Logcat

**Narration:**
"Let's verify that Frida Gadget is now active."

**Actions:**
```cmd
adb logcat | findstr "FRIDA"
```

**Show:**
```
[FRIDA_LOADER] SUCCESS: Frida Gadget loaded!
[FRIDA_SCRIPT] Biometric hooks initialized
[FRIDA_SCRIPT] BiometricManager hooked
[FRIDA_SCRIPT] BiometricPrompt hooked
```

**Narration:**
"Perfect! Frida Gadget is loaded and all biometric hooks are active."

---

## 🎥 PART 3: Side-Channel Attack Detection (5 minutes)

### Step 1: Normal Authentication Baseline (1 minute)

**On Screen:** biometric_test_app + BioShield app side by side

**Narration:**
"First, let's establish a baseline with normal authentication."

**Actions:**
1. Open biometric_test_app
2. Click "Test 1: Perfect Implementation"
3. Scan fingerprint normally
4. Open BioShield → Scan Screen → "Process Logs"

**Show Results:**
```json
{
  "side_channel_score": 0.0,
  "timing_variance": 125.5,
  "timing_entropy": 1.85,
  "vulnerabilities": []
}
```

**Narration:**
"As you can see, legitimate authentication shows zero vulnerabilities and normal timing patterns."

---

### Step 2: Timing Attack Demonstration (2 minutes)

**On Screen:** biometric_test_app with attack buttons visible

**Narration:**
"Now, let's simulate a timing attack. I'll scroll down to our built-in attack demonstrations."

**Actions:**
1. Scroll to "🚨 Side-Channel Attack Demonstrations"
2. Click "ATTACK 1: Timing Attack"
3. Show the status message: "ATTACK: Timing Attack - Instant bypass (5ms delay)"
4. Open BioShield → "Process Logs"

**Show Results:**
```json
{
  "side_channel_score": 75.0,
  "has_timing_attack": true,
  "timing_variance": 3.2,
  "timing_entropy": 0.3,
  "vulnerabilities": [
    "TIMING_ATTACK: Authentication completed in 12ms",
    "CONSTANT_TIME_LEAK: Timing variance = 3.20ms",
    "LOW_TIMING_ENTROPY: Entropy = 0.300"
  ]
}
```

**Narration:**
"BioShield immediately detected the attack! The system identified:
- Authentication completed in just 12 milliseconds (under the 100ms minimum)
- Extremely low timing variance indicating automated behavior
- Low entropy suggesting non-human interaction

The side-channel risk score is 75 out of 100 - a CRITICAL level."

---

### Step 3: Show Firebase Data (1 minute)

**On Screen:** Firebase Console

**Narration:**
"All this data is automatically uploaded to Firebase for our machine learning pipeline."

**Actions:**
1. Open Firebase Console
2. Navigate to Firestore → users → scans
3. Show the latest scan document
4. Highlight `side_channel_analysis` object

**Show:**
```json
{
  "side_channel_analysis": {
    "side_channel_score": 75.0,
    "vulnerabilities": [...],
    "timing_variance": 3.2
  },
  "spoof_features": {...},
  "anomaly_features": {...}
}
```

---

### Step 4: Replay Attack Demo (1 minute)

**Narration:**
"Let me quickly demonstrate another attack type - the Replay Attack."

**Actions:**
1. Clear logs: `adb shell rm /storage/emulated/0/Download/BioShield/logs.jsonl`
2. Click "ATTACK 2: Replay Attack" 3-4 times
3. Process in BioShield

**Show Results:**
```json
{
  "side_channel_score": 65.0,
  "vulnerabilities": [
    "REPLAY_PATTERN: Detected repeating timing intervals",
    "CONSTANT_TIME_LEAK: Timing variance = 0.00ms"
  ]
}
```

**Narration:**
"The system detected the constant 500ms timing pattern - a clear sign of a replay attack."

---

## 🎥 PART 4: Free Tier Limitations (3 minutes)

**On Screen:** BioShield app - Profile/Dashboard screen

**Narration:**
"BioShield implements a freemium model with smart limitations for free users."

### Show Free User Dashboard

**Actions:**
1. Log in as free user
2. Show dashboard with scan counter
3. Display: "2/3 scans remaining today"

---

### Demonstrate Scan Limit

**Narration:**
"Free users are limited to 3 scans per 24-hour period. Let's see what happens when we hit the limit."

**Actions:**
1. Process 3 scans (show counter: 3/3, 2/3, 1/3, 0/3)
2. Try to process a 4th scan

**Show Error:**
```
❌ Scan limit reached
You've used 3/3 scans today
Reset in 18 hours

Upgrade to Premium for unlimited scans!
```

**Code Implementation:**
```dart
// In frida_log_processor.dart
if (!isPremium) {
  final canScan = await _checkScanLimit(userId);
  if (!canScan.allowed) {
    return ProcessResult(
      success: false,
      message: 'Scan limit reached. ${canScan.remainingScans}/3 scans used.',
    );
  }
}
```

---

### Show Export Limitation

**Narration:**
"Additionally, free users cannot export scan reports."

**Actions:**
1. View scan details
2. Try to click "Export PDF/CSV" button
3. Show disabled button with tooltip

**Show UI:**
```
[Export Report] button - DISABLED
Tooltip: "Upgrade to Premium to export reports"
```

---

### Premium Comparison

**On Screen:** Comparison table

| Feature | Free | Premium |
|---------|------|---------|
| Scans per day | 3 | ∞ Unlimited |
| ML Analysis | ✅ | ✅ |
| Side-Channel Detection | ✅ | ✅ |
| Firebase Upload | ✅ | ✅ |
| Export Reports | ❌ | ✅ |
| Price | Free | $4.99/month |

**Narration:**
"This model ensures free users can evaluate the system while incentivizing upgrades for power users."

---

## 🎥 PART 5: Conclusion (2 minutes)

**On Screen:** Summary slide

**Narration:**
"In this demonstration, I've shown:

1. ✅ Automated Frida Gadget repack workflow
2. ✅ Real-time side-channel attack detection
3. ✅ Three attack types: Timing, Replay, and Correlation
4. ✅ Machine learning integration with Firebase
5. ✅ Freemium tier implementation with scan limits

BioShield successfully detects sophisticated attacks that traditional biometric systems miss, providing enterprise-grade security analysis for Android applications.

The system is production-ready for security researchers, penetration testers, and developers who want to ensure their biometric implementations are secure.

Thank you for watching!"

**Final Screen:**
- GitHub repository link
- Contact information
- "Questions?" slide

---

## 📋 Pre-Recording Checklist

Before recording, ensure:

- [ ] Emulator/device is running and visible
- [ ] BioShield app installed and logged in as free user
- [ ] biometric_test_app with Frida Gadget installed
- [ ] Firebase Console open in browser
- [ ] Command prompt ready with REPACK folder
- [ ] Logcat window ready
- [ ] Screen recorder set to 1080p
- [ ] Microphone tested
- [ ] PowerPoint slides ready
- [ ] Demo flow practiced 2-3 times

---

## 🎬 Recording Tips

1. **Use screen recording software** (OBS Studio recommended)
2. **Record in 1080p** at 30fps minimum
3. **Use a good microphone** - clear audio is critical
4. **Zoom in** on important text/code (125-150%)
5. **Slow down** - pause between steps for clarity
6. **Highlight cursor** movements for visibility
7. **Rehearse** the demo 2-3 times before recording
8. **Have backup** - record multiple takes

---

## 🎯 Key Messages to Emphasize

1. **Automation** - The repack process is fully automated
2. **Real-time** - Detection happens immediately
3. **Comprehensive** - 5 types of side-channel attacks detected
4. **Production-ready** - Enterprise-grade security
5. **Smart monetization** - Freemium model balances access and revenue

---

## ⏱️ Time Breakdown

| Section | Duration | Cumulative |
|---------|----------|------------|
| Introduction | 2 min | 2 min |
| Repack Demo | 5 min | 7 min |
| Attack Detection | 5 min | 12 min |
| Free Tier Limits | 3 min | 15 min |
| Conclusion | 2 min | 17 min |
| Buffer/Q&A | 3 min | 20 min |

**Total:** 17-20 minutes (perfect for FYP presentation)

Good luck with your video! 🎓🚀
