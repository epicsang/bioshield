# Side-Channel Attack Demo - Quick Reference

## 🎯 Quick Demo (5 Minutes)

### 1. Setup (30 seconds)
```bash
# Clear old logs
adb shell rm /storage/emulated/0/Download/BioShield/logs.jsonl

# Navigate to attack scripts
cd c:\Users\User\Desktop\School\FYP\BioShield\REPACK\frida\side_channel_attacks
```

### 2. Run Timing Attack (2 minutes)
```bash
# Launch attack
run_timing_attack.bat

# In the app, click any test button
# Watch logcat:
adb logcat | findstr "ATTACK"
```

**Expected Output:**
```
[ATTACK] Intercepted authenticate() - bypassing instantly!
[ATTACK] Triggering instant success!
```

### 3. View Results in BioShield (2 minutes)
```
1. Open BioShield app
2. Scan Screen → "Process Logs"
3. See detection:
   ⚠️ TIMING_ATTACK
   ⚠️ CONSTANT_TIME_LEAK
   📊 Score: 75/100 (CRITICAL)
```

---

## 📋 All Attack Commands

| Attack | Command | Expected Score |
|--------|---------|----------------|
| **Timing** | `run_timing_attack.bat` | 70-85 (CRITICAL) |
| **Replay** | `run_replay_attack.bat` | 60-75 (HIGH) |
| **Correlation** | `run_correlation_attack.bat` | 30-60 (MEDIUM) |
| **Normal** | Use app without Frida hooks | 0-20 (SAFE) |

---

## 🔍 What Gets Detected

### Timing Attack
```
✅ Authentication in 12ms (< 100ms minimum)
✅ Timing variance = 3.20ms (expected > 50ms)
✅ Entropy = 0.300 (expected > 1.0)
```

### Replay Attack
```
✅ Repeating timing intervals detected
✅ Timing variance = 0.00ms
✅ Entropy = 0.000
```

### Timing Correlation
```
✅ Success avg: 2000ms, Failure avg: 800ms
✅ Difference: 1200ms (information leak!)
```

---

## 📱 Testing Workflow

```
1. Clear logs → 2. Run attack → 3. Trigger auth → 4. Process in BioShield
     ↓               ↓                ↓                    ↓
  adb shell rm   run_*.bat    Click test button    "Process Logs"
```

---

## 🎓 For Presentations

**3-Slide Demo:**

**Slide 1: Normal Behavior**
- Screenshot: BioShield showing score 0/100
- Caption: "Legitimate authentication - no vulnerabilities"

**Slide 2: Timing Attack**
- Screenshot: BioShield showing score 75/100
- Caption: "Instant bypass detected in 12ms"
- Highlight: 3 vulnerabilities listed

**Slide 3: Firebase Data**
- Screenshot: Firestore console showing side_channel_analysis
- Caption: "Detailed vulnerability tracking and ML integration"

---

## 🚨 Common Issues

| Issue | Solution |
|-------|----------|
| No logs found | `adb shell cat /storage/emulated/0/Download/BioShield/logs.jsonl` |
| Frida not attaching | `frida-ps -U` to check connection |
| App crashes | Use `timing_attack.js` (simplest) first |
| Score shows 0 | Trigger auth multiple times (3-5x) |

---

## 📊 Firebase Result Example

```json
{
  "side_channel_analysis": {
    "side_channel_score": 75.0,
    "vulnerabilities": [
      "TIMING_ATTACK: Authentication completed in 12ms",
      "CONSTANT_TIME_LEAK: Timing variance = 3.20ms",
      "LOW_TIMING_ENTROPY: Entropy = 0.300"
    ]
  }
}
```

**Path:** `users/{your_uid}/scans/{latest_scan}`

---

## 🎯 Demo Script (For Presentations)

```
"Let me demonstrate BioShield's side-channel attack detection.

[Run timing_attack.bat]

This Frida script bypasses biometric authentication instantly.
Watch the logcat - you can see it triggers success in just 5 milliseconds.

[Show logcat output]

Now let's see if BioShield detected this attack...

[Open BioShield → Process Logs]

As you can see, BioShield detected:
- Timing attack (authentication under 100ms)
- Constant-time leak (variance under 10ms)
- Low entropy (automated behavior)

The system calculated a risk score of 75 out of 100 - CRITICAL level.

[Open Firebase Console]

All this data is uploaded to Firebase with specific vulnerability
descriptions, making it perfect for training our ML models to detect
future attacks automatically.

That's BioShield's real-time side-channel attack detection in action!"
```

**Duration:** 3-4 minutes

---

## 📁 File Locations

```
Attack Scripts:
  c:\Users\User\Desktop\School\FYP\BioShield\REPACK\frida\side_channel_attacks\
  ├── timing_attack.js
  ├── replay_attack.js
  ├── timing_correlation_attack.js
  ├── variance_exploit_attack.js
  ├── run_timing_attack.bat
  ├── run_replay_attack.bat
  └── run_correlation_attack.bat

Documentation:
  c:\Users\User\Desktop\School\FYP\BioShield\docs\
  ├── SIDE_CHANNEL_ATTACK_DEMO_GUIDE.md (Full guide)
  ├── SIDE_CHANNEL_ATTACK_DETECTION.md (Technical details)
  └── ML_DATA_PIPELINE.md (Data structure)

Log File:
  /storage/emulated/0/Download/BioShield/logs.jsonl (on device)
```

---

## ✅ Pre-Demo Checklist

- [ ] Frida server running on device
- [ ] Biometric test app installed
- [ ] BioShield installed and logged in
- [ ] Old logs cleared
- [ ] Firebase console open (optional)
- [ ] Logcat window ready (optional)

---

**Ready to impress! 🚀**
