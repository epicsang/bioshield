import 'package:firebase_auth/firebase_auth.dart';

/// Service to get the current Firebase Auth user ID
/// This ID is used to link hooked apps to this BioShield user
class UserIdService {
  /// Get the current Firebase Auth user's UID
  /// This is the persistent ID that links hooked apps to this user
  static Future<String> getUserId() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      print('[UserIdService] ERROR: No user logged in');
      throw Exception('User not authenticated. Please log in first.');
    }

    final uid = user.uid;
    print('[UserIdService] Retrieved Firebase Auth UID: $uid');

    return uid;
  }

  /// Get user ID synchronously (returns null if not logged in)
  static String? getUserIdSync() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  /// Check if user is authenticated
  static bool isAuthenticated() {
    return FirebaseAuth.instance.currentUser != null;
  }
}
