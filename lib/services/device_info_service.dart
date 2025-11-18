import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Get current device information
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'manufacturer': androidInfo.manufacturer,
          'model': androidInfo.model,
          'device': androidInfo.device,
          'androidVersion': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'brand': androidInfo.brand,
          'fingerprint': androidInfo.fingerprint,
          'hardware': androidInfo.hardware,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'model': iosInfo.model,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'name': iosInfo.name,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
        };
      } else {
        return {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
        };
      }
    } catch (e) {
      print('Error getting device info: $e');
      return {
        'manufacturer': 'Unknown',
        'model': 'Unknown',
        'device': 'Unknown',
        'androidVersion': 'Unknown',
        'sdkInt': 0,
        'brand': 'Unknown',
      };
    }
  }

  /// Get a formatted device string (e.g., "Samsung Galaxy S21")
  static Future<String> getDeviceString() async {
    final info = await getDeviceInfo();
    if (Platform.isAndroid) {
      final brand = info['brand'] ?? 'Unknown';
      final model = info['model'] ?? 'Unknown';
      return '$brand $model';
    }
    return info['model'] ?? 'Unknown Device';
  }

  /// Get Android version string
  static Future<String> getAndroidVersion() async {
    final info = await getDeviceInfo();
    final version = info['androidVersion'] ?? 'Unknown';
    final sdk = info['sdkInt'] ?? 0;
    return 'Android $version (API $sdk)';
  }
}
