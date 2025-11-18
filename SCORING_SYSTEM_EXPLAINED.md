# BioShield Security Scoring System - Complete Walkthrough

## Overview
BioShield calculates a **Security Score (0-100)** where:
- **100 = Completely Secure** (no vulnerabilities)
- **0 = Critically Insecure** (maximum vulnerabilities)

The score is calculated using a **Hybrid Approach**:
- **70% Rule-Based Analysis** (Side-Channel Attack Detection)
- **30% ML-Based Analysis** (TFLite Neural Networks)

---

## Step 1: Rule-Based Side-Channel Analysis (70% Weight)

The system runs **5 different side-channel attack detection algorithms**. Each adds points to a **Risk Score** (0-100) where higher = more risky.

### Algorithm 1: Timing Attack Detection (30 points)
**What it detects:** Authentication that completes too quickly (< 100ms)

**How it works:**
1. Groups biometric events into authentication sessions (gap > 1 second = new session)
2. Checks each session duration
3. If session < 100ms → **TIMING_ATTACK detected**

**Code Location:** `lib/services/frida_log_processor.dart:416-451`

```dart
if (sessionDuration < 100) {
  vulnerabilities.add('TIMING_ATTACK: Session completed in ${sessionDuration}ms');
  sideChannelScore += 30.0;  // Add 30 points to risk
}
```

**Example:**
- Session 1: 250ms → Normal ✅
- Session 2: 12ms → **+30 risk points** ⚠️

---

### Algorithm 2: Constant-Time Leak Detection (25 points)
**What it detects:** Automated/scripted attacks with suspiciously uniform timing

**How it works:**
1. Calculates timing variance between events
2. If variance < 10ms AND at least 3 events → **CONSTANT_TIME_LEAK**

**Code Location:** `lib/services/frida_log_processor.dart:453-462`

```dart
if (timingVariance < 10.0 && intervals.length >= 3) {
  vulnerabilities.add('CONSTANT_TIME_LEAK: Variance = ${timingVariance}ms');
  sideChannelScore += 25.0;  // Add 25 points to risk
}
```

**Example:**
- Events: 100ms, 102ms, 101ms, 100ms (variance = 0.8ms)
- Too uniform → **+25 risk points** (likely automated)

---

### Algorithm 3: Timing Channel Exploit Detection (20 points)
**What it detects:** Extremely high variance indicating timing probing attacks

**How it works:**
1. Checks if variance > 5000ms
2. Indicates attacker is deliberately varying timing to probe the system

**Code Location:** `lib/services/frida_log_processor.dart:465-469`

```dart
if (timingVariance > 5000.0) {
  vulnerabilities.add('TIMING_CHANNEL_EXPLOIT: Variance = ${timingVariance}ms');
  sideChannelScore += 20.0;  // Add 20 points to risk
}
```

---

### Algorithm 4: Replay Pattern Detection (35 points)
**What it detects:** Repeating timing patterns indicating replay attacks

**How it works:**
1. Analyzes timing intervals for repeating sequences
2. If same pattern repeats → **REPLAY_PATTERN**

**Code Location:** `lib/services/frida_log_processor.dart:472-477`

```dart
if (_hasRepeatingPattern(intervals)) {
  vulnerabilities.add('REPLAY_PATTERN: Detected repeating timing intervals');
  sideChannelScore += 35.0;  // Add 35 points to risk
}
```

**Example:**
- Intervals: [100, 50, 100, 50, 100, 50]
- Pattern [100, 50] repeats → **+35 risk points**

---

### Algorithm 5: Timing Correlation Detection (30 points)
**What it detects:** Different timing for success vs failure (information leak)

**How it works:**
1. Groups events by success/failure outcome
2. Compares average timing for each
3. If significant difference → **TIMING_CORRELATION**

**Code Location:** `lib/services/frida_log_processor.dart:479-486`

```dart
if (timingByOutcome['correlation_detected'] == true) {
  vulnerabilities.add('TIMING_CORRELATION: Success/failure timing correlation');
  sideChannelScore += 30.0;  // Add 30 points to risk
}
```

**Example:**
- Success events: avg 200ms
- Failure events: avg 50ms
- Timing leaks authentication result → **+30 risk points**

