import 'package:flutter/services.dart';

/// Service to communicate with the in-app hook framework
///
/// The hook framework runs inside repackaged APKs and logs:
/// - Every biometric authentication attempt
/// - Authentication results (success/fail/error)
/// - Timing data and anomalies
/// - Risk assessment
class HookFrameworkService {
  static const MethodChannel _channel =
      MethodChannel('com.fyp.bioshield/hook_framework');

  /// Check if hook framework is enabled
  Future<bool> isEnabled() async {
    try {
      final result = await _channel.invokeMethod('isEnabled');
      return result as bool;
    } catch (e) {
      print('Error checking hook framework status: $e');
      return false;
    }
  }

  /// Enable or disable the hook framework
  Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setEnabled', {'enabled': enabled});
    } catch (e) {
      print('Error setting hook framework status: $e');
      rethrow;
    }
  }

  /// Check if there is any data collected (to avoid empty reports)
  Future<bool> hasData() async {
    try {
      final stats = await getStats();
      final logCount = stats['logCount'] ?? 0;
      return logCount > 0;
    } catch (e) {
      return false;
    }
  }

  /// Get statistics from the hook framework
  ///
  /// Returns:
  /// - enabled: bool
  /// - hookedCallbacks: int
  /// - logCount: int
  /// - timingEvents: int
  /// - hookEngineStats: Map
  /// - biometricProxyStats: Map
  /// - timingTrackerStats: Map
  /// - logStoreStats: Map
  Future<Map<String, dynamic>> getStats() async {
    try {
      final result = await _channel.invokeMethod('getStats');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('Error getting hook framework stats: $e');
      return {};
    }
  }

  /// Generate a comprehensive scan report
  ///
  /// Returns:
  /// - timestamp: int
  /// - packageName: String
  /// - authEventCount: int
  /// - successCount: int
  /// - failureCount: int
  /// - errorCount: int
  /// - timingStats: Map
  /// - hasAnomalies: bool
  /// - anomalyReport: Map (if hasAnomalies)
  /// - riskLevel: String (SAFE/LOW/MEDIUM/HIGH)
  Future<HookScanReport> generateReport() async {
    try {
      final result = await _channel.invokeMethod('generateReport');
      return HookScanReport.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      print('Error generating scan report: $e');
      rethrow;
    }
  }

  /// Export logs to file for ML processing
  ///
  /// Returns: String path to exported log file
  Future<String?> exportLogs() async {
    try {
      final result = await _channel.invokeMethod('exportLogs');
      return result as String?;
    } catch (e) {
      print('Error exporting logs: $e');
      return null;
    }
  }

  /// Clear all hook data (logs, timing data, etc.)
  Future<void> clearData() async {
    try {
      await _channel.invokeMethod('clearData');
    } catch (e) {
      print('Error clearing hook data: $e');
      rethrow;
    }
  }

  /// Get human-readable status message
  Future<String> getStatusMessage() async {
    try {
      final result = await _channel.invokeMethod('getStatusMessage');
      return result as String;
    } catch (e) {
      print('Error getting status message: $e');
      return 'Error: $e';
    }
  }

  /// Export report as JSON string
  Future<String> exportReportJson() async {
    try {
      final result = await _channel.invokeMethod('exportReportJson');
      return result as String;
    } catch (e) {
      print('Error exporting report JSON: $e');
      return '{}';
    }
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

  factory HookScanReport.fromMap(Map<String, dynamic> map) {
    return HookScanReport(
      timestamp: map['timestamp'] as int,
      packageName: map['packageName'] as String,
      authEventCount: map['authEventCount'] as int,
      successCount: map['successCount'] as int,
      failureCount: map['failureCount'] as int,
      errorCount: map['errorCount'] as int,
      timingStats: TimingStats.fromMap(
        Map<String, dynamic>.from(map['timingStats'] as Map),
      ),
      hasAnomalies: map['hasAnomalies'] as bool,
      anomalyReport: map['anomalyReport'] != null
          ? AnomalyReport.fromMap(
              Map<String, dynamic>.from(map['anomalyReport'] as Map),
            )
          : null,
      riskLevel: _parseRiskLevel(map['riskLevel'] as String),
    );
  }

  static RiskLevel _parseRiskLevel(String level) {
    switch (level.toUpperCase()) {
      case 'SAFE':
        return RiskLevel.safe;
      case 'LOW':
        return RiskLevel.low;
      case 'MEDIUM':
        return RiskLevel.medium;
      case 'HIGH':
        return RiskLevel.high;
      default:
        return RiskLevel.safe;
    }
  }

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

  factory TimingStats.fromMap(Map<String, dynamic> map) {
    return TimingStats(
      totalSessions: map['totalSessions'] as int,
      totalEvents: map['totalEvents'] as int,
      suspiciousTimings: map['suspiciousTimings'] as int,
      rapidRetries: map['rapidRetries'] as int,
      eventCounts: Map<String, int>.from(map['eventCounts'] as Map? ?? {}),
      averageDurations: Map<String, int>.from(
        (map['averageDurations'] as Map? ?? {}).map(
          (key, value) => MapEntry(key.toString(), value as int),
        ),
      ),
    );
  }

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

  factory AnomalyReport.fromMap(Map<String, dynamic> map) {
    return AnomalyReport(
      sessionId: map['sessionId'] as String,
      eventCount: map['eventCount'] as int,
      anomalyCount: map['anomalyCount'] as int,
      anomalies: List<String>.from(map['anomalies'] as List),
    );
  }

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
