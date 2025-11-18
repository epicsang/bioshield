# Frida Gadget → BioShield Data Flow Issue

## Problem Identified

There's a **mismatch in the IPC (Inter-Process Communication) mechanism**:

### Current Setup:

**Frida Gadget (agent.js):**
```javascript
// Writes to shared storage
var logDir = "/storage/emulated/0/BioShield/logs";
// Creates files: timing_2025-11-16T12-30-45.jsonl
```

**BioShield App:**
```dart
// Expects ContentProvider IPC
final logs = await _contentProviderService.readLogs(packageName);
// Looks for authority: com.fyp.vulnerable.hookprovider
```

### The Issue:
- ❌ Frida Gadget writes JSON files to `/storage/emulated/0/BioShield/logs/`
- ❌ BioShield tries to read via ContentProvider (which doesn't exist in Gadget mode)
- ❌ **No data flow between them!**

---

## Why This Happens

### Two Different Workflows:

#### Workflow 1: Native Java Hooks + ContentProvider (Original)
```
Vulnerable App
├─ HookEngine.java (injected)
├─ TimingTracker.java
├─ HookLogProvider (ContentProvider)
└─ Exposes data via content://authority/data
       ↓ (IPC)
BioShield reads via ContentProvider
```

#### Workflow 2: Frida Gadget + File Storage (Current)
```
Any App + Frida Gadget
├─ agent.js runs inside app
├─ Hooks biometric APIs
└─ Writes to /storage/emulated/0/BioShield/logs/*.jsonl
       ↓ (???)
BioShield tries ContentProvider (doesn't exist!)
```

---

## Solutions

### Option A: Make BioShield Read Files Directly (RECOMMENDED)

**Modify BioShield to detect Gadget mode and read from files:**

1. Add file-based reading service:
```dart
// lib/services/gadget_file_reader_service.dart
class GadgetFileReaderService {
  static const logDir = "/storage/emulated/0/BioShield/logs";

  Future<List<Map<String, dynamic>>> readLogs() async {
    final directory = Directory(logDir);
    if (!await directory.exists()) return [];

    final files = directory.listSync()
      .where((f) => f.path.endsWith('.jsonl'))
      .toList();

    List<Map<String, dynamic>> allLogs = [];
    for (var file in files) {
      final lines = await File(file.path).readAsLines();
      for (var line in lines) {
        allLogs.add(jsonDecode(line));
      }
    }
    return allLogs;
  }
}
```

2. Update `ComprehensiveScanService` to check for Gadget mode:
```dart
Future<List<Map<String, dynamic>>> readLogs(String packageName) async {
  // Try ContentProvider first (for native hooks)
  var logs = await _contentProviderService.readLogs(packageName);

  // If no logs, try file-based (for Frida Gadget)
  if (logs.isEmpty) {
    logs = await _gadgetFileReaderService.readLogs();
  }

  return logs;
}
```

**Pros:**
- ✅ Works with both native hooks AND Frida Gadget
- ✅ Backward compatible
- ✅ No changes to Frida agent needed
- ✅ BioShield auto-detects the mode

**Cons:**
- Requires file permissions (already have them)
- Slightly more complex logic

---

### Option B: Make Gadget Expose ContentProvider (Complex)

**Inject a ContentProvider into the hooked app:**

This would require:
1. Frida agent creates a ContentProvider dynamically
2. Registers it with the Android system
3. Exposes log data via content:// URI

**Pros:**
- No changes to BioShield needed

**Cons:**
- ❌ Very complex to implement
- ❌ Requires Frida to manipulate Android framework
- ❌ May not be possible with Gadget's security restrictions
- ❌ Not recommended

---

### Option C: Hybrid Approach

Use **SharedPreferences** or **Broadcast** for IPC:

```javascript
// agent.js
function writeLog(data) {
    // Write to file AND broadcast
    var Intent = Java.use("android.content.Intent");
    var intent = Intent.$new("com.fyp.bioshield.BIOMETRIC_EVENT");
    intent.putExtra("data", JSON.stringify(data));
    context.sendBroadcast(intent);
}
```

**Pros:**
- Real-time updates
- No file permissions needed

**Cons:**
- Requires BroadcastReceiver in BioShield
- Data might be lost if BioShield isn't running
- Needs both apps running simultaneously

---

## Recommended Implementation: Option A

### Step 1: Add File Reader Service

Create `lib/services/gadget_file_reader_service.dart`:

```dart
import 'dart:io';
import 'dart:convert';

class GadgetFileReaderService {
  static const String logDir = "/storage/emulated/0/BioShield/logs";

  Future<List<Map<String, dynamic>>> readAllLogs() async {
    try {
      final directory = Directory(logDir);
      if (!await directory.exists()) {
        print('[GadgetFileReader] Log directory not found');
        return [];
      }

      final files = directory.listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.jsonl'))
        .toList();

      print('[GadgetFileReader] Found ${files.length} log files');

      List<Map<String, dynamic>> allLogs = [];
      for (var file in files) {
        try {
          final lines = await file.readAsLines();
          for (var line in lines) {
            if (line.trim().isNotEmpty) {
              allLogs.add(jsonDecode(line));
            }
          }
        } catch (e) {
          print('[GadgetFileReader] Error reading file ${file.path}: $e');
        }
      }

      print('[GadgetFileReader] Read ${allLogs.length} total log events');
      return allLogs;
    } catch (e) {
      print('[GadgetFileReader] Error: $e');
      return [];
    }
  }

  Future<void> clearLogs() async {
    try {
      final directory = Directory(logDir);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
        await directory.create();
        print('[GadgetFileReader] Cleared all logs');
      }
    } catch (e) {
      print('[GadgetFileReader] Error clearing logs: $e');
    }
  }
}
```

### Step 2: Update ComprehensiveScanService

Modify the service to try both methods:

```dart
final _gadgetFileService = GadgetFileReaderService();

Future<List<Map<String, dynamic>>> _readLogsFlexible(String packageName) async {
  // Try ContentProvider first (native hooks)
  var logs = await _contentProviderService.readLogs(packageName);

  // If empty, try file-based (Frida Gadget)
  if (logs.isEmpty) {
    print('[Scan] ContentProvider empty, trying file-based...');
    logs = await _gadgetFileService.readAllLogs();
  }

  return logs;
}
```

---

## Current Permissions Status

### Already Configured: ✅

**AndroidManifest.xml:**
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"/>
```

**Frida agent.js:**
```javascript
var logDir = "/storage/emulated/0/BioShield/logs";
ensureDir(logDir); // Creates directory
writeLog(data);    // Writes JSONL files
```

### What's Missing:
BioShield code to **read** from `/storage/emulated/0/BioShield/logs/`

---

## Testing Plan

### After implementing file reader:

1. **Install Frida Gadget APK:**
   ```bash
   adb install app-debug_frida.apk
   ```

2. **Run the app and trigger biometric auth**

3. **Check logs are created:**
   ```bash
   adb shell ls -la /storage/emulated/0/BioShield/logs/
   ```

4. **Open BioShield and scan**
   - Should now read the JSONL files
   - Display timing data

5. **Verify in logs:**
   ```bash
   adb shell cat /storage/emulated/0/BioShield/logs/timing_*.jsonl
   ```

---

## Next Steps

1. ✅ Permissions already configured
2. ⏳ Implement `GadgetFileReaderService`
3. ⏳ Update `ComprehensiveScanService` to use hybrid approach
4. ⏳ Test with Frida Gadget APK
5. ⏳ Verify data flows correctly

---

## Summary

**Problem:** Frida Gadget writes files, BioShield expects ContentProvider
**Solution:** Add file reading capability to BioShield (fallback mechanism)
**Status:** Permissions ✅ | Implementation ⏳
