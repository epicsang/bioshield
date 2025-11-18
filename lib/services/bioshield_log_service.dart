import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_id_service.dart';

/// Service to stream biometric logs from Firestore
/// Hooked apps upload logs to: bioshield_logs/{userId}/{packageName}/{events}
class BioshieldLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream logs for a specific app package
  /// Returns realtime stream of biometric events from hooked app
  Future<Stream<List<Map<String, dynamic>>>> streamLogsForApp(String packageName) async {
    final userId = await UserIdService.getUserId();

    print('[BioshieldLogService] Streaming logs for userId=$userId, package=$packageName');

    return _firestore
        .collection('bioshield_logs')
        .doc(userId)
        .collection(packageName)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      print('[BioshieldLogService] Received ${snapshot.docs.length} log events');
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id; // Include document ID for reference
        return data;
      }).toList();
    });
  }

  /// Get all logs for a specific app (one-time fetch)
  Future<List<Map<String, dynamic>>> getLogsForApp(String packageName) async {
    final userId = await UserIdService.getUserId();

    print('[BioshieldLogService] Fetching logs for userId=$userId, package=$packageName');

    final snapshot = await _firestore
        .collection('bioshield_logs')
        .doc(userId)
        .collection(packageName)
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['docId'] = doc.id;
      return data;
    }).toList();
  }

  /// Clear all logs for a specific app
  Future<void> clearLogsForApp(String packageName) async {
    final userId = await UserIdService.getUserId();

    print('[BioshieldLogService] Clearing logs for userId=$userId, package=$packageName');

    final collection = _firestore
        .collection('bioshield_logs')
        .doc(userId)
        .collection(packageName);

    final snapshot = await collection.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    print('[BioshieldLogService] Cleared ${snapshot.docs.length} log events');
  }

  /// Get list of all apps that have uploaded logs
  Future<List<String>> getAppsWithLogs() async {
    final userId = await UserIdService.getUserId();

    // Note: Firestore doesn't support listing subcollections directly
    // This would need to be tracked separately in a document
    // For now, we'll return an empty list
    // TODO: Implement app tracking in a separate document

    return [];
  }
}