---

### Algorithm 6: Low Entropy Detection (15 points)
**What it detects:** Low randomness in timing (predictable patterns)

**How it works:**
1. Calculates Shannon entropy of timing intervals
2. If entropy < 0.5 → **LOW_TIMING_ENTROPY**

**Code Location:** `lib/services/frida_log_processor.dart:488-495`

```dart
if (timingEntropy < 0.5) {
  vulnerabilities.add('LOW_TIMING_ENTROPY: Entropy = ${timingEntropy}');
  sideChannelScore += 15.0;  // Add 15 points to risk
}
```

---

### Side-Channel Score Summary

| Attack Type | Points Added | Max Contribution |
|-------------|-------------|------------------|
| Timing Attack | 30 | 30% |
| Constant-Time Leak | 25 | 25% |
| Timing Channel Exploit | 20 | 20% |
| Replay Pattern | 35 | 35% |
| Timing Correlation | 30 | 30% |
| Low Entropy | 15 | 15% |
| **Total Possible** | **155** | **Capped at 100** |

**Note:** Score is capped at 100, so multiple vulnerabilities don't exceed maximum risk.

---

## Step 2: ML-Based Analysis (30% Weight)

BioShield uses **2 TFLite Neural Networks** trained to detect spoofing and anomalies.

### ML Model 1: Spoof Detector (60% of ML weight)
**What it detects:** Fake/spoofed biometric authentication attempts

**Input Features:**
1. **Duration** (10-1000ms): How fast auth completed
2. **Entropy** (0-1): Randomness of timing patterns
3. **hasCrypto** (0 or 1): Whether crypto binding was used
4. **networkFlag** (0 or 1): Suspicious network activity detected

**Code Location:** `lib/services/ml_inference_service.dart:172-194`

**Output:**
- **spoofScore** (0-1): Probability this is a spoof
  - 0.0-0.3 = Genuine ✅
  - 0.3-0.7 = Uncertain ⚠️
  - 0.7-1.0 = Spoof Detected 🚨

**Example:**
```
Input: [duration=15ms, entropy=0.2, hasCrypto=0, networkFlag=1]
Output: spoofScore = 0.92 (92% confidence SPOOF)
→ Adds ML vulnerability
```

---

### ML Model 2: Anomaly Detector (40% of ML weight)
**What it detects:** Unusual authentication patterns/behavior

**Input Features:**
1. **Duration** (10-2000ms): Average auth duration
2. **Entropy** (0-1): Success/failure pattern randomness
3. **timeOfDay** (0-23): Hour when auth occurred
4. **dayOfWeek** (1-7): Day of week

**Code Location:** `lib/services/ml_inference_service.dart:199-227`

**Output:**
- **confidence** (0-1): Probability of anomalous behavior
  - > 0.5 = Anomaly Detected

**Example:**
```
Input: [duration=10ms, entropy=0.1, timeOfDay=3, dayOfWeek=2]
Output: confidence = 0.87 (87% anomaly - unusual time + fast auth)
→ Adds ML vulnerability
```

---

### ML Score Calculation

**Step 1:** Convert ML outputs to risk scores (0-100)
```dart
final spoofRisk = spoofResult.spoofScore * 100;      // 0.92 → 92
final anomalyRisk = anomalyResult.confidence * 100;   // 0.87 → 87
```

**Step 2:** Combine with weights (Spoof 60%, Anomaly 40%)
```dart
mlRiskScore = (spoofRisk * 0.6 + anomalyRisk * 0.4);
            = (92 * 0.6) + (87 * 0.4)
            = 55.2 + 34.8
            = 90.0
```

**Code Location:** `lib/services/frida_log_processor.dart:742-749`

---

## Step 3: Hybrid Score Combination

The final risk score combines both approaches:

```dart
combinedRiskScore = (sideChannelScore * 0.7 + mlRiskScore * 0.3)
```

**Example Calculation:**

Assume:
- **Rule-based** detected: Timing Attack (30) + Replay Pattern (35) = **65 points**
- **ML-based** calculated: **90 points** (from above)

```
combinedRiskScore = (65 * 0.7) + (90 * 0.3)
                  = 45.5 + 27.0
                  = 72.5
```

