# BioShield Complete Setup & Testing Guide

## Architecture Summary

```
┌─────────────────────────────────────┐
│   Vulnerable App (Hooked)          │
│  ┌──────────────────────────────┐  │
│  │ HookEngine                    │  │ Intercepts biometric callbacks
│  │ ├─ onAuthenticationSuccess   │  │
│  │ ├─ onAuthenticationError     │  │
│  │ └─ onAuthenticationFailed    │  │
│  └──────────────────────────────┘  │
│            ↓                        │
│  ┌──────────────────────────────┐  │
│  │ TimingTracker                │  │ Records 12 ML features
│  │ └─ bioshield_hooks.jsonl     │  │ Writes to local file
│  └──────────────────────────────┘  │
│            ↓                        │
│  ┌──────────────────────────────┐  │
│  │ HookLogProvider              │  │ Exposes via ContentProvider
│  │ Authority: {pkg}.hookprovider│  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
            ↓ IPC
┌─────────────────────────────────────┐
│   BioShield App                     │
│  ┌──────────────────────────────┐  │
│  │ ContentProviderReader        │  │ Reads logs via IPC
│  └──────────────────────────────┘  │
│            ↓                        │
│  ┌──────────────────────────────┐  │
│  │ ComprehensiveScanService     │  │ Orchestrates workflow
│  │ 1. Read logs via IPC         │  │
│  │ 2. Generate scan report      │  │
│  │ 3. Upload to Firebase        │  │ ← BioShield uploads!
│  │ 4. Clear local logs          │  │
│  └──────────────────────────────┘  │
│            ↓                        │
│  ┌──────────────────────────────┐  │
│  │ Firebase (Firestore)         │  │
│  │ bioshield_logs/{uid}/{pkg}/  │  │ Stores logs
│  │ scan_reports/{uid}/{pkg}/    │  │ Stores reports
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
```

## ✅ Implementation Status

### Completed Components

#### 1. BioShield App (Flutter + Kotlin)

**Flutter Services:**
- ✅ [HookContentProviderService](lib/services/hook_contentprovider_service.dart) - IPC reader
- ✅ [FirebaseLogUploadService](lib/services/firebase_log_upload_service.dart) - Firebase uploader
- ✅ [ComprehensiveScanService](lib/services/comprehensive_scan_service.dart) - Workflow orchestrator

**Kotlin Platform Code:**
- ✅ [ContentProviderReader.kt](android/app/src/main/kotlin/com/fyp/bioshield/bioshield/ContentProviderReader.kt) - IPC reader
- ✅ [ContentProviderChannel.kt](android/app/src/main/kotlin/com/fyp/bioshield/bioshield/ContentProviderChannel.kt) - MethodChannel handler
- ✅ [MainActivity.kt](android/app/src/main/kotlin/com/fyp/bioshield/bioshield/MainActivity.kt) - Registered ContentProvider channel

#### 2. Hook Framework (Java)

**In REPACK/hooks/:**
- ✅ HookEngine.java - Biometric event interceptor
- ✅ TimingTracker.java - JSONL writer with 12 ML features
- ✅ HookLogProvider.java - ContentProvider for IPC
- ✅ LogStore.java - General log storage
- ✅ HookManager.java - Hook coordinator
- ✅ BiometricProxy.java - Proxy wrapper
- ✅ AppContextProvider.java - Context helper

#### 3. Repackaging Scripts

- ✅ [repackage_contentprovider.py](scripts/repackage_contentprovider.py) - Injects hooks

## 📋 Setup Instructions

### Step 1: Build BioShield App

```bash
cd c:/Users/User/Desktop/School/FYP/BioShield

# Get dependencies
flutter pub get

# Build APK
flutter build apk --release

# Install on device
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Step 2: Repackage Vulnerable App

**Option A: Using Python Script (Recommended)**

```bash
cd scripts

# Repackage target APK
python repackage_contentprovider.py <path/to/vulnerable.apk>

