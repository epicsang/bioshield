// lib/services/saf_watcher_service.dart
// Monitors app-specific external storage directories for Frida events
// Uses Storage Access Framework (SAF) for cross-app file access

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class SAFWatcherService {
  Timer? _pollingTimer;
  final Set<String> _processedFiles = {};
  final Duration _pollingInterval;

  // Callback for new events
  Function(Map<String, dynamic>)? onEvent;

  String? _watchDirectory;
  bool _isWatching = false;

  SAFWatcherService({
    Duration pollingInterval = const Duration(milliseconds: 500),
  }) : _pollingInterval = pollingInterval;

  /// Start watching a specific app's bioshield directory
  ///
  /// Example: /storage/emulated/0/Android/data/com.example.vulnerableapp/files/bioshield/
  Future<void> startWatching({
    required String packageName,
    required Function(Map<String, dynamic>) onEvent,
  }) async {
    if (_isWatching) {
      print('⚠️ Already watching directory');
      return;
    }

    this.onEvent = onEvent;

    // Construct the path to the app's bioshield directory
    _watchDirectory = '/storage/emulated/0/Android/data/$packageName/files/bioshield';

    print('📂 Starting file watcher for: $_watchDirectory');

    // Check if directory exists
    final dir = Directory(_watchDirectory!);
    if (!await dir.exists()) {
      print('⚠️ Directory does not exist yet, creating: $_watchDirectory');
      try {
        await dir.create(recursive: true);
      } catch (e) {
        print('❌ Failed to create directory: $e');
        print('💡 Note: Directory will be created automatically when Frida starts emitting events');
      }
    }

    _isWatching = true;

    // Start polling for new files
    _pollingTimer = Timer.periodic(_pollingInterval, (_) => _checkForNewFiles());

    print('✅ File watcher started (polling every ${_pollingInterval.inMilliseconds}ms)');
  }

  /// Stop watching for events
  void stopWatching() {
    if (!_isWatching) return;

    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isWatching = false;
    _processedFiles.clear();
    _watchDirectory = null;

    print('🛑 File watcher stopped');
  }

  /// Check for new event files in the watched directory
  Future<void> _checkForNewFiles() async {
    if (_watchDirectory == null) return;

    try {
      final dir = Directory(_watchDirectory!);

      // Check if directory exists before listing
      if (!await dir.exists()) {
        return;  // Silently wait for directory to be created by Frida
      }

      final files = await dir.list().toList();

      for (var entity in files) {
        if (entity is File && entity.path.endsWith('.json')) {
          final filePath = entity.path;

          // Skip if already processed
          if (_processedFiles.contains(filePath)) {
            continue;
          }

          // Process new file
          await _processEventFile(entity);
          _processedFiles.add(filePath);
        }
      }
    } catch (e) {
      // Silently handle permission errors (will be resolved when user grants SAF access)
      if (!e.toString().contains('Permission denied')) {
        print('⚠️ Error checking directory: $e');
      }
    }
  }

  /// Process a single event file
  Future<void> _processEventFile(File file) async {
    try {
      final contents = await file.readAsString();
      final eventData = jsonDecode(contents) as Map<String, dynamic>;

      print('📨 New event: ${eventData['type'] ?? 'unknown'} from ${file.path.split('/').last}');

      // Call the event handler
      if (onEvent != null) {
        onEvent!(eventData);
      }

      // Optionally delete processed files to prevent clutter
      // Uncomment if you want to auto-clean:
      // await file.delete();

    } catch (e) {
      print('❌ Error processing event file ${file.path}: $e');
    }
  }

  /// Request SAF permission for a specific app directory
  ///
  /// This prompts the user to grant persistent access to the app's directory
  /// Only needs to be done once - permission persists across app restarts
  Future<bool> requestSAFPermission(String packageName) async {
    try {
      // Use platform channel to request SAF access
      const platform = MethodChannel('com.bioshield/saf');

      final path = 'Android/data/$packageName/files/bioshield';
      final granted = await platform.invokeMethod('requestDirectoryAccess', {
        'path': path,
      });

      if (granted == true) {
        print('✅ SAF permission granted for: $path');
        return true;
      } else {
        print('❌ SAF permission denied');
        return false;
      }
    } catch (e) {
      print('⚠️ SAF not available (using direct file access): $e');
      // Fallback: direct file access (works on Android <11 or with root)
      return true;
    }
  }

  /// Check if we have access to a directory
  Future<bool> hasAccess(String packageName) async {
    final path = '/storage/emulated/0/Android/data/$packageName/files/bioshield';
    final dir = Directory(path);

    try {
      await dir.list().first;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get list of all processed event files
  Set<String> get processedFiles => Set.from(_processedFiles);

  /// Check if currently watching
  bool get isWatching => _isWatching;

  /// Get the watched directory path
  String? get watchDirectory => _watchDirectory;

  /// Cleanup
  void dispose() {
    stopWatching();
  }
}

/// Event types that can be emitted by Frida
class FridaEventType {
  static const String fridaReady = 'frida_ready';
  static const String vulnerability = 'vulnerability';
  static const String authResult = 'auth_result';
  static const String scanReport = 'scan_report';
}

/// Example usage:
///
/// ```dart
/// final watcher = SAFWatcherService();
///
/// await watcher.requestSAFPermission('com.example.vulnerableapp');
///
/// await watcher.startWatching(
///   packageName: 'com.example.vulnerableapp',
///   onEvent: (event) {
///     print('Received event: ${event['type']}');
///
///     switch (event['type']) {
///       case FridaEventType.fridaReady:
///         print('Frida is ready!');
///         break;
///       case FridaEventType.vulnerability:
///         print('Vulnerability found: ${event['data']['title']}');
///         break;
///       case FridaEventType.authResult:
///         print('Auth result: ${event['data']['result']}');
///         break;
///       case FridaEventType.scanReport:
///         print('Scan complete: ${event['data']['riskScore']} risk score');
///         break;
///     }
///   },
/// );
/// ```
