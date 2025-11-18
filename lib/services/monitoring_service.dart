// lib/services/monitoring_service.dart
// Real-Time Monitoring Service - Premium feature
// Monitors biometric authentication attempts in real-time

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Alert severity levels
enum AlertSeverity { info, warning, critical }

/// Security alert
class SecurityAlert {
  final String id;
  final DateTime timestamp;
  final AlertSeverity severity;
  final String title;
  final String description;
  final Map<String, dynamic> metadata;

  SecurityAlert({
    required this.id,
    required this.timestamp,
    required this.severity,
    required this.title,
    required this.description,
    required this.metadata,
  });

  factory SecurityAlert.fromMap(Map<String, dynamic> map) {
    return SecurityAlert(
      id: map['id'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      severity: AlertSeverity.values.firstWhere(
        (e) => e.toString() == 'AlertSeverity.${map['severity']}',
        orElse: () => AlertSeverity.info,
      ),
      title: map['title'] as String,
      description: map['description'] as String,
      metadata: map['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': Timestamp.fromDate(timestamp),
      'severity': severity.toString().split('.').last,
      'title': title,
      'description': description,
      'metadata': metadata,
    };
  }
}

/// Real-time monitoring service
class MonitoringService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<QuerySnapshot>? _alertSubscription;
  final _alertController = StreamController<SecurityAlert>.broadcast();

  /// Get alert stream for real-time updates
  Stream<SecurityAlert> get alertStream => _alertController.stream;

  /// Start monitoring for current user
  Future<void> startMonitoring() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Listen to real-time alerts
    _alertSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('alerts')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final alert = SecurityAlert.fromMap(
            change.doc.data() as Map<String, dynamic>,
          );
          _alertController.add(alert);
        }
      }
    });

    print('✅ Real-time monitoring started');
  }

  /// Stop monitoring
  void stopMonitoring() {
    _alertSubscription?.cancel();
    print('⏸️ Real-time monitoring stopped');
  }

  /// Create security alert
  Future<void> createAlert({
    required AlertSeverity severity,
    required String title,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final alert = SecurityAlert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      severity: severity,
      title: title,
      description: description,
      metadata: metadata ?? {},
    );

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('alerts')
        .doc(alert.id)
        .set(alert.toMap());

    print('🚨 Alert created: $title');
  }

  /// Get recent alerts
  Future<List<SecurityAlert>> getRecentAlerts({int limit = 20}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('alerts')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => SecurityAlert.fromMap(doc.data()))
        .toList();
  }

  /// Clear old alerts
  Future<void> clearOldAlerts({int daysToKeep = 30}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('alerts')
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    print('🗑️ Cleared ${snapshot.docs.length} old alerts');
  }

  /// Analyze scan and create alerts if needed
  Future<void> analyzeAndAlert({
    required Map<String, dynamic> scanResult,
    required double riskScore,
    required List<dynamic> vulnerabilities,
  }) async {
    // Critical risk - immediate alert
    if (riskScore < 40) {
      await createAlert(
        severity: AlertSeverity.critical,
        title: 'Critical Security Risk Detected',
        description:
            'Scan revealed critical vulnerabilities. Immediate action required.',
        metadata: {
          'riskScore': riskScore,
          'vulnerabilityCount': vulnerabilities.length,
          'scanId': scanResult['scanId'],
        },
      );
    }
    // High risk - warning alert
    else if (riskScore < 60) {
      await createAlert(
        severity: AlertSeverity.warning,
        title: 'High Security Risk Detected',
        description: 'Multiple vulnerabilities found. Review recommended.',
        metadata: {
          'riskScore': riskScore,
          'vulnerabilityCount': vulnerabilities.length,
          'scanId': scanResult['scanId'],
        },
      );
    }
    // Low risk but has vulnerabilities - info alert
    else if (vulnerabilities.isNotEmpty) {
      await createAlert(
        severity: AlertSeverity.info,
        title: 'Security Issues Found',
        description: 'Minor vulnerabilities detected. Review when possible.',
        metadata: {
          'riskScore': riskScore,
          'vulnerabilityCount': vulnerabilities.length,
          'scanId': scanResult['scanId'],
        },
      );
    }
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _alertController.close();
  }
}
