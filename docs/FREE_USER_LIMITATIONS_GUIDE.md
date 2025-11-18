# Free User Limitations - Implementation Guide

## Overview

BioShield implements a **freemium model** with smart limitations for free users:
- ✅ **3 scans per 24 hours** - Enforced at service level
- ❌ **No export** - CSV/PDF export disabled
- ✅ **Full ML analysis** - Both spoof and anomaly detection available
- ✅ **Firebase upload** - Data stored for training

---

## ✅ Already Implemented

### 1. Scan Limit Service

**File:** `lib/services/scan_limit_service.dart`

```dart
class ScanLimitService {
  static const int freeTierLimit = 3;  // 3 scans per 24h
  static const int limitWindowHours = 24;

  Future<ScanLimitResult> canImportScan(String userId, bool isPremium) async {
    // Premium users: unlimited
    if (isPremium) {
      return ScanLimitResult(canImport: true, remainingScans: -1);
    }

    // Check scans in last 24 hours
    final windowStart = now.subtract(Duration(hours: 24));
    final recentScans = await _firestore
        .collection('users')
        .doc(userId)
        .collection('scans')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(windowStart))
        .get();

    if (recentScans.docs.length >= 3) {
      return ScanLimitResult(
        canImport: false,
        remainingScans: 0,
        hoursUntilReset: calculateReset(),
      );
    }

    return ScanLimitResult(canImport: true, remainingScans: 3 - recentScans.length);
  }
}
```

**Status:** ✅ COMPLETE

---

### 2. Frida Log Processor Integration

**File:** `lib/services/frida_log_processor.dart`

The `FridaLogProcessor` enforces limits before processing:

```dart
Future<ProcessResult> processAndUpload({
  required String userId,
  required bool isPremium,
  required String packageName,
  required String appName,
}) async {
  // CHECK SCAN LIMITS FOR FREE USERS
  if (!isPremium) {
    final canScan = await _checkScanLimit(userId);
    if (!canScan.allowed) {
      return ProcessResult(
        success: false,
        message: 'Scan limit reached. ${canScan.remainingScans}/3 scans used. Reset in ${canScan.hoursUntilReset}h',
        scanData: null,
      );
    }
  }

  // Process logs and upload to Firebase
  final features = extractMLFeatures(logs, packageName);
  await _firestore.collection('users').doc(userId).collection('scans').add(features);

  return ProcessResult(success: true, message: 'Scan processed successfully!');
}
```

**Status:** ✅ COMPLETE

---

## 🔧 Recommendations for Enhancement

### 1. Add Visual Scan Counter to Dashboard

**File to modify:** `lib/screens/dashboard_screen.dart`

**Add this widget:**

```dart
Widget _buildScanLimitIndicator() {
  return FutureBuilder<ScanLimitResult>(
    future: ScanLimitService().canImportScan(userId, isPremium),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return SizedBox();

      final limit = snapshot.data!;

      if (isPremium) {
        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.all_inclusive, color: Colors.green),
                SizedBox(width: 12),
                Text('Unlimited scans (Premium)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }

      // Free user - show counter
      return Card(
        color: limit.remainingScans == 0 ? Colors.red.shade50 : Colors.blue.shade50,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircularProgressIndicator(
                    value: limit.remainingScans / 3.0,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation(
                      limit.remainingScans == 0 ? Colors.red : Colors.blue,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${limit.remainingScans}/3 scans remaining',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: limit.remainingScans == 0 ? Colors.red : Colors.black,
                          ),
                        ),
                        if (limit.remainingScans == 0)
                          Text(
                            'Reset in ${limit.hoursUntilReset}h',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (limit.remainingScans == 0) ...[
                SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/pricing'),
                  icon: Icon(Icons.upgrade),
                  label: Text('Upgrade to Premium'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
```

---

### 2. Disable Export for Free Users

**File to modify:** `lib/screens/scan_details_screen.dart`

**Update export buttons:**

```dart
Widget _buildExportButton() {
  return ElevatedButton.icon(
    onPressed: isPremium ? _exportToPDF : null,  // Disable if not premium
    icon: Icon(Icons.picture_as_pdf),
    label: Text('Export PDF'),
    style: ElevatedButton.styleFrom(
      backgroundColor: isPremium ? Colors.blue : Colors.grey,
    ),
  );
}

// Add tooltip for free users
Widget _buildExportSection() {
  if (!isPremium) {
    return Tooltip(
      message: 'Upgrade to Premium to export reports',
      child: Opacity(
        opacity: 0.5,
        child: Column(
          children: [
            _buildExportButton(),
            SizedBox(height: 4),
            Text(
              '🔒 Premium Feature',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  return _buildExportButton();
}
```

---

### 3. Add Upgrade Prompts

**Create:** `lib/widgets/upgrade_prompt.dart`

```dart
class UpgradePrompt extends StatelessWidget {
  final String feature;
  final String message;

  const UpgradePrompt({
    required this.feature,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.lock, size: 48, color: Colors.amber),
            SizedBox(height: 12),
            Text(
              feature,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/pricing'),
              icon: Icon(Icons.upgrade),
              label: Text('Upgrade to Premium - \$4.99/month'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Usage:**

```dart
// Show when free user hits limit
if (!isPremium && scanLimit.remainingScans == 0) {
  return UpgradePrompt(
    feature: 'Scan Limit Reached',
    message: 'You\'ve used all 3 free scans today. Upgrade to Premium for unlimited scans!',
  );
}

