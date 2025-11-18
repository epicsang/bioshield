import 'dart:async';
import 'package:flutter/services.dart';

class NativeSurfaceHelper {
  static const MethodChannel _channel = MethodChannel('bioshield_surface');

  /// Returns true if the native surface is currently valid (attached & drawable)
  static Future<bool> surfaceAlive() async {
    try {
      final res = await _channel.invokeMethod('surfaceAlive');
      if (res is bool) return res;
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Ask native side to request battery exemption
  static Future<bool> requestBatteryExemption() async {
    try {
      final res = await _channel.invokeMethod('requestBatteryExemption');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  /// Pixel 6 (Android 13) - No delay required, execute immediately
  static Future<void> safeRedraw(Function action) async {
    action();
  }

  /// Safe rebuild with mounted check for StatefulWidget contexts
  /// Pixel 6 (Android 13) - No delay required
  static Future<void> safeRebuild(
    FutureOr<void> Function() action, {
    bool Function()? isMounted,
  }) async {
    // Check if widget is still mounted before calling action
    if (isMounted != null && !isMounted()) {
      return;
    }

    await action();
  }
}
