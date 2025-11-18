import 'dart:convert';
import 'package:flutter/services.dart';

/// Service to read biometric hook logs via ContentProvider IPC
///
/// Architecture:
/// Vulnerable App (Hooked)
/// ├─ HookEngine intercepts biometric events
/// ├─ TimingTracker writes to local JSONL file
/// └─ HookLogProvider exposes via ContentProvider
///     ↓ (IPC via ContentProvider)
/// BioShield App
/// └─ Reads logs from ContentProvider authority
class HookContentProviderService {
  static const MethodChannel _channel =
      MethodChannel('com.fyp.bioshield/contentprovider');

  /// Read all logs from a hooked app's ContentProvider
  ///
  /// [packageName] - The package name of the hooked app
  /// Returns list of log events as JSON objects
  Future<List<Map<String, dynamic>>> readLogs(String packageName) async {
    try {
      print('[HookContentProviderService] Reading logs from: $packageName');

      // Extract base package name (first 3 segments for com.fyp.vulnerable.* apps)
      // For com.fyp.vulnerable.vulnerable_biometric_app -> com.fyp.vulnerable
      final authority = _getAuthority(packageName);
      print('[HookContentProviderService] Using authority: $authority');

      final result = await _channel.invokeMethod('readLogs', {
        'authority': authority,
        'path': 'data', // Frida ContentProvider path
      });

      if (result == null) {
        print('[HookContentProviderService] No logs returned');
        return [];
      }

      // Parse JSONL response
      final List<dynamic> jsonList = json.decode(result);
      final logs = jsonList.map((e) => Map<String, dynamic>.from(e)).toList();

      print('[HookContentProviderService] Read ${logs.length} log events');
      return logs;
    } catch (e) {
      print('[HookContentProviderService] Error reading logs: $e');
      return [];
    }
  }

  /// Read only timing logs (enhanced 12-feature events)
  ///
  /// [packageName] - The package name of the hooked app
  /// Returns list of timing events with ML features
  Future<List<Map<String, dynamic>>> readTimingLogs(String packageName) async {
    try {
      print('[HookContentProviderService] Reading timing logs from: $packageName');

      final authority = _getAuthority(packageName);
      final result = await _channel.invokeMethod('readLogs', {
        'authority': authority,
        'path': 'timing', // Only timing logs
      });

      if (result == null) {
        print('[HookContentProviderService] No timing logs returned');
        return [];
      }

      // Parse JSONL response
      final List<dynamic> jsonList = json.decode(result);
      final logs = jsonList.map((e) => Map<String, dynamic>.from(e)).toList();

      print('[HookContentProviderService] Read ${logs.length} timing events');
      return logs;
    } catch (e) {
      print('[HookContentProviderService] Error reading timing logs: $e');
      return [];
    }
  }

  /// Read only general logs (LogStore events)
  ///
  /// [packageName] - The package name of the hooked app
  /// Returns list of general log events
  Future<List<Map<String, dynamic>>> readGeneralLogs(String packageName) async {
    try {
      print('[HookContentProviderService] Reading general logs from: $packageName');

      final authority = _getAuthority(packageName);
      final result = await _channel.invokeMethod('readLogs', {
        'authority': authority,
        'path': 'general', // Only general logs
      });

      if (result == null) {
        print('[HookContentProviderService] No general logs returned');
        return [];
      }

      // Parse JSONL response
      final List<dynamic> jsonList = json.decode(result);
      final logs = jsonList.map((e) => Map<String, dynamic>.from(e)).toList();

      print('[HookContentProviderService] Read ${logs.length} general events');
      return logs;
    } catch (e) {
      print('[HookContentProviderService] Error reading general logs: $e');
      return [];
    }
  }

  /// Clear all logs from a hooked app
  ///
  /// [packageName] - The package name of the hooked app
  /// Returns number of logs deleted
  Future<int> clearLogs(String packageName) async {
    try {
      print('[HookContentProviderService] Clearing logs from: $packageName');

      final authority = _getAuthority(packageName);
      final result = await _channel.invokeMethod('clearLogs', {
        'authority': authority,
      });

      final deletedCount = result as int? ?? 0;
      print('[HookContentProviderService] Cleared $deletedCount log files');
      return deletedCount;
    } catch (e) {
      print('[HookContentProviderService] Error clearing logs: $e');
      return 0;
    }
  }

