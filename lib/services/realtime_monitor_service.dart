// lib/services/realtime_monitor_service.dart
// Real-Time Biometric Monitoring Service - Premium Feature
// Continuously monitors biometric authentication attempts and alerts users to threats

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'biometric_service.dart';

/// Monitoring event types
enum MonitorEventType {
  successfulAuth,
  failedAuth,
  suspiciousActivity,
  multipleFailures,
  unusualTiming,
  possibleSpoof,
}

/// Real-time monitoring event
class MonitorEvent {
  final String id;
  final MonitorEventType type;
  final DateTime timestamp;
  final String description;
  final Map<String, dynamic> metadata;
  final int severityLevel; // 1-5, where 5 is critical

  MonitorEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.description,
    required this.metadata,
    required this.severityLevel,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'metadata': metadata,
      'severityLevel': severityLevel,
    };
  }

  factory MonitorEvent.fromMap(Map<String, dynamic> map) {
    return MonitorEvent(
      id: map['id'],
      type: MonitorEventType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => MonitorEventType.suspiciousActivity,
      ),
      timestamp: DateTime.parse(map['timestamp']),
      description: map['description'],
      metadata: map['metadata'] ?? {},
      severityLevel: map['severityLevel'] ?? 3,
    );
  }
}

/// Real-Time Monitor Service
class RealtimeMonitorService {
  static final RealtimeMonitorService _instance = RealtimeMonitorService._internal();
  factory RealtimeMonitorService() => _instance;
  RealtimeMonitorService._internal();

  final BiometricService _biometricService = BiometricService();

  bool _isMonitoring = false;
  Timer? _monitorTimer;
  StreamController<MonitorEvent>? _eventStreamController;

  // Statistics
  int _totalAuthAttempts = 0;
  int _failedAttempts = 0;
  int _suspiciousEvents = 0;
  DateTime? _lastAuthTime;
  final List<DateTime> _recentFailures = [];

  /// Check if monitoring is currently active
  bool get isMonitoring => _isMonitoring;

  /// Get real-time event stream
  Stream<MonitorEvent> get eventStream {
    _eventStreamController ??= StreamController<MonitorEvent>.broadcast();
    return _eventStreamController!.stream;
  }

  /// Get current statistics
  Map<String, dynamic> getStatistics() {
    return {
      'totalAuthAttempts': _totalAuthAttempts,
      'failedAttempts': _failedAttempts,
      'suspiciousEvents': _suspiciousEvents,
      'successRate': _totalAuthAttempts > 0
          ? ((_totalAuthAttempts - _failedAttempts) / _totalAuthAttempts * 100).toStringAsFixed(1)
          : '0.0',
      'lastAuthTime': _lastAuthTime?.toIso8601String(),
      'monitoringStatus': _isMonitoring ? 'active' : 'inactive',
    };
  }

  /// Start real-time monitoring (Premium feature)
  Future<void> startMonitoring() async {
    if (_isMonitoring) {
      print('Monitoring already active');
      return;
    }

    print('🔴 Starting real-time biometric monitoring...');
    _isMonitoring = true;
    _eventStreamController ??= StreamController<MonitorEvent>.broadcast();

    // Check biometric availability
    final capability = await _biometricService.checkBiometricSupport();
    if (!capability.isSupported) {
      _emitEvent(MonitorEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: MonitorEventType.suspiciousActivity,
        timestamp: DateTime.now(),
        description: 'Biometric hardware not available',
        metadata: {'reason': capability.message},
        severityLevel: 4,
      ));
    }