# Output will be in: scripts/output/<apk_name>/output/<apk_name>_hooked.apk
```

**Option B: Manual Integration**

See [CONTENTPROVIDER_IPC_GUIDE.md](CONTENTPROVIDER_IPC_GUIDE.md) for manual integration steps.

**Important:** The repackaging script includes hook source files in `assets/bioshield_hooks/`. You need to either:
1. Manually compile and integrate them into the APK
2. Use a pre-built hook framework DEX file
3. Follow the build instructions in `assets/bioshield_hooks/BUILD_INSTRUCTIONS.txt`

### Step 3: Sign Both Apps with Same Certificate

**CRITICAL:** For ContentProvider signature-level permissions to work, both apps must be signed with the **same certificate**.

```bash
# Generate a keystore (do this once)
keytool -genkey \
  -v -keystore bioshield.keystore \
  -alias bioshield \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000

# Sign BioShield app
jarsigner -verbose \
  -sigalg SHA256withRSA \
  -digestalg SHA-256 \
  -keystore bioshield.keystore \
  build/app/outputs/flutter-apk/app-release.apk \
  bioshield

# Sign hooked vulnerable app
jarsigner -verbose \
  -sigalg SHA256withRSA \
  -digestalg SHA-256 \
  -keystore bioshield.keystore \
  scripts/output/vulnerable/output/vulnerable_hooked.apk \
  bioshield

# Zipalign both
zipalign -v -f 4 app-release.apk app-release-aligned.apk
zipalign -v -f 4 vulnerable_hooked.apk vulnerable_hooked-aligned.apk
```

### Step 4: Install Both Apps

```bash
# Install BioShield
adb install -r app-release-aligned.apk

# Install hooked vulnerable app
adb install -r vulnerable_hooked-aligned.apk
```

## 🧪 Testing Workflow

### Test 1: Verify Hook Framework Installation

```bash
# Check if HookLogProvider is registered
adb shell dumpsys package com.example.vulnerable.app | grep -i "provider"

# Should show: com.example.vulnerable.app.hookprovider
```

### Test 2: Trigger Biometric Authentication

1. Open the hooked vulnerable app
2. Trigger a biometric authentication prompt
3. Complete authentication (success or failure)
4. Repeat 3-5 times to generate multiple events

### Test 3: Read Logs via ContentProvider

**From Dart (in BioShield app):**

```dart
import 'package:bioshield/services/comprehensive_scan_service.dart';

final scanService = ComprehensiveScanService();

// Perform complete scan (reads logs, uploads to Firebase, generates report)
final result = await scanService.performCompleteScan('com.example.vulnerable.app');

if (result.success) {
  final report = result.report!;

  print('✓ Scan successful!');
  print('  Risk Level: ${report.riskLevel.emoji} ${report.riskLevel.displayName}');
  print('  Auth Events: ${report.authEventCount}');
  print('  Success Rate: ${report.successRate.toStringAsFixed(1)}%');
  print('  Logs Count: ${result.logsCount}');
  print('  Uploaded to Firebase: ${result.uploadedToFirebase}');

  if (report.hasAnomalies) {
    print('  ⚠ Anomalies detected:');
    for (var anomaly in report.anomalyReport!.anomalies) {
      print('    - $anomaly');
    }
  }
} else {
  print('✗ Scan failed: ${result.error}');
}
```

**From Kotlin (testing only):**

```kotlin
import com.fyp.bioshield.bioshield.ContentProviderReader

val authority = "com.example.vulnerable.app.hookprovider"
val logs = ContentProviderReader.readLogs(context, authority)

Log.d("Test", "Read logs: $logs")
```

### Test 4: Verify Firebase Upload

```bash
# Check Firestore console
# Navigate to: bioshield_logs/{userId}/{packageName}/

# Or query via Firebase Admin SDK
```

### Test 5: View Scan Reports

```dart
// Get latest report
final latestReport = await scanService.getLatestScanReport('com.example.vulnerable.app');
print('Latest report: $latestReport');