  /// Check if a hooked app has logs available
  ///
  /// [packageName] - The package name of the hooked app
  /// Returns true if logs are available
  Future<bool> hasLogs(String packageName) async {
    try {
      final logs = await readLogs(packageName);
      return logs.isNotEmpty;
    } catch (e) {
      print('[HookContentProviderService] Error checking logs: $e');
      return false;
    }
  }

  /// Generate a scan report from ContentProvider logs
  ///
  /// [packageName] - The package name of the hooked app
  /// Returns a comprehensive scan report
  Future<HookScanReport> generateReport(String packageName) async {
    try {
      print('[HookContentProviderService] Generating report for: $packageName');

      // Read all logs
      final logs = await readLogs(packageName);

      if (logs.isEmpty) {
        throw Exception('No logs available for $packageName');
      }

      // Analyze logs
      int successCount = 0;
      int failureCount = 0;
      int errorCount = 0;
      int suspiciousTimings = 0;
      int rapidRetries = 0;
      final anomalies = <String>[];

      for (var log in logs) {
        final eventType = log['eventType'] as String?;

        if (eventType == 'auth_success') {
          successCount++;
        } else if (eventType == 'auth_failed') {
          failureCount++;
        } else if (eventType == 'auth_error') {
          errorCount++;
        }

        // Check for anomalies
        final logAnomalies = log['anomalies'] as List<dynamic>?;
        if (logAnomalies != null && logAnomalies.isNotEmpty) {
          for (var anomaly in logAnomalies) {
            final anomalyStr = anomaly.toString();
            if (!anomalies.contains(anomalyStr)) {
              anomalies.add(anomalyStr);
            }

            if (anomalyStr.contains('FAST') || anomalyStr.contains('SLOW')) {
              suspiciousTimings++;
            } else if (anomalyStr.contains('RAPID_RETRY')) {
              rapidRetries++;
            }
          }
        }
      }

      // Determine risk level
      RiskLevel riskLevel;
      if (anomalies.isEmpty) {
        riskLevel = RiskLevel.safe;
      } else if (suspiciousTimings <= 2 && rapidRetries == 0) {
        riskLevel = RiskLevel.low;
      } else if (suspiciousTimings <= 3 || rapidRetries <= 5) {
        riskLevel = RiskLevel.medium;
      } else {
        riskLevel = RiskLevel.high;
      }

      return HookScanReport(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        packageName: packageName,
        authEventCount: logs.length,
        successCount: successCount,
        failureCount: failureCount,
        errorCount: errorCount,
        timingStats: TimingStats(
          totalSessions: 1,
          totalEvents: logs.length,
          suspiciousTimings: suspiciousTimings,
          rapidRetries: rapidRetries,
          eventCounts: {
            'auth_success': successCount,
            'auth_failed': failureCount,
            'auth_error': errorCount,
          },
          averageDurations: {},
        ),
        hasAnomalies: anomalies.isNotEmpty,
        anomalyReport: anomalies.isNotEmpty
            ? AnomalyReport(
                sessionId: 'contentprovider_scan',
                eventCount: logs.length,
                anomalyCount: anomalies.length,
                anomalies: anomalies,
              )
            : null,
        riskLevel: riskLevel,
      );
    } catch (e) {
      print('[HookContentProviderService] Error generating report: $e');
      rethrow;
    }
  }

  /// Export logs to JSON string for ML processing
  ///
  /// [packageName] - The package name of the hooked app
  /// Returns JSON string of all logs
  Future<String> exportLogsJson(String packageName) async {
    try {
      final logs = await readLogs(packageName);
      return json.encode(logs);
    } catch (e) {
      print('[HookContentProviderService] Error exporting logs: $e');
      return '[]';
    }
  }