// Show when trying to export
if (!isPremium) {
  return UpgradePrompt(
    feature: 'Export Reports',
    message: 'Export your scan results to PDF or CSV with Premium.',
  );
}
```

---

### 4. Add Firestore Rules for Scan Limits

**File:** `firestore.rules`

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // User scans - enforce 24h limit for free users
    match /users/{userId}/scans/{scanId} {
      allow read: if request.auth != null && request.auth.uid == userId;

      allow create: if request.auth != null
        && request.auth.uid == userId
        && (
          // Premium users: no limit
          get(/databases/$(database)/documents/users/$(userId)).data.membership.isPremium == true
          ||
          // Free users: check count in last 24h
          getRecentScanCount(userId) < 3
        );

      // Function to count recent scans
      function getRecentScanCount(userId) {
        let recentScans = firestore.get(
          /databases/$(database)/documents/users/$(userId)/scans
        ).where('scan_timestamp', '>', request.time - duration.value(24, 'h'));

        return recentScans.size();
      }
    }

    // ML training data - read-only for users
    match /ml_training_data/{scanId} {
      allow read: if request.auth != null;
      allow write: if false;  // Only backend can write
    }
  }
}
```

**Status:** ⚠️ RECOMMENDED (add server-side validation)

---

## 📊 Implementation Status Summary

| Feature | Status | File | Priority |
|---------|--------|------|----------|
| **Scan Limit Logic** | ✅ Complete | `scan_limit_service.dart` | - |
| **Processor Integration** | ✅ Complete | `frida_log_processor.dart` | - |
| **Dashboard Counter** | ⚠️ Recommended | `dashboard_screen.dart` | HIGH |
| **Export Disable** | ⚠️ Recommended | `scan_details_screen.dart` | HIGH |
| **Upgrade Prompts** | ⚠️ Recommended | `upgrade_prompt.dart` | MEDIUM |
| **Firestore Rules** | ⚠️ Recommended | `firestore.rules` | MEDIUM |
| **Error Messages** | ✅ Complete | `frida_log_processor.dart` | - |

---

## 🎯 Quick Implementation Checklist

For your FYP demo, I recommend implementing:

**Essential (30 minutes):**
- [x] Scan limit enforcement (DONE)
- [ ] Visual scan counter on dashboard
- [ ] Disable export buttons for free users

**Nice to Have (1 hour):**
- [ ] Upgrade prompts with pricing
- [ ] "Premium" badge on features
- [ ] Firestore security rules

**Already Working:**
- [x] 3 scans per 24h limit
- [x] Error messages when limit hit
- [x] Premium bypass logic
- [x] Firebase scan storage

---

## 🚀 Testing the Limitations

### Test Scenario 1: Free User Hitting Limit

```dart
// 1. Create free user account
final freeUser = UserModel(isPremium: false, ...);

// 2. Process 3 scans
for (int i = 0; i < 3; i++) {
  final result = await fridaLogProcessor.processAndUpload(
    userId: freeUser.uid,
    isPremium: false,
    ...
  );
  print('Scan ${i+1}: ${result.success}');  // true, true, true
}

// 3. Try 4th scan
final result4 = await fridaLogProcessor.processAndUpload(...);
print('Scan 4: ${result4.success}');  // false
print('Message: ${result4.message}'); // "Scan limit reached..."
```

**Expected Output:**
```
Scan 1: true
Scan 2: true
Scan 3: true
Scan 4: false
Message: Scan limit reached. 0/3 scans used. Reset in 24h
```

---

### Test Scenario 2: Premium User (No Limits)

```dart
final premiumUser = UserModel(isPremium: true, ...);

for (int i = 0; i < 10; i++) {
  final result = await fridaLogProcessor.processAndUpload(
    userId: premiumUser.uid,
    isPremium: true,
    ...
  );
  print('Scan ${i+1}: ${result.success}');  // All true!
}
```

---

## 💡 Best Practices

### 1. **User-Friendly Error Messages**

```dart
// ❌ Bad
"Error: Limit exceeded"

// ✅ Good
"You've used all 3 free scans today. Your limit resets in 8 hours, or upgrade to Premium for unlimited scans!"
```

### 2. **Clear Upgrade Path**

Always provide an upgrade button when showing limitations:
```dart
ElevatedButton.icon(
  onPressed: () => Navigator.pushNamed(context, '/pricing'),
  icon: Icon(Icons.upgrade),
  label: Text('Upgrade to Premium'),
)
```

### 3. **Progressive Disclosure**

Show limitations contextually:
- Dashboard: Show scan counter
- Scan screen: Check limit before processing
- Results screen: Disable export button
- Error dialog: Explain limit with upgrade option

---

## 📱 UI/UX Mockups

### Free User Dashboard
```
┌─────────────────────────────────┐
│  Scan Limit                     │
│  ●●●○○  2/3 scans remaining    │
│  Resets in 16 hours             │
│  [Upgrade to Premium →]         │
└─────────────────────────────────┘
```

### Limit Reached Dialog
```
┌─────────────────────────────────┐
│  🔒 Scan Limit Reached          │
│                                 │
│  You've used all 3 free scans   │
│  today. Your limit resets in    │
│  8 hours.                       │
│                                 │
│  Premium users get:             │
│  • Unlimited scans              │
│  • Export to PDF/CSV            │
│  • Priority support             │
│                                 │
│  [Upgrade - $4.99/mo]  [Close]  │
└─────────────────────────────────┘
```

---

## 🎯 Summary

**You already have the core limitation logic implemented!**

The `FridaLogProcessor` checks scan limits and returns appropriate errors. For a complete user experience, add:

1. ✅ **Visual scan counter** on dashboard
2. ✅ **Disabled export buttons** with tooltips
3. ✅ **Upgrade prompts** when limits hit

**Estimated time to complete:** 30-60 minutes

Perfect for demonstrating a production-ready freemium model in your FYP! 🎓🚀