// Get scan history
final history = await scanService.getScanHistory('com.example.vulnerable.app', limit: 5);
print('Found ${history.length} previous scans');
```

## 🔧 Troubleshooting

### Issue 1: "Permission denied" when reading ContentProvider

**Cause:** Apps not signed with same certificate

**Solution:**
```bash
# Verify signatures match
jarsigner -verify -verbose -certs app1.apk | grep "SHA-256"
jarsigner -verify -verbose -certs app2.apk | grep "SHA-256"

# Should output identical SHA-256 hashes
```

### Issue 2: "ContentProvider not found"

**Cause:** HookLogProvider not registered in manifest

**Solution:**
```bash
# Decompile APK and check manifest
apktool d vulnerable_hooked.apk -o temp
cat temp/AndroidManifest.xml | grep -i "provider"

# Should contain:
# <provider android:name="com.example.vulnerable.app.bioshield.HookLogProvider"
#           android:authorities="com.example.vulnerable.app.hookprovider"
#           android:exported="true" />
```

### Issue 3: "No logs found"

**Cause:** Hook framework not triggered or not writing logs

**Solutions:**
1. Check if biometric auth was triggered in hooked app
2. Verify TimingTracker is writing to file:
```bash
adb shell run-as com.example.vulnerable.app ls files/
# Should show: bioshield_hooks.jsonl

adb shell run-as com.example.vulnerable.app cat files/bioshield_hooks.jsonl
# Should show JSON log events
```

### Issue 4: "Firebase upload failed"

**Cause:** Firebase not configured or network issues

**Solutions:**
1. Check `google-services.json` is present
2. Verify Firebase project is configured
3. Check internet connection
4. Review Firestore security rules

### Issue 5: Black screen after scan

**Cause:** UI thread blocking during ContentProvider read

**Solution:** Already handled - we use async reading. If still occurs:
```dart
// Use quick scan without Firebase upload
final result = await scanService.performQuickScan('com.example.vulnerable.app');
```

## 📊 Data Flow Example

### Complete Workflow

```
1. User triggers biometric auth in hooked app
   ↓
2. HookEngine intercepts callback
   ↓
3. TimingTracker writes to bioshield_hooks.jsonl:
   {
     "eventType": "auth_success",
     "timestamp": 1700000000000,
     "auth_start_ms": 1700000000000,
     "sensor_acquire_ms": 1700000000050,
     "detection_ms": 1700000000250,
     "success_failure_ms": 1700000000300,
     "retry_count": 0,
     "failure_reason": 0,
     "cpu_load": 0.45,
     "thermal_state": 0,
     "screen_state": 1,
     "entropy": 0.75,
     "hasCrypto": 1,
     "networkFlag": 0,
     "anomalies": []
   }
   ↓
4. User opens BioShield app and clicks "Scan"
   ↓
5. BioShield calls ComprehensiveScanService.performCompleteScan()
   ↓
6. ContentProviderReader reads from HookLogProvider
   ↓
7. BioShield generates scan report locally
   ↓
8. BioShield uploads logs to Firebase:
   bioshield_logs/{userId}/com.example.vulnerable.app/{eventId}
   ↓
9. BioShield uploads report to Firebase:
   scan_reports/{userId}/com.example.vulnerable.app/{reportId}
   ↓
10. BioShield displays results in UI
```

### JSONL Event Format

Each line in `bioshield_hooks.jsonl`:

```json
{
  "eventType": "auth_success",
  "eventCode": 0,
  "timestamp": 1700000000000,
  "duration": 300,
  "sessionId": "session_1700000000000_123",
  "auth_start_ms": 1700000000000,
  "sensor_acquire_ms": 1700000000050,
  "detection_ms": 1700000000250,
  "success_failure_ms": 1700000000300,
  "sensor_latency": 50,
  "detection_latency": 200,
  "completion_latency": 50,
  "total_duration": 300,
  "retry_count": 0,
  "failure_reason": 0,
  "cpu_load": 0.45,
  "thermal_state": 0,
  "screen_state": 1,
  "entropy": 0.75,
  "hasCrypto": 1,
  "networkFlag": 0,
  "anomalies": [],
  "hasAnomalies": false
}
```

## 🚀 Usage Example (Full App Integration)

```dart
import 'package:flutter/material.dart';
import 'package:bioshield/services/comprehensive_scan_service.dart';

