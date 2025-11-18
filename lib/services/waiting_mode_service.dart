import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to manage waiting mode workflow for biometric scanning
///
/// Workflow:
/// 1. BioShield enters waiting mode (waits for AUTH_DONE broadcast)
/// 2. User manually opens vulnerable app and performs authentication
/// 3. Frida hooks send AUTH_DONE broadcast to BioShield
/// 4. BioShield reads timing.jsonl via run-as command
/// 5. BioShield uploads to Firebase
/// 6. BioShield sends DELETE_LOG broadcast to Frida
/// 7. Frida deletes timing.jsonl
/// 8. BioShield increments scan counter and exits waiting mode
class WaitingModeService {
  static const MethodChannel _authChannel =
      MethodChannel('com.fyp.bioshield/auth_done');
  static const MethodChannel _sharedStorageChannel =
      MethodChannel('bioshield/shared_storage');

  bool _isWaiting = false;
  String? _targetPackage;
  Function(String packageName, List<Map<String, dynamic>> logs)? _onAuthDone;
  Function(String error)? _onError;

  /// Start waiting mode for a specific package
  ///
  /// [packageName] - The package name of the app to monitor
  /// [onAuthDone] - Callback when authentication is done and logs are uploaded
  /// [onError] - Callback when an error occurs
  Future<void> startWaiting({
    required String packageName,
    required Function(String packageName, List<Map<String, dynamic>> logs) onAuthDone,
    Function(String error)? onError,
  }) async {
    // If already waiting, stop the previous scan first
    if (_isWaiting) {
      print('[WaitingModeService] Stopping previous waiting mode before starting new one');
      stopWaiting();
    }

    _isWaiting = true;
    _targetPackage = packageName;
    _onAuthDone = onAuthDone;
    _onError = onError;

    print('[WaitingModeService] Entering waiting mode for: $packageName');

    // Register listener for AUTH_DONE broadcast from Frida
    _authChannel.setMethodCallHandler(_handleMethodCall);
  }

  /// Stop waiting mode
  void stopWaiting() {
    print('[WaitingModeService] Exiting waiting mode');
    _isWaiting = false;
    _targetPackage = null;
    _onAuthDone = null;
    _onError = null;
    _authChannel.setMethodCallHandler(null);
  }

