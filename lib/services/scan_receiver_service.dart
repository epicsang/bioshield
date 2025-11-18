// lib/services/scan_receiver_service.dart
// Service to receive real-time vulnerability data from repackaged apps via IPC

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'scan_results_service.dart';

class ScanReceiverService {
  static const platform = MethodChannel('com.fyp.bioshield/scan_receiver');
  static ScanReceiverService? _instance;
  static bool _initialized = false;

  // Callback for when scan data is received
  Function(Map<String, dynamic>)? onScanDataReceived;

  ScanReceiverService._();

  static ScanReceiverService get instance {
    _instance ??= ScanReceiverService._();
    return _instance!;
  }

  /// Initialize the receiver service
  /// Call this once during app startup
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Set up method call handler to receive data from Android
      platform.setMethodCallHandler(_handleMethodCall);
      _initialized = true;
      print('[ScanReceiver] Service initialized and listening for broadcasts');
    } catch (e) {
      print('[ScanReceiver] Error initializing: $e');
    }
  }

  /// Handle incoming method calls from Android
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    print('[ScanReceiver] Received method call: ${call.method}');

    switch (call.method) {
      case 'onScanDataReceived':
        await _processScanData(call.arguments);
        return null;

      default:
        print('[ScanReceiver] Unknown method: ${call.method}');
        throw PlatformException(
          code: 'UNKNOWN_METHOD',
          message: 'Method ${call.method} not implemented',
        );
    }
  }

  /// Process received scan data
  Future<void> _processScanData(dynamic arguments) async {
    try {
      final Map<String, dynamic> data = Map<String, dynamic>.from(arguments);
      final String? scanDataJson = data['scanData'];
      final int? timestamp = data['timestamp'];
      final String? sourcePackage = data['sourcePackage'];

      print('[ScanReceiver] Processing scan data from $sourcePackage');
      print('[ScanReceiver] Data size: ${scanDataJson?.length ?? 0} bytes');
      print('[ScanReceiver] Timestamp: $timestamp');

      if (scanDataJson == null || scanDataJson.isEmpty) {
        print('[ScanReceiver] ERROR: Scan data is null or empty');
        return;
      }

      // Parse JSON
      Map<String, dynamic> scanResult = jsonDecode(scanDataJson);
      print('[ScanReceiver] Parsed scan result successfully');

      // Add source info
      scanResult['sourcePackage'] = sourcePackage;
      scanResult['receivedAt'] = timestamp;

      // Call callback if registered
      if (onScanDataReceived != null) {
        onScanDataReceived!(scanResult);
      }

      // Auto-save to Firestore
      await _saveScanToFirestore(scanResult);

      print('[ScanReceiver] Scan data processed and saved successfully!');
    } catch (e, stackTrace) {
      print('[ScanReceiver] ERROR processing scan data: $e');
      print('[ScanReceiver] Stack trace: $stackTrace');
    }
  }

  /// Save scan data to Firestore
  Future<void> _saveScanToFirestore(Map<String, dynamic> scanData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('[ScanReceiver] No user logged in, skipping Firestore save');
        return;
      }

      // Extract metadata
      final metadata = scanData['metadata'] ?? {};
      final vulnerabilities = List<Map<String, dynamic>>.from(scanData['vulnerabilities'] ?? []);
      final timingData = scanData['timingData'] ?? {};
      final apiFindings = List<Map<String, dynamic>>.from(scanData['apiFindings'] ?? []);

      // Calculate risk score
      final riskScore = _calculateRiskScore(vulnerabilities);

      // Count vulnerabilities by severity
      final severityCounts = _countVulnerabilitiesBySeverity(vulnerabilities);

      // Generate result summary for UI
      String resultSummary;
      if (riskScore >= 70) {
        resultSummary = 'Critical: ${vulnerabilities.length} vulnerabilities detected';
      } else if (riskScore >= 40) {
        resultSummary = 'Warning: Moderate security risks found';
      } else if (riskScore > 0) {
        resultSummary = 'Minor issues detected';
      } else {
        resultSummary = 'No security issues detected';
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('scans')
          .add({
        'scanId': metadata['scanId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'biometricType': 'Real-Time Analysis',
        'targetApp': metadata['targetPackage'] ?? scanData['sourcePackage'] ?? 'Unknown',
        'appVersion': metadata['appVersion'] ?? 'Unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'riskScore': riskScore.toDouble(),
        'resultSummary': resultSummary, // For UI compatibility
        'status': 'completed',
        'vulnerabilityCount': vulnerabilities.length,
        'criticalCount': severityCounts['CRITICAL'] ?? 0,
        'highCount': severityCounts['HIGH'] ?? 0,
        'mediumCount': severityCounts['MEDIUM'] ?? 0,
        'lowCount': severityCounts['LOW'] ?? 0,
        'securityStatus': _getSecurityStatus(riskScore),
        // Store full vulnerability data
        'vulnerabilities': vulnerabilities,
        // Store API findings
        'apiFindings': apiFindings,
        // Store timing data
        'timingData': timingData,
        // Source info
        'sourcePackage': scanData['sourcePackage'],
        'receivedAt': scanData['receivedAt'],
        'method': 'IPC',  // Mark as IPC-received vs file-based
      });

      print('[ScanReceiver] Scan saved to Firestore successfully');
    } catch (e) {
      print('[ScanReceiver] Error saving to Firestore: $e');
    }
  }

  /// Calculate risk score from vulnerabilities
  int _calculateRiskScore(List<Map<String, dynamic>> vulnerabilities) {
    if (vulnerabilities.isEmpty) return 100;

    int score = 100;
    for (var vuln in vulnerabilities) {
      final severity = vuln['severity']?.toString().toUpperCase() ?? 'LOW';
      switch (severity) {
        case 'CRITICAL':
          score -= 25;
          break;
        case 'HIGH':
          score -= 15;
          break;
        case 'MEDIUM':
          score -= 8;
          break;
        case 'LOW':
          score -= 3;
          break;
      }
    }

    return score.clamp(0, 100);
  }

  /// Count vulnerabilities by severity
  Map<String, int> _countVulnerabilitiesBySeverity(List<Map<String, dynamic>> vulnerabilities) {
    final counts = {
      'CRITICAL': 0,
      'HIGH': 0,
      'MEDIUM': 0,
      'LOW': 0,
    };

    for (var vuln in vulnerabilities) {
      final severity = vuln['severity']?.toString().toUpperCase() ?? 'LOW';
      if (counts.containsKey(severity)) {
        counts[severity] = (counts[severity] ?? 0) + 1;
      }
    }

    return counts;
  }

  /// Get security status from risk score
  String _getSecurityStatus(int riskScore) {
    if (riskScore >= 80) return 'SECURE';
    if (riskScore >= 60) return 'WARNING';
    if (riskScore >= 40) return 'VULNERABLE';
    return 'CRITICAL';
  }

  /// Dispose the service
  void dispose() {
    _initialized = false;
    onScanDataReceived = null;
  }
}