class ScanScreen extends StatefulWidget {
  final String packageName;

  const ScanScreen({required this.packageName});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _scanService = ComprehensiveScanService();
  bool _isScanning = false;
  ScanResult? _result;

  Future<void> _performScan() async {
    setState(() {
      _isScanning = true;
      _result = null;
    });

    try {
      final result = await _scanService.performCompleteScan(
        widget.packageName,
        uploadToFirebase: true,
      );

      setState(() {
        _result = result;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan ${widget.packageName}')),
      body: Center(
        child: _isScanning
            ? CircularProgressIndicator()
            : _result != null
                ? _buildResults()
                : ElevatedButton(
                    onPressed: _performScan,
                    child: Text('Start Scan'),
                  ),
      ),
    );
  }

  Widget _buildResults() {
    if (!_result!.success) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text('Scan Failed', style: TextStyle(fontSize: 24)),
          SizedBox(height: 8),
          Text(_result!.error ?? 'Unknown error'),
        ],
      );
    }

    final report = _result!.report!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(report.riskLevel.emoji, style: TextStyle(fontSize: 64)),
        SizedBox(height: 16),
        Text(
          report.riskLevel.displayName,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 32),
        _buildStatRow('Auth Events', '${report.authEventCount}'),
        _buildStatRow('Success Rate', '${report.successRate.toStringAsFixed(1)}%'),
        _buildStatRow('Logs Analyzed', '${_result!.logsCount}'),
        _buildStatRow('Uploaded', _result!.uploadedToFirebase ? 'Yes' : 'No'),

        if (report.hasAnomalies) ...[
          SizedBox(height: 32),
          Text('⚠ Anomalies Detected:', style: TextStyle(fontSize: 18)),
          ...report.anomalyReport!.anomalies.map((a) => Text('  • $a')),
        ],
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 18)),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
```

## 📝 Key Files Reference

### Documentation
- [CONTENTPROVIDER_IPC_GUIDE.md](CONTENTPROVIDER_IPC_GUIDE.md) - IPC implementation details
- [COMPLETE_SETUP_GUIDE.md](COMPLETE_SETUP_GUIDE.md) - This file

### BioShield Services
- [lib/services/hook_contentprovider_service.dart](lib/services/hook_contentprovider_service.dart)
- [lib/services/firebase_log_upload_service.dart](lib/services/firebase_log_upload_service.dart)
- [lib/services/comprehensive_scan_service.dart](lib/services/comprehensive_scan_service.dart)

### Hook Framework
- [REPACK/hooks/](REPACK/hooks/) - All hook framework files

### Repackaging
- [scripts/repackage_contentprovider.py](scripts/repackage_contentprovider.py)

## ✅ Checklist

- [ ] BioShield app built and installed
- [ ] Vulnerable app repackaged with hooks
- [ ] Both apps signed with same certificate
- [ ] Both apps installed on device
- [ ] Firebase configured with google-services.json
- [ ] Biometric auth triggered in hooked app
- [ ] Scan performed in BioShield app
- [ ] Logs uploaded to Firebase
- [ ] Scan report visible in UI

## 🎯 Next Steps

1. **Build Production Signing** - Create production keystore for release
2. **ML Integration** - Use 12-feature events for ML model training
3. **UI Screens** - Add scan results, history, and analytics screens
4. **Error Handling** - Add retry logic and better error messages
5. **Performance** - Optimize large log file reading
6. **Security** - Review and harden ContentProvider permissions

---

**Note:** This implementation ensures that **ONLY BioShield uploads to Firebase**. The hooked app writes logs locally, and BioShield reads via IPC and uploads. This centralizes data collection and ensures user privacy.
