// lib/services/android_repackager_service.dart
// DEPRECATED: This service is no longer used
// BioShield now uses laptop-based Frida injection with Pixel 6 (Android 13)
// Frida runs on laptop via USB and injects into vulnerable apps dynamically

import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Result from APK repackaging
class AndroidRepackageResult {
  final bool success;
  final String? repackagedApkPath;
  final String? error;
  final List<String> logs;

  AndroidRepackageResult({
    required this.success,
    this.repackagedApkPath,
    this.error,
    this.logs = const [],
  });

  factory AndroidRepackageResult.success(String apkPath, List<String> logs) {
    return AndroidRepackageResult(
      success: true,
      repackagedApkPath: apkPath,
      logs: logs,
    );
  }

  factory AndroidRepackageResult.error(String message, List<String> logs) {
    return AndroidRepackageResult(
      success: false,
      error: message,
      logs: logs,
    );
  }
}

/// Android Native Repackager Service
/// Repackages APKs directly on the Android device without needing a laptop
class AndroidRepackagerService {
  static const platform = MethodChannel('com.fyp.bioshield/repackager');
  final List<String> _logs = [];

  /// Check if device can perform repackaging
  Future<bool> isRepackagingSupported() async {
    try {
      // Check if running on Android
      final bool? supported = await platform.invokeMethod('isSupported');
      if (supported != true) return false;

      // Check if Frida Gadget asset exists
      try {
        await rootBundle.load('assets/frida-gadget-android-arm64.so');
      } catch (e) {
        print('Frida Gadget not found. Please add to assets/ folder.');
        return false;
      }

      // Check if scan script exists
      try {
        await rootBundle.load('assets/biometricPrompt.js');
      } catch (e) {
        print('biometricPrompt.js not found. Please add to assets/ folder.');
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Repackage APK with Frida Gadget on device
  Future<AndroidRepackageResult> repackageApk({
    required String apkPath,
    required Function(String) onLog,
  }) async {
    _logs.clear();
    _addLog('🔧 Starting on-device APK repackaging...', onLog);

    try {
      // 1. Verify APK exists
      final apkFile = File(apkPath);
      if (!await apkFile.exists()) {
        return AndroidRepackageResult.error('APK file not found: $apkPath', _logs);
      }

      _addLog('📦 APK: ${apkFile.path.split('/').last}', onLog);

      // 2. Get Frida Gadget from assets
      _addLog('📥 Loading Frida Gadget...', onLog);
      final gadgetData = await rootBundle.load('assets/frida-gadget-android-arm64.so');

      // 3. Get biometricPrompt.js script
      _addLog('📜 Loading scan script...', onLog);
      final scriptData = await rootBundle.load('assets/biometricPrompt.js');

      // 4. Get output directory
      final outputDir = await getExternalStorageDirectory();
      final workDir = Directory('${outputDir!.path}/bioshield_repackage');

      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
      await workDir.create(recursive: true);

      _addLog('📂 Work directory: ${workDir.path}', onLog);

      // 5. Copy files to work directory
      final gadgetFile = File('${workDir.path}/frida-gadget.so');
      await gadgetFile.writeAsBytes(gadgetData.buffer.asUint8List());

      final scriptFile = File('${workDir.path}/biometricPrompt.js');
      await scriptFile.writeAsBytes(scriptData.buffer.asUint8List());

      final apkCopy = File('${workDir.path}/target.apk');
      await apkFile.copy(apkCopy.path);

      _addLog('✅ Files prepared', onLog);

      // 6. Call native Android method to repackage
      _addLog('🚀 Starting native repackaging...', onLog);

      final result = await platform.invokeMethod('repackageApk', {
        'apkPath': apkCopy.path,
        'gadgetPath': gadgetFile.path,
        'scriptPath': scriptFile.path,
        'outputDir': workDir.path,
      });

      final Map<String, dynamic> resultMap = Map<String, dynamic>.from(result as Map);

      if (resultMap['success'] == true) {
        final outputApk = resultMap['outputPath'] as String;
        _addLog('✅ Repackaging complete!', onLog);
        _addLog('📦 Output: $outputApk', onLog);

        // Add installation instructions
        _addLog('', onLog);
        _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', onLog);
        _addLog('✅ SUCCESS! APK Repackaged', onLog);
        _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', onLog);
        _addLog('', onLog);
        _addLog('📦 APK saved to: /sdcard/Download/', onLog);
        _addLog('', onLog);
        _addLog('⚠️  INSTALLATION REQUIRES ADB', onLog);
        _addLog('   On-device signing not available on Android', onLog);
        _addLog('', onLog);
        _addLog('📋 Installation Steps:', onLog);
        _addLog('', onLog);
        _addLog('1️⃣  CONNECT TO COMPUTER', onLog);
        _addLog('   • Connect phone via USB', onLog);
        _addLog('   • Enable USB debugging', onLog);
        _addLog('', onLog);
        _addLog('2️⃣  UNINSTALL ORIGINAL APP', onLog);
        _addLog('   • adb uninstall <package.name>', onLog);
        _addLog('   • Or manually from Settings > Apps', onLog);
        _addLog('', onLog);
        _addLog('3️⃣  INSTALL VIA ADB', onLog);
        _addLog('   • adb install /sdcard/Download/BioShield_*.apk', onLog);
        _addLog('   • ADB bypasses signature checks', onLog);
        _addLog('', onLog);
        _addLog('4️⃣  TEST BIOMETRIC HOOKS', onLog);
        _addLog('   • Open repackaged app', onLog);
        _addLog('   • Authenticate with fingerprint', onLog);
        _addLog('   • Frida runs automatically!', onLog);
        _addLog('', onLog);
        _addLog('💡 See REPACKAGE_TROUBLESHOOTING.md for signing help', onLog);

        return AndroidRepackageResult.success(outputApk, _logs);
      } else {
        final error = resultMap['error'] as String?;
        _addLog('❌ Repackaging failed: $error', onLog);
        return AndroidRepackageResult.error(error ?? 'Unknown error', _logs);
      }

    } on PlatformException catch (e) {
      _addLog('❌ Platform error: ${e.message}', onLog);
      return AndroidRepackageResult.error(e.message ?? 'Platform error', _logs);
    } catch (e) {
      _addLog('❌ Error: $e', onLog);
      return AndroidRepackageResult.error(e.toString(), _logs);
    }
  }

  /// Get installed apps that can be extracted and repackaged
  Future<List<Map<String, String>>> getInstalledApps() async {
    try {
      final List<dynamic>? apps = await platform.invokeMethod('getInstalledApps');

      if (apps == null) return [];

      return apps.map((app) => {
        'packageName': app['packageName'] as String,
        'appName': app['appName'] as String,
        'icon': app['icon'] as String?,
      }).cast<Map<String, String>>().toList();

    } catch (e) {
      print('Error getting installed apps: $e');
      return [];
    }
  }

  /// Extract APK from installed app
  Future<String?> extractApk({
    required String packageName,
    required Function(String) onLog,
  }) async {
    try {
      _addLog('📤 Extracting APK for $packageName...', onLog);

      final String? apkPath = await platform.invokeMethod('extractApk', {
        'packageName': packageName,
      });

      if (apkPath != null) {
        _addLog('✅ APK extracted: $apkPath', onLog);
        return apkPath;
      } else {
        _addLog('❌ Failed to extract APK', onLog);
        return null;
      }
    } catch (e) {
      _addLog('❌ Extraction error: $e', onLog);
      return null;
    }
  }

  /// Install repackaged APK
  Future<bool> installApk(String apkPath) async {
    try {
      final bool? installed = await platform.invokeMethod('installApk', {
        'apkPath': apkPath,
      });
      return installed ?? false;
    } catch (e) {
      print('Error installing APK: $e');
      return false;
    }
  }

  /// Get setup instructions
  String getSetupInstructions() {
    return '''
BioShield On-Device APK Repackaging

✅ NO LAPTOP REQUIRED!
✅ Everything runs on your Android device

How it works:
1. Select an installed app OR pick an APK file
2. BioShield extracts and repackages it automatically
3. Install the repackaged version
4. Frida Gadget runs automatically!

Requirements:
- Android 8.0+ (API 26+)
- Storage permission for APK files
- Install permission for repackaged apps

Workflow:
1. Tap "Select Installed App" or "Choose APK File"
2. Wait for repackaging (1-3 minutes)
3. Tap "Install" when complete
4. Open app and test biometric login
5. Check scan results in BioShield

Benefits:
✅ Fully mobile - no computer needed
✅ Perfect for demos and presentations
✅ Quick iteration - test multiple apps
✅ Works anywhere, anytime

Note: Some apps with strong anti-tampering
may not work when repackaged.
''';
  }

  /// Add log entry
  void _addLog(String message, Function(String) onLog) {
    final timestamp = DateTime.now().toString().split('.')[0];
    final logEntry = '[$timestamp] $message';
    _logs.add(logEntry);
    onLog(logEntry);
    print(message);
  }

  /// Get logs
  List<String> get logs => List.unmodifiable(_logs);
}
