import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_id_service.dart';

/// Service for BioShield to upload hook logs to Firebase
///
/// Flow:
/// 1. BioShield reads logs from hooked app via ContentProvider IPC
/// 2. BioShield uploads logs to Firebase: bioshield_logs/{userId}/{packageName}/{events}
/// 3. BioShield can then analyze logs, generate reports, and display results
///
/// Note: The HOOKED APP does NOT upload to Firebase.
/// Only BioShield uploads after reading via ContentProvider.
class FirebaseLogUploadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload a single log event to Firebase
  ///
  /// [packageName] - Package name of the hooked app
  /// [logEvent] - Log event data (from ContentProvider)
  Future<void> uploadLogEvent(String packageName, Map<String, dynamic> logEvent) async {
    try {
      final userId = await UserIdService.getUserId();

      print('[FirebaseLogUploadService] Uploading log for $packageName');

      // Add metadata
      logEvent['uploadedAt'] = FieldValue.serverTimestamp();
      logEvent['uploadedBy'] = 'bioshield';

      // Upload to Firestore
      await _firestore
          .collection('bioshield_logs')
          .doc(userId)
          .collection(packageName)
          .add(logEvent);

      print('[FirebaseLogUploadService] Log uploaded successfully');
    } catch (e) {
      print('[FirebaseLogUploadService] Error uploading log: $e');
      rethrow;
    }
  }

  /// Upload multiple log events in batch
  ///
  /// [packageName] - Package name of the hooked app
  /// [logEvents] - List of log events (from ContentProvider)
  /// Returns number of successfully uploaded logs
  Future<int> uploadLogEventsBatch(String packageName, List<Map<String, dynamic>> logEvents) async {
    try {
      final userId = await UserIdService.getUserId();

      print('[FirebaseLogUploadService] Uploading ${logEvents.length} logs for $packageName');

      int successCount = 0;
      final batch = _firestore.batch();

      for (var logEvent in logEvents) {
        // Add metadata
        final enrichedEvent = Map<String, dynamic>.from(logEvent);
        enrichedEvent['uploadedAt'] = FieldValue.serverTimestamp();
        enrichedEvent['uploadedBy'] = 'bioshield';

        // Add to batch
        final docRef = _firestore
            .collection('bioshield_logs')
            .doc(userId)
            .collection(packageName)
            .doc();

        batch.set(docRef, enrichedEvent);
        successCount++;
      }

      // Commit batch
      await batch.commit();

      print('[FirebaseLogUploadService] Uploaded $successCount logs successfully');
      return successCount;
    } catch (e) {
      print('[FirebaseLogUploadService] Error uploading batch: $e');
      rethrow;
    }
  }

  /// Upload scan report to Firebase
  ///
  /// [packageName] - Package name of the hooked app
  /// [report] - Scan report data
  Future<void> uploadScanReport(String packageName, Map<String, dynamic> report) async {
    try {
      final userId = await UserIdService.getUserId();

      print('[FirebaseLogUploadService] Uploading scan report for $packageName');

      // Add metadata
      report['uploadedAt'] = FieldValue.serverTimestamp();
      report['uploadedBy'] = 'bioshield';
      report['userId'] = userId;
      report['packageName'] = packageName;

      // Upload to Firestore
      await _firestore
          .collection('scan_reports')
          .doc(userId)
          .collection(packageName)
          .add(report);

      print('[FirebaseLogUploadService] Scan report uploaded successfully');
    } catch (e) {
      print('[FirebaseLogUploadService] Error uploading scan report: $e');
      rethrow;
    }
  }

  /// Upload scan report and update latest report document
  ///
  /// [packageName] - Package name of the hooked app
  /// [report] - Scan report data
  Future<void> uploadAndUpdateLatestReport(String packageName, Map<String, dynamic> report) async {
    try {
      final userId = await UserIdService.getUserId();

      print('[FirebaseLogUploadService] Uploading and updating latest report for $packageName');

      // Add metadata
      report['uploadedAt'] = FieldValue.serverTimestamp();
      report['uploadedBy'] = 'bioshield';
      report['userId'] = userId;
      report['packageName'] = packageName;

      // Upload to history
      await _firestore
          .collection('scan_reports')
          .doc(userId)
          .collection(packageName)
          .add(report);

      // Update latest report
      await _firestore
          .collection('scan_reports')
          .doc(userId)
          .collection('latest')
          .doc(packageName)
          .set(report, SetOptions(merge: true));

      print('[FirebaseLogUploadService] Report uploaded and latest updated');
    } catch (e) {
      print('[FirebaseLogUploadService] Error uploading report: $e');
      rethrow;
    }
  }

  /// Clear logs for a specific app from Firebase
  ///
  /// [packageName] - Package name of the hooked app
  Future<void> clearLogsForApp(String packageName) async {
    try {
      final userId = await UserIdService.getUserId();

      print('[FirebaseLogUploadService] Clearing logs for $packageName');

      final collection = _firestore
          .collection('bioshield_logs')
          .doc(userId)
          .collection(packageName);

      final snapshot = await collection.get();
      final batch = _firestore.batch();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      print('[FirebaseLogUploadService] Cleared ${snapshot.docs.length} logs');
    } catch (e) {
      print('[FirebaseLogUploadService] Error clearing logs: $e');
      rethrow;
    }
  }

  /// Get upload statistics
  ///
  /// [packageName] - Package name of the hooked app
  /// Returns map with upload statistics
  Future<Map<String, dynamic>> getUploadStats(String packageName) async {
    try {
      final userId = await UserIdService.getUserId();

      final logsSnapshot = await _firestore
          .collection('bioshield_logs')
          .doc(userId)
          .collection(packageName)
          .count()
          .get();

      final reportsSnapshot = await _firestore
          .collection('scan_reports')
          .doc(userId)
          .collection(packageName)
          .count()
          .get();

      return {
        'totalLogs': logsSnapshot.count,
        'totalReports': reportsSnapshot.count,
        'packageName': packageName,
      };
    } catch (e) {
      print('[FirebaseLogUploadService] Error getting stats: $e');
      return {
        'totalLogs': 0,
        'totalReports': 0,
        'packageName': packageName,
      };
    }
  }

  /// Stream logs for a specific app from Firebase
  ///
  /// [packageName] - Package name of the hooked app
  /// Returns real-time stream of uploaded logs
  Future<Stream<List<Map<String, dynamic>>>> streamLogsForApp(String packageName) async {
    final userId = await UserIdService.getUserId();

    return _firestore
        .collection('bioshield_logs')
        .doc(userId)
        .collection(packageName)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get latest scan report for an app
  ///
  /// [packageName] - Package name of the hooked app
  /// Returns latest scan report or null if none exists
  Future<Map<String, dynamic>?> getLatestReport(String packageName) async {
    try {
      final userId = await UserIdService.getUserId();

      final doc = await _firestore
          .collection('scan_reports')
          .doc(userId)
          .collection('latest')
          .doc(packageName)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('[FirebaseLogUploadService] Error getting latest report: $e');
      return null;
    }
  }

  /// Get all scan reports for an app
  ///
  /// [packageName] - Package name of the hooked app
  /// [limit] - Maximum number of reports to fetch (default: 10)
  /// Returns list of scan reports, newest first
  Future<List<Map<String, dynamic>>> getReportsForApp(String packageName, {int limit = 10}) async {
    try {
      final userId = await UserIdService.getUserId();

      final snapshot = await _firestore
          .collection('scan_reports')
          .doc(userId)
          .collection(packageName)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('[FirebaseLogUploadService] Error getting reports: $e');
      return [];
    }
  }
}