  /// Extract ContentProvider authority from package name
  ///
  /// For laptop-based Frida injection: bioshield.logs (dynamic provider)
  /// The Frida agent.js (running from laptop) dynamically registers the ContentProvider
  ///
  /// [packageName] - Full package name
  /// Returns authority string
  String _getAuthority(String packageName) {
    // For laptop-based Frida injection, use the universal authority
    // The Frida agent.js dynamically registers: content://bioshield.logs/data
    return 'bioshield.logs';

    // Legacy format (if needed):
    // final segments = packageName.split('.');
    // if (segments.length >= 3 && segments[0] == 'com' && segments[1] == 'fyp') {
    //   return '${segments[0]}.${segments[1]}.${segments[2]}.hookprovider';
    // }
    // return '$packageName.hookprovider';
  }
}

/// Scan report from hook framework
class HookScanReport {
  final int timestamp;
  final String packageName;
  final int authEventCount;
  final int successCount;
  final int failureCount;
  final int errorCount;
  final TimingStats timingStats;
  final bool hasAnomalies;
  final AnomalyReport? anomalyReport;
  final RiskLevel riskLevel;

  HookScanReport({
    required this.timestamp,
    required this.packageName,
    required this.authEventCount,
    required this.successCount,
    required this.failureCount,
    required this.errorCount,
    required this.timingStats,
    required this.hasAnomalies,
    this.anomalyReport,
    required this.riskLevel,
  });

  double get successRate {
    if (authEventCount == 0) return 0.0;
    return (successCount / authEventCount) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'packageName': packageName,
      'authEventCount': authEventCount,
      'successCount': successCount,
      'failureCount': failureCount,
      'errorCount': errorCount,
      'timingStats': timingStats.toMap(),
      'hasAnomalies': hasAnomalies,
      'anomalyReport': anomalyReport?.toMap(),
      'riskLevel': riskLevel.toString().split('.').last.toUpperCase(),
      'successRate': successRate,
    };
  }
}

/// Timing statistics from TimingTracker
class TimingStats {
  final int totalSessions;
  final int totalEvents;
  final int suspiciousTimings;
  final int rapidRetries;
  final Map<String, int> eventCounts;
  final Map<String, int> averageDurations;

  TimingStats({
    required this.totalSessions,
    required this.totalEvents,
    required this.suspiciousTimings,
    required this.rapidRetries,
    required this.eventCounts,
    required this.averageDurations,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalSessions': totalSessions,
      'totalEvents': totalEvents,
      'suspiciousTimings': suspiciousTimings,
      'rapidRetries': rapidRetries,
      'eventCounts': eventCounts,
      'averageDurations': averageDurations,
    };
  }
}

/// Anomaly report from TimingTracker
class AnomalyReport {
  final String sessionId;
  final int eventCount;
  final int anomalyCount;
  final List<String> anomalies;

  AnomalyReport({
    required this.sessionId,
    required this.eventCount,
    required this.anomalyCount,
    required this.anomalies,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'eventCount': eventCount,
      'anomalyCount': anomalyCount,
      'anomalies': anomalies,
    };
  }
}

/// Risk levels assessed by the hook framework
enum RiskLevel {
  safe,    // No anomalies detected
  low,     // Minor anomalies (1-2 suspicious timings)
  medium,  // Moderate anomalies (2+ suspicious timings OR rapid retries)
  high,    // Severe anomalies (3+ suspicious timings OR 5+ rapid retries)
}

extension RiskLevelExtension on RiskLevel {
  String get displayName {
    switch (this) {
      case RiskLevel.safe:
        return 'Safe';
      case RiskLevel.low:
        return 'Low Risk';
      case RiskLevel.medium:
        return 'Medium Risk';
      case RiskLevel.high:
        return 'High Risk';
    }
  }

  String get emoji {
    switch (this) {
      case RiskLevel.safe:
        return '✅';
      case RiskLevel.low:
        return '⚠️';
      case RiskLevel.medium:
        return '🔶';
      case RiskLevel.high:
        return '🔴';
    }
  }
}
