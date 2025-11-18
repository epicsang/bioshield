# Side-Channel Attack Demonstration Scripts

## Quick Start

These scripts demonstrate **5 types of side-channel attacks** that BioShield can detect.

---

## Available Attacks

### 1. Timing Attack (`timing_attack.js`)
**Run:** `run_timing_attack.bat`

Bypasses authentication instantly (~5ms). Demonstrates:
- Instant bypass vulnerability
- Constant-time operation leak

**Expected Detection:**
- ⚠️ TIMING_ATTACK: < 100ms
- ⚠️ CONSTANT_TIME_LEAK
- 📊 Score: 70-85/100 (CRITICAL)

---

### 2. Replay Attack (`replay_attack.js`)
**Run:** `run_replay_attack.bat`

Replays prerecorded timing pattern (constant 500ms). Demonstrates:
- Replay vulnerability
- Repeating patterns
- Zero entropy

**Expected Detection:**
- ⚠️ REPLAY_PATTERN detected
- ⚠️ LOW_TIMING_ENTROPY
- 📊 Score: 60-75/100 (HIGH)

---

### 3. Timing Correlation Attack (`timing_correlation_attack.js`)
**Run:** `run_correlation_attack.bat`

Uses different timing for success (2000ms) vs failure (800ms). Demonstrates:
- Information leakage through timing
- Success/failure distinguishability

**Expected Detection:**
- ⚠️ TIMING_CORRELATION: 1200ms difference
- 📊 Score: 30-60/100 (MEDIUM)

---

### 4. Variance Exploit Attack (`variance_exploit_attack.js`)
**Run manually:**
```bash
frida -U -f com.example.biometric_test_app -l variance_exploit_attack.js --no-pause
```

Uses extreme timing variations (50ms to 5200ms). Demonstrates:
- Timing channel probing
- Vulnerability discovery attempts

**Expected Detection:**
- ⚠️ TIMING_CHANNEL_EXPLOIT: variance > 5000ms
- 📊 Score: 20-40/100 (MEDIUM)

---

## Usage Instructions

### Step 1: Choose Attack
```bash
cd c:\Users\User\Desktop\School\FYP\BioShield\REPACK\frida\side_channel_attacks
```

### Step 2: Clear Previous Logs
```bash
adb shell rm /storage/emulated/0/Download/BioShield/logs.jsonl
```

### Step 3: Run Attack
```bash
# Option A: Use batch file
run_timing_attack.bat

# Option B: Manual Frida command
"C:/Users/User/AppData/Roaming/Python/Python313/Scripts/frida.exe" -U -f com.example.biometric_test_app -l timing_attack.js --no-pause
```

### Step 4: Trigger Authentication
- App will launch automatically
- Click any test button (attack hooks all scenarios)
- Watch logcat for attack messages:
  ```bash
  adb logcat | findstr "ATTACK"
  ```

### Step 5: Process in BioShield
1. Open BioShield app
2. Go to **Scan Screen**
3. Click **"Process Logs"**
4. View side-channel analysis results!

---

## Expected Results

### Normal Behavior (No Attack)
```json
{
  "side_channel_score": 0.0,
  "vulnerabilities": [],
  "timing_variance": 125.5,
  "timing_entropy": 1.85
}
```

### Timing Attack Detection
```json
{
  "side_channel_score": 75.0,
  "vulnerabilities": [
    "TIMING_ATTACK: Authentication completed in 12ms",
    "CONSTANT_TIME_LEAK: Timing variance = 3.20ms",
    "LOW_TIMING_ENTROPY: Entropy = 0.300"
  ]
}
```

### Replay Attack Detection
```json
{
  "side_channel_score": 65.0,
  "vulnerabilities": [
    "REPLAY_PATTERN: Detected repeating timing intervals",
    "CONSTANT_TIME_LEAK: Timing variance = 0.00ms",
    "LOW_TIMING_ENTROPY: Entropy = 0.000"
  ]
}
```

---

## Viewing Results

### Option 1: BioShield App
- Scan Screen → Process Logs
- View risk score and vulnerabilities

### Option 2: Firebase Console
- Firestore → `users/{uid}/scans/`
- Check `side_channel_analysis` field

### Option 3: Logcat
```bash
adb logcat | findstr "FridaLogProcessor"
```

---

## Troubleshooting

**Issue:** No logs created
```bash
# Check Frida is running
adb logcat | findstr "FRIDA_SCRIPT"

# Verify app has permission
adb shell pm grant com.example.biometric_test_app android.permission.WRITE_EXTERNAL_STORAGE
```

**Issue:** Attack not triggering
```bash
# Check Frida attached
frida-ps -U

# Try manual attach
frida -U com.example.biometric_test_app -l timing_attack.js
```

**Issue:** BioShield shows "No logs found"
```bash
# Verify log file exists
adb shell cat /storage/emulated/0/Download/BioShield/logs.jsonl

# Check file is encrypted
adb shell ls -la /storage/emulated/0/Download/BioShield/
```

---

## Attack Comparison

| Attack | Duration | Variance | Entropy | Score | Severity |
|--------|----------|----------|---------|-------|----------|
| Normal | 1500ms | 125ms | 1.85 | 0 | ✅ Safe |
| Timing | 12ms | 3ms | 0.3 | 75 | ⚠️ CRITICAL |
| Replay | 500ms | 0ms | 0.0 | 65 | ⚠️ HIGH |
| Correlation | 1400ms | 360000ms | 1.8 | 45 | ⚠️ MEDIUM |
| Variance | 2600ms | 5123ms | 1.7 | 30 | ⚠️ MEDIUM |

---

## For Presentations/Demos

**Recommended Demo Flow:**

1. **Show Normal Behavior** (baseline)
   - Use app normally without attack scripts
   - Show clean results (score: 0)

2. **Demonstrate Timing Attack** (most dramatic)
   - Run `run_timing_attack.bat`
   - Show CRITICAL score (70-85)
   - Highlight instant bypass

3. **Demonstrate Replay Attack** (realistic threat)
   - Run `run_replay_attack.bat`
   - Show pattern detection
   - Explain replay vulnerability

4. **Show Firebase Data**
   - Open Firebase console
   - Show detailed vulnerability list
   - Explain ML integration

**Total Demo Time:** 10-15 minutes

---

## Documentation

For detailed information, see:
- [`SIDE_CHANNEL_ATTACK_DEMO_GUIDE.md`](../../docs/SIDE_CHANNEL_ATTACK_DEMO_GUIDE.md) - Complete testing guide
- [`SIDE_CHANNEL_ATTACK_DETECTION.md`](../../docs/SIDE_CHANNEL_ATTACK_DETECTION.md) - Technical details
- [`ML_DATA_PIPELINE.md`](../../docs/ML_DATA_PIPELINE.md) - Data pipeline overview

---

## Notes

- All attacks are **educational demonstrations** for FYP research
- Scripts are designed to be **easily detectable** by BioShield
- Real-world attacks may be more sophisticated
- Use only on test apps you control
- Perfect for **academic presentations** and **security research**

Happy testing! 🎓🔒