  /// Handle method calls from MainActivity (AUTH_DONE broadcast)
  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onAuthDone' && _isWaiting) {
      print('[WaitingModeService] Received AUTH_DONE signal from Frida');
      await _handleAuthDone();
    }
  }

  /// Handle AUTH_DONE signal: read logs, upload, delete, exit
  Future<void> _handleAuthDone() async {
    if (!_isWaiting || _targetPackage == null) {
      print('[WaitingModeService] Not in waiting mode, ignoring AUTH_DONE');
      return;
    }

    final packageName = _targetPackage!;

    try {
      print('[WaitingModeService] Processing AUTH_DONE for: $packageName');

      // Step 1: Read timing.jsonl via run-as command
      final logs = await _readTimingFile(packageName);

      if (logs.isEmpty) {
        throw Exception('No timing data found in timing.jsonl');
      }

      print('[WaitingModeService] Read ${logs.length} timing events');

      // Step 2: Upload to Firebase
      await _uploadToFirebase(packageName, logs);

      print('[WaitingModeService] Successfully uploaded logs to Firebase');

      // Step 3: Send DELETE_LOG broadcast to Frida
      await _sendDeleteCommand();

      print('[WaitingModeService] DELETE_LOG broadcast sent');

      // Step 4: Increment scan counter
      await _incrementScanCount();

      print('[WaitingModeService] Scan counter incremented');

      // Step 5: Exit waiting mode and notify caller
      _onAuthDone?.call(packageName, logs);
      stopWaiting();
    } catch (e) {
      print('[WaitingModeService] Error handling AUTH_DONE: $e');
      _onError?.call(e.toString());
      stopWaiting();
    }
  }

  /// Read timing.jsonl from shared storage
  Future<List<Map<String, dynamic>>> _readTimingFile(String packageName) async {
    try {
      print('[WaitingModeService] Reading timing.jsonl from shared storage for: $packageName');

      // Use platform channel to read from shared storage
      final result = await _sharedStorageChannel.invokeMethod('readSharedTimingFile', {
        'packageName': packageName,
      });

      if (result == null || result.toString().isEmpty) {
        print('[WaitingModeService] No timing data returned');
        return [];
      }

      // Parse JSONL (one JSON object per line)
      final lines = result.toString().split('\n');
      final logs = <Map<String, dynamic>>[];

      for (var line in lines) {
        if (line.trim().isEmpty) continue;

        try {
          final json = jsonDecode(line);
          if (json is Map<String, dynamic>) {
            logs.add(json);
          }
        } catch (e) {
          print('[WaitingModeService] Failed to parse line: $line');
        }
      }

      print('[WaitingModeService] Parsed ${logs.length} timing events');
      return logs;
    } catch (e) {
      print('[WaitingModeService] Error reading timing file: $e');
      rethrow;
    }
  }

  /// Upload timing logs to Firebase
  Future<void> _uploadToFirebase(
    String packageName,
    List<Map<String, dynamic>> logs,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('[WaitingModeService] Uploading ${logs.length} logs to Firebase');

      // Create scan document
      final scanDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('scans')
          .doc();

      // Calculate statistics
      int successCount = 0;
      int failCount = 0;
      int errorCount = 0;

      for (var log in logs) {
        final event = log['event'] as String?;
        if (event == 'success') successCount++;
        if (event == 'fail') failCount++;
        if (event == 'error') errorCount++;
      }

      // Calculate risk score based on fail/error ratio
      final totalEvents = logs.length;
      final internalRiskScore = totalEvents > 0
          ? ((failCount + errorCount) / totalEvents * 100).clamp(0, 100).toDouble()
          : 0.0;

      // Invert for UI: internal risk (0=secure, 100=risky) -> security score (0=risky, 100=secure)
      final securityScore = 100 - internalRiskScore;

      // Generate result summary
      String resultSummary;
      if (internalRiskScore >= 70) {
        resultSummary = 'Critical: High failure rate detected';
      } else if (internalRiskScore >= 40) {
        resultSummary = 'Warning: Moderate failure rate';
      } else if (internalRiskScore > 0) {
        resultSummary = 'Minor issues detected';
      } else {
        resultSummary = 'All biometric attempts successful';
      }

      // Upload scan data
      await scanDoc.set({
        'packageName': packageName,
        'timestamp': FieldValue.serverTimestamp(),
        'eventCount': logs.length,
        'successCount': successCount,
        'failCount': failCount,
        'errorCount': errorCount,
        'riskScore': securityScore, // For UI compatibility - inverted from internal risk score
        'resultSummary': resultSummary, // For UI compatibility
        'status': 'completed', // For UI compatibility
        'logs': logs.map((log) => Map<String, dynamic>.from(log)).toList(),
        'source': 'waiting_mode',
        'fridaVersion': 'laptop-based',
      });

      print('[WaitingModeService] Successfully uploaded scan to Firebase: ${scanDoc.id}');
    } catch (e) {
      print('[WaitingModeService] Error uploading to Firebase: $e');
      rethrow;
    }
  }

  /// Send DELETE_LOG broadcast to Frida hooks
  Future<void> _sendDeleteCommand() async {
    try {
      print('[WaitingModeService] Sending DELETE_LOG broadcast');

      await _sharedStorageChannel.invokeMethod('sendDeleteLogBroadcast');

      print('[WaitingModeService] DELETE_LOG broadcast sent successfully');
    } catch (e) {
      print('[WaitingModeService] Error sending DELETE_LOG broadcast: $e');
      rethrow;
    }
  }

  /// Increment user's scan counter in Firebase
  Future<void> _incrementScanCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      // Get current scan count
      final snapshot = await userDoc.get();
      final data = snapshot.data();

      // Get today's date as string (YYYY-MM-DD)
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Get scan data for today - safely handle different data types
      int todayScans = 0;
      if (data != null && data.containsKey('dailyScans')) {
        final dailyScansRaw = data['dailyScans'];
        if (dailyScansRaw is Map) {
          // Convert to Map<String, dynamic> safely
          final scanData = Map<String, dynamic>.from(dailyScansRaw);
          todayScans = (scanData[dateKey] as int?) ?? 0;
        }
      }

      // Increment scan count - use set with merge to create field if it doesn't exist
      await userDoc.set({
        'dailyScans': {dateKey: todayScans + 1},
        'totalScans': FieldValue.increment(1),
        'lastScanTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('[WaitingModeService] Scan count incremented: $dateKey -> ${todayScans + 1}');
    } catch (e) {
      print('[WaitingModeService] Error incrementing scan count: $e');
      // Don't rethrow - scan count is not critical
    }
  }

  /// Check if user has reached daily scan limit (3 scans for free users)
  Future<bool> canScanToday() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data() ?? {};
      final isPremium = data['isPremium'] as bool? ?? false;

      // Premium users have unlimited scans
      if (isPremium) return true;

      // Get today's date as string (YYYY-MM-DD)
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Get scan data for today
      final scanData = data['dailyScans'] as Map<String, dynamic>? ?? {};
      final todayScans = (scanData[dateKey] as int?) ?? 0;

      // Free users: 3 scans per day
      const freeUserLimit = 3;
      return todayScans < freeUserLimit;
    } catch (e) {
      print('[WaitingModeService] Error checking scan limit: $e');
      return false;
    }
  }

  /// Get remaining scans for today (for free users)
  Future<int> getRemainingScanCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data() ?? {};
      final isPremium = data['isPremium'] as bool? ?? false;

      // Premium users have unlimited scans
      if (isPremium) return 999;

      // Get today's date as string (YYYY-MM-DD)
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Get scan data for today
      final scanData = data['dailyScans'] as Map<String, dynamic>? ?? {};
      final todayScans = (scanData[dateKey] as int?) ?? 0;

      // Free users: 3 scans per day
      const freeUserLimit = 3;
      return (freeUserLimit - todayScans).clamp(0, freeUserLimit);
    } catch (e) {
      print('[WaitingModeService] Error getting remaining scan count: $e');
      return 0;
    }
  }

  /// Check if currently in waiting mode
  bool get isWaiting => _isWaiting;

  /// Get the package being monitored (if in waiting mode)
  String? get targetPackage => _targetPackage;
}