    // Start periodic monitoring (every 5 seconds)
    _monitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _performMonitoringCheck();
    });

    // Save monitoring session to Firestore
    await _saveMonitoringSession('started');

    _emitEvent(MonitorEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: MonitorEventType.successfulAuth,
      timestamp: DateTime.now(),
      description: 'Real-time monitoring started',
      metadata: {'status': 'active'},
      severityLevel: 1,
    ));
  }

  /// Stop real-time monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) {
      print('Monitoring not active');
      return;
    }

    print('🔴 Stopping real-time biometric monitoring...');
    _isMonitoring = false;
    _monitorTimer?.cancel();
    _monitorTimer = null;

    // Save monitoring session to Firestore
    await _saveMonitoringSession('stopped');

    _emitEvent(MonitorEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: MonitorEventType.successfulAuth,
      timestamp: DateTime.now(),
      description: 'Real-time monitoring stopped',
      metadata: getStatistics(),
      severityLevel: 1,
    ));

    await _eventStreamController?.close();
    _eventStreamController = null;
  }

  /// Perform monitoring check
  void _performMonitoringCheck() {
    if (!_isMonitoring) return;

    // Simulate detection of biometric events
    // In a real implementation, this would hook into Android's BiometricPrompt callbacks
    _checkForSuspiciousPatterns();
  }

  /// Check for suspicious patterns
  void _checkForSuspiciousPatterns() {
    // Check for multiple recent failures (brute force attempt)
    _recentFailures.removeWhere(
      (time) => DateTime.now().difference(time).inMinutes > 5,
    );

    if (_recentFailures.length >= 3) {
      _emitEvent(MonitorEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: MonitorEventType.multipleFailures,
        timestamp: DateTime.now(),
        description: 'Multiple failed authentication attempts detected',
        metadata: {
          'failureCount': _recentFailures.length,
          'timeWindow': '5 minutes',
          'recommendation': 'Possible brute force attack',
        },
        severityLevel: 5,
      ));
      _suspiciousEvents++;
    }

    // Check for unusual timing patterns
    if (_lastAuthTime != null) {
      final timeSinceLastAuth = DateTime.now().difference(_lastAuthTime!);
      if (timeSinceLastAuth.inSeconds < 2) {
        _emitEvent(MonitorEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MonitorEventType.unusualTiming,
          timestamp: DateTime.now(),
          description: 'Rapid authentication attempts detected',
          metadata: {
            'timeBetweenAttempts': '${timeSinceLastAuth.inMilliseconds}ms',
            'recommendation': 'Possible automated attack',
          },
          severityLevel: 4,
        ));
        _suspiciousEvents++;
      }
    }
  }

  /// Record authentication attempt
  Future<void> recordAuthAttempt({
    required bool success,
    Map<String, dynamic>? metadata,
  }) async {
    _totalAuthAttempts++;
    _lastAuthTime = DateTime.now();

    if (!success) {
      _failedAttempts++;
      _recentFailures.add(DateTime.now());

      _emitEvent(MonitorEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: MonitorEventType.failedAuth,
        timestamp: DateTime.now(),
        description: 'Failed biometric authentication',
        metadata: metadata ?? {},
        severityLevel: 2,
      ));
    } else {
      _emitEvent(MonitorEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: MonitorEventType.successfulAuth,
        timestamp: DateTime.now(),
        description: 'Successful biometric authentication',
        metadata: metadata ?? {},
        severityLevel: 1,
      ));
    }

    // Save to Firestore
    await _saveAuthEvent(success, metadata);
  }

  /// Emit monitoring event
  void _emitEvent(MonitorEvent event) {
    _eventStreamController?.add(event);
    print('📊 Monitor Event: ${event.description}');
  }

  /// Save monitoring session to Firestore
  Future<void> _saveMonitoringSession(String action) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('monitoring_sessions')
          .add({
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
        'statistics': getStatistics(),
      });
    } catch (e) {
      print('Error saving monitoring session: $e');
    }
  }

  /// Save authentication event to Firestore
  Future<void> _saveAuthEvent(bool success, Map<String, dynamic>? metadata) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('auth_events')
          .add({
        'success': success,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
      });
    } catch (e) {
      print('Error saving auth event: $e');
    }
  }

  /// Get event color based on severity
  static Color getEventColor(int severity) {
    switch (severity) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.deepOrange;
      case 5:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get event icon based on type
  static IconData getEventIcon(MonitorEventType type) {
    switch (type) {
      case MonitorEventType.successfulAuth:
        return Icons.check_circle;
      case MonitorEventType.failedAuth:
        return Icons.cancel;
      case MonitorEventType.suspiciousActivity:
        return Icons.warning;
      case MonitorEventType.multipleFailures:
        return Icons.block;
      case MonitorEventType.unusualTiming:
        return Icons.access_time;
      case MonitorEventType.possibleSpoof:
        return Icons.security;
    }
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _eventStreamController?.close();
    _monitorTimer?.cancel();
  }
}
