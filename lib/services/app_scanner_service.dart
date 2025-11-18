// lib/services/app_scanner_service.dart
// Stub file - Frida functionality removed

import 'dart:async';

class AppScannerService {
  Future<void> checkStatus() async {
    throw UnsupportedError('Frida not available');
  }

  Future<List<Map<String, dynamic>>> getAvailableApps() async {
    return [];
  }

  Future<dynamic> scanApp({
    required String packageName,
    required Duration timeout,
  }) async {
    throw UnsupportedError('Frida not available');
  }

  Future<String> getSetupInstructions() async {
    return 'Frida functionality removed';
  }

  void dispose() {}
}
