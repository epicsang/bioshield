// lib/services/admin_service.dart
// Admin operations: user management, analytics, banner management
// FIXED: Better error handling and data fetching for real Firestore data

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============ USER ANALYTICS ============

  /// Get total user count
  Future<int> getTotalUsers() async {
    try {
      final snapshot = await _db.collection('users').get();
      print('📊 Total users found: ${snapshot.docs.length}');
      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting total users: $e');
      return 0;
    }
  }

  /// Get premium user count
  Future<int> getPremiumUsers() async {
    try {
      final snapshot = await _db.collection('users').get();
      int premiumCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final isPremium = data['membership']?['isPremium'] ?? false;
        if (isPremium) premiumCount++;
      }

      print('📊 Premium users found: $premiumCount');
      return premiumCount;
    } catch (e) {
      print('❌ Error getting premium users: $e');
      return 0;
    }
  }

  /// Get free user count
  Future<int> getFreeUsers() async {
    try {
      final total = await getTotalUsers();
      final premium = await getPremiumUsers();
      final free = total - premium;
      print('📊 Free users found: $free');
      return free;
    } catch (e) {
      print('❌ Error getting free users: $e');
      return 0;
    }
  }

  /// Get new signups today
  Future<int> getNewSignupsToday() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final snapshot = await _db.collection('users').get();
      int newSignups = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAtStr = data['createdAt'] as String?;

        if (createdAtStr != null) {
          try {
            // Handle both ISO8601 strings and Firestore timestamps
            DateTime createdAt;
            if (createdAtStr.contains('T')) {
              createdAt = DateTime.parse(createdAtStr);
            } else {
              continue; // Skip if format is unexpected
            }

            if (createdAt.isAfter(startOfDay)) {
              newSignups++;
            }
          } catch (e) {
            print('   ⚠️ Could not parse date: $createdAtStr');
            continue;
          }
        }
      }

      print('📊 New signups today: $newSignups');
      return newSignups;
    } catch (e) {
      print('❌ Error getting new signups: $e');
      return 0;
    }
  }

  /// Get all users with details
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      // Remove .orderBy() to avoid index/permission issues
      final snapshot = await _db.collection('users').get();

      print('📊 Fetching ${snapshot.docs.length} users...');

      final usersList = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'username': data['username'] ?? 'Unknown',
          'email': data['email'] ?? 'N/A',
          'isPremium': data['membership']?['isPremium'] ?? false,
          'accountStatus': data['accountStatus'] ?? 'active',
          'createdAt': data['createdAt'] ?? '',
          'role': (data['role'] == null || data['role'] == '') ? 'user' : data['role'],
        };
      }).toList();

      // Sort in memory instead of in Firestore query
      usersList.sort((a, b) {
        final aDate = a['createdAt'] as String;
        final bDate = b['createdAt'] as String;
        return bDate.compareTo(aDate); // Descending order (newest first)
      });

      print('✅ Users fetched and sorted');
      return usersList;
    } catch (e) {
      print('❌ Error getting all users: $e');
      return [];
    }
  }

  // ============ SCAN ANALYTICS ============

  /// Get total scans across all users
  Future<int> getTotalScans() async {
    try {
      int totalScans = 0;
      final users = await _db.collection('users').get();

      print('📊 Counting scans for ${users.docs.length} users...');

      for (var user in users.docs) {
        final scans = await _db
            .collection('users')
            .doc(user.id)
            .collection('scans')
            .get();
        totalScans += scans.docs.length;

        if (scans.docs.isNotEmpty) {
          print('   User ${user.id}: ${scans.docs.length} scans');
        }
      }

      print('📊 Total scans found: $totalScans');
      return totalScans;
    } catch (e) {
      print('❌ Error getting total scans: $e');
      return 0;
    }
  }

  /// Get scans performed today
  Future<int> getScansToday() async {
    try {
      int scansToday = 0;
      final users = await _db.collection('users').get();
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      print('📊 Counting today\'s scans (after ${startOfDay})...');

      for (var user in users.docs) {
        final scans = await _db
            .collection('users')
            .doc(user.id)
            .collection('scans')
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .get();

        scansToday += scans.docs.length;

        if (scans.docs.isNotEmpty) {
          print('   User ${user.id}: ${scans.docs.length} scans today');
        }
      }

      print('📊 Scans today: $scansToday');
      return scansToday;
    } catch (e) {
      print('❌ Error getting scans today: $e');
      return 0;
    }
  }

  /// Get average security score across all scans
  Future<double> getAverageSecurityScore() async {
    try {
      double totalScore = 0;
      int scanCount = 0;

      final users = await _db.collection('users').get();

      print('📊 Calculating average security score...');

      for (var user in users.docs) {
        final scans = await _db
            .collection('users')
            .doc(user.id)
            .collection('scans')
            .where('status', isEqualTo: 'completed')
            .get();

        for (var scan in scans.docs) {
          final data = scan.data();
          final score = data['riskScore'];

          if (score != null) {
            totalScore += (score is int) ? score.toDouble() : score as double;
            scanCount++;
          }
        }
      }

      final avgScore = scanCount > 0 ? totalScore / scanCount : 0.0;
      print('📊 Average security score: ${avgScore.toStringAsFixed(1)} (from $scanCount scans)');
      return avgScore;
    } catch (e) {
      print('❌ Error calculating average score: $e');
      return 0.0;
    }
  }

  /// Get vulnerability distribution
  Future<Map<String, int>> getVulnerabilityDistribution() async {
    try {
      Map<String, int> distribution = {
        'Low Risk (80-100)': 0,
        'Medium Risk (60-79)': 0,
        'High Risk (0-59)': 0,
      };

      final users = await _db.collection('users').get();

      print('📊 Calculating vulnerability distribution...');

      for (var user in users.docs) {
        final scans = await _db
            .collection('users')
            .doc(user.id)
            .collection('scans')
            .where('status', isEqualTo: 'completed')
            .get();

        for (var scan in scans.docs) {
          final data = scan.data();
          final scoreValue = data['riskScore'];

          if (scoreValue == null) continue;

          final score = (scoreValue is int) ? scoreValue : (scoreValue as double).toInt();

          if (score >= 80) {
            distribution['Low Risk (80-100)'] = distribution['Low Risk (80-100)']! + 1;
          } else if (score >= 60) {
            distribution['Medium Risk (60-79)'] = distribution['Medium Risk (60-79)']! + 1;
          } else {
            distribution['High Risk (0-59)'] = distribution['High Risk (0-59)']! + 1;
          }
        }
      }

      print('📊 Distribution: $distribution');
      return distribution;
    } catch (e) {
      print('❌ Error getting vulnerability distribution: $e');
      return {
        'Low Risk (80-100)': 0,
        'Medium Risk (60-79)': 0,
        'High Risk (0-59)': 0,
      };
    }
  }

  /// Get recent high-risk scans
  /// DEPRECATED: Replaced with anonymized vulnerability statistics for privacy
  Future<List<Map<String, dynamic>>> getHighRiskScans({int limit = 10}) async {
    // This method is no longer used - replaced with getVulnerabilityTypeDistribution
    return [];
  }

  /// Get vulnerability type distribution (anonymized)
  Future<Map<String, int>> getVulnerabilityTypeDistribution() async {
    try {
      Map<String, int> distribution = {
        'Timing Attack Risk': 0,
        'Low Sensor Entropy': 0,
        'Weak API Implementation': 0,
        'Multiple Issues': 0,
      };

      final users = await _db.collection('users').get();

      print('📊 Calculating vulnerability type distribution...');

      for (var user in users.docs) {
        final scans = await _db
            .collection('users')
            .doc(user.id)
            .collection('scans')
            .where('status', isEqualTo: 'completed')
            .get();

        for (var scan in scans.docs) {
          final data = scan.data();
          final scoreValue = data['riskScore'];

          if (scoreValue == null) continue;

          final score = (scoreValue is int) ? scoreValue : (scoreValue as double).toInt();

          // Categorize by score range
          if (score < 40) {
            distribution['Multiple Issues'] = distribution['Multiple Issues']! + 1;
          } else if (score < 50) {
            distribution['Timing Attack Risk'] = distribution['Timing Attack Risk']! + 1;
          } else if (score < 60) {
            distribution['Low Sensor Entropy'] = distribution['Low Sensor Entropy']! + 1;
          } else if (score < 70) {
            distribution['Weak API Implementation'] = distribution['Weak API Implementation']! + 1;
          }
          // Scores 70+ are not counted as vulnerabilities
        }
      }

      print('📊 Vulnerability types: $distribution');
      return distribution;
    } catch (e) {
      print('❌ Error getting vulnerability types: $e');
      return {
        'Timing Attack Risk': 0,
        'Low Sensor Entropy': 0,
        'Weak API Implementation': 0,
        'Multiple Issues': 0,
      };
    }
  }

  // ============ USER MANAGEMENT ============

  /// Update user role (Free/Premium/Admin)
  Future<void> updateUserRole(String uid, bool isPremium) async {
    try {
      await _db.collection('users').doc(uid).update({
        'membership.isPremium': isPremium,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Updated user $uid to ${isPremium ? "Premium" : "Free"}');
    } catch (e) {
      print('❌ Error updating user role: $e');
    }
  }

  /// Suspend user account
  Future<void> suspendUser(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'accountStatus': 'suspended',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Suspended user $uid');
    } catch (e) {
      print('❌ Error suspending user: $e');
    }
  }

  /// Activate user account
  Future<void> activateUser(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'accountStatus': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Activated user $uid');
    } catch (e) {
      print('❌ Error activating user: $e');
    }
  }

  /// Delete user account (admin action)
  Future<void> deleteUser(String uid) async {
    try {
      // Delete user's scans first
      final scans = await _db.collection('users').doc(uid).collection('scans').get();
      for (var scan in scans.docs) {
        await scan.reference.delete();
      }

      // Delete user document
      await _db.collection('users').doc(uid).delete();
      print('✅ Deleted user $uid and all their data');
    } catch (e) {
      print('❌ Error deleting user: $e');
    }
  }

  // ============ BANNER MANAGEMENT ============

  /// Get all advertisement banners
  Future<List<Map<String, dynamic>>> getAllBanners() async {
    try {
      final snapshot = await _db.collection('advertisementBanners').get();

      print('📊 Found ${snapshot.docs.length} banners');

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'bannerId': doc.id,
          'content': data['content'] ?? '',
          'startDate': data['startDate'] ?? '',
          'endDate': data['endDate'] ?? '',
          'status': data['status'] ?? 'inactive',
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting banners: $e');
      return [];
    }
  }

  /// Add new banner
  Future<void> addBanner({
    required String content,
    required String startDate,
    required String endDate,
  }) async {
    try {
      await _db.collection('advertisementBanners').add({
        'content': content,
        'startDate': startDate,
        'endDate': endDate,
        'status': 'active',
      });
      print('✅ Added new banner');
    } catch (e) {
      print('❌ Error adding banner: $e');
    }
  }

  /// Update existing banner
  Future<void> updateBanner({
    required String bannerId,
    required String content,
    required String startDate,
    required String endDate,
    required String status,
  }) async {
    try {
      await _db.collection('advertisementBanners').doc(bannerId).update({
        'content': content,
        'startDate': startDate,
        'endDate': endDate,
        'status': status,
      });
      print('✅ Updated banner $bannerId');
    } catch (e) {
      print('❌ Error updating banner: $e');
    }
  }

  /// Delete banner
  Future<void> deleteBanner(String bannerId) async {
    try {
      await _db.collection('advertisementBanners').doc(bannerId).delete();
      print('✅ Deleted banner $bannerId');
    } catch (e) {
      print('❌ Error deleting banner: $e');
    }
  }

  // ============ USER GROWTH DATA (For Charts) ============

  /// Get user signups per day for the last 7 days
  Future<List<Map<String, dynamic>>> getUserGrowthData({int days = 7}) async {
    try {
      List<Map<String, dynamic>> growthData = [];
      final allUsers = await _db.collection('users').get();

      print('📊 Calculating user growth for last $days days...');

      for (int i = days - 1; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        int signupsOnDay = 0;

        for (var userDoc in allUsers.docs) {
          final data = userDoc.data();
          final createdAtStr = data['createdAt'] as String?;

          if (createdAtStr != null) {
            try {
              final createdAt = DateTime.parse(createdAtStr);
              if (createdAt.isAfter(startOfDay) && createdAt.isBefore(endOfDay)) {
                signupsOnDay++;
              }
            } catch (e) {
              // Skip invalid dates
              continue;
            }
          }
        }

        growthData.add({
          'date': '${date.month}/${date.day}',
          'signups': signupsOnDay,
        });

        print('   ${date.month}/${date.day}: $signupsOnDay signups');
      }

      return growthData;
    } catch (e) {
      print('❌ Error getting user growth data: $e');
      return [];
    }
  }

  // ============ CHECK IF USER IS ADMIN ============

  /// Check if current user is admin
  Future<bool> isAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No user logged in');
        return false;
      }

      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        print('⚠️ User document not found');
        return false;
      }

      final data = doc.data();
      final role = (data?['role'] == null || data?['role'] == '') ? 'user' : data?['role'];

      print('🔍 User role: $role');
      return role == 'admin';
    } catch (e) {
      print('❌ Error checking admin status: $e');
      return false;
    }
  }
}