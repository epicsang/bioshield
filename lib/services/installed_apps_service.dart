import 'package:flutter/services.dart';

/// Service to get list of installed apps on the device
class InstalledAppsService {
  static const MethodChannel _channel = MethodChannel('com.fyp.bioshield/installed_apps');

  /// Get list of all installed apps (package names and labels)
  Future<List<Map<String, String>>> getInstalledApps() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getInstalledApps');
      return result.map((app) => Map<String, String>.from(app)).toList();
    } catch (e) {
      print('Error getting installed apps: $e');
      return [];
    }
  }

  /// Get app label (name) for a specific package
  Future<String?> getAppLabel(String packageName) async {
    try {
      return await _channel.invokeMethod('getAppLabel', {'packageName': packageName});
    } catch (e) {
      print('Error getting app label: $e');
      return null;
    }
  }
}