**Code Location:** `lib/services/frida_log_processor.dart:751`

---

## Step 4: Score Inversion for UI

The **Risk Score** (0=secure, 100=risky) is inverted to **Security Score** for better UX:

```dart
securityScore = 100 - combinedRiskScore
              = 100 - 72.5
              = 27.5 → rounded to 28/100
```

**Why?** Users understand **higher score = better security**

**Code Location:** `lib/services/frida_log_processor.dart:769`

---

## Final Score Interpretation

| Security Score | Risk Level | Meaning |
|---------------|-----------|---------|
| **80-100** | ✅ Low Risk | Secure implementation, minimal/no vulnerabilities |
| **60-79** | ⚠️ Medium Risk | Some security issues, should be addressed |
| **40-59** | ⚠️ High Risk | Multiple vulnerabilities, address within 48 hours |
| **0-39** | 🚨 Critical | Severe vulnerabilities, immediate action required |

**Code Location:** `lib/services/frida_log_processor.dart:774-782`

---

## Complete Scoring Flow Example

**Scenario:** ML Spoof Attack from Test App

**Step 1: Input Data**
- Log file with: duration=15ms, hasCrypto=false, networkFlag=true, 2 events

**Step 2: Rule-Based Analysis**
```
Session 1: 15ms < 100ms
→ TIMING_ATTACK detected
→ sideChannelScore = 30
```

**Step 3: ML Analysis**
```
Spoof Detector Input: [15, 0.5, 0, 1]
→ spoofScore = 0.95 (95% spoof)
→ spoofRisk = 95

Anomaly Detector Input: [15, 0.5, 14, 3]
→ confidence = 0.82 (82% anomaly)
→ anomalyRisk = 82

mlRiskScore = (95 * 0.6) + (82 * 0.4) = 89.8
```

**Step 4: Combine Scores**
```
combinedRiskScore = (30 * 0.7) + (89.8 * 0.3)
                  = 21 + 26.94
                  = 47.94
```

**Step 5: Invert for UI**
```
securityScore = 100 - 47.94 = 52.06 → 52/100
```

**Result:** User sees **52/100** (High Risk) with vulnerabilities:
- TIMING_ATTACK: Session completed in 15ms
- ML_SPOOF_DETECTED: 95% confidence
- ML_ANOMALY_DETECTED: 82% confidence

---

## Weightage Breakdown Summary

```
Final Security Score (0-100)
│
├─ 70% Rule-Based Detection
│  ├─ Up to 30 pts: Timing Attack
│  ├─ Up to 25 pts: Constant-Time Leak
│  ├─ Up to 20 pts: Timing Channel Exploit
│  ├─ Up to 35 pts: Replay Pattern
│  ├─ Up to 30 pts: Timing Correlation
│  └─ Up to 15 pts: Low Entropy
│     (Total capped at 100)
│
└─ 30% ML-Based Detection
   ├─ 60% Spoof Detector (TFLite)
   │  └─ Input: [duration, entropy, hasCrypto, networkFlag]
   │
   └─ 40% Anomaly Detector (TFLite)
      └─ Input: [duration, entropy, timeOfDay, dayOfWeek]
```

**Final Formula:**
```
Security Score = 100 - [(SideChannelScore × 0.7) + (MLScore × 0.3)]
```

Where:
- **SideChannelScore** = Sum of rule-based detections (capped at 100)
- **MLScore** = (SpoofRisk × 0.6) + (AnomalyRisk × 0.4)

---

## Key Takeaways

1. **Multiple Detection Layers**: 6 rule-based algorithms + 2 ML models
2. **Weighted Combination**: 70% rules, 30% ML (because rules are more reliable for known attacks)
3. **ML Sub-Weighting**: Spoof detection (60%) weighted higher than anomaly (40%)
4. **Score Inversion**: Internal risk score inverted for better UX
5. **Capping**: Rule-based score capped at 100 to prevent overflow
6. **Additive Risk**: Multiple vulnerabilities stack up to show cumulative risk

This ensures BioShield catches:
- Known attack patterns (rules)
- Unknown/novel attacks (ML)
- Provides actionable security score
