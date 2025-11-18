// lib/services/scan_limit_service.dart
// Service to enforce free tier scan limits (3 reports per 24 hours)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class ScanLimitService {
  static const int freeTierLimit = 3;
  static const int limitWindowHours = 24;
  static const String resultsPath = '/storage/emulated/0/BioShield';

  /// Check if user can import a new scan (free tier: 3 scans per 24 hours)
  Future<ScanLimitResult> canImportScan(String userId, bool isPremium) async {
    // Premium users have unlimited scans
    if (isPremium) {
      return ScanLimitResult(
        canImport: true,
        remainingScans: -1, // Unlimited
        hoursUntilReset: 0,
      );
    }

    try {
      // Get user's scan history from Firestore
      final now = DateTime.now();
      final windowStart = now.subtract(const Duration(hours: limitWindowHours));

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('scans')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(windowStart))
          .get();

      final recentScansCount = querySnapshot.docs.length;

      if (recentScansCount >= freeTierLimit) {
        // Calculate hours until reset
        if (querySnapshot.docs.isNotEmpty) {
          // Get the oldest scan in the window
          final oldestScan = querySnapshot.docs
              .map((doc) => (doc.data()['timestamp'] as Timestamp).toDate())
              .reduce((a, b) => a.isBefore(b) ? a : b);

          final resetTime = oldestScan.add(const Duration(hours: limitWindowHours));
          final hoursUntilReset = resetTime.difference(now).inHours;

          return ScanLimitResult(
            canImport: false,
            remainingScans: 0,
            hoursUntilReset: hoursUntilReset > 0 ? hoursUntilReset : 0,
          );
        }

        return ScanLimitResult(
          canImport: false,
          remainingScans: 0,
          hoursUntilReset: 0,
        );
      }

      return ScanLimitResult(
        canImport: true,
        remainingScans: freeTierLimit - recentScansCount,
        hoursUntilReset: 0,
      );
    } catch (e) {
      print('Error checking scan limit: $e');
      // On error, allow the scan (fail open)
      return ScanLimitResult(
        canImport: true,
        remainingScans: freeTierLimit,
        hoursUntilReset: 0,
      );
    }
  }

  /// Clean up old local scan files (older than 24 hours) and upload last 3 to Firebase
  Future<CleanupResult> cleanupOldScans(String userId) async {
    try {
      final directory = Directory(resultsPath);
      if (!await directory.exists()) {
        return CleanupResult(success: false, deletedCount: 0, message: 'BioShield directory not found');
      }

      // Get all scan files
      final allFiles = await directory
          .list()
          .where((entity) {
            if (entity is File) {
              final name = entity.path.split('/').last;
              return name.startsWith('biometric_scan_') && name.endsWith('.json');
            }
            return false;
          })
          .cast<File>()
          .toList();

      if (allFiles.isEmpty) {
        return CleanupResult(success: true, deletedCount: 0, message: 'No scan files to clean up');
      }

      // Sort by modification time (newest first)
      allFiles.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: limitWindowHours));

      // Find files older than 24 hours
      final oldFiles = allFiles.where((file) {
        final stat = file.statSync();
        return stat.modified.isBefore(cutoffTime);
      }).toList();

      // Delete old files
      int deletedCount = 0;
      for (final file in oldFiles) {
        try {
          await file.delete();
          deletedCount++;
        } catch (e) {
          print('Error deleting file ${file.path}: $e');
        }
      }

      return CleanupResult(
        success: true,
        deletedCount: deletedCount,
        message: 'Cleaned up $deletedCount old scan files',
      );
    } catch (e) {
      print('Error during cleanup: $e');
      return CleanupResult(
        success: false,
        deletedCount: 0,
        message: 'Error during cleanup: $e',
      );
    }
  }

  /// Get scan limit status for display
  Future<String> getScanLimitStatus(String userId, bool isPremium) async {
    final result = await canImportScan(userId, isPremium);

    if (isPremium) {
      return 'Unlimited scans (Premium)';
    }

    if (result.canImport) {
      return '${result.remainingScans}/3 scans remaining today';
    } else {
      return 'Scan limit reached. Reset in ${result.hoursUntilReset}h';
    }
  }
}

/// Result of checking scan limits
class ScanLimitResult {
  final bool canImport;
  final int remainingScans; // -1 for unlimited (premium)
  final int hoursUntilReset;

  ScanLimitResult({
    required this.canImport,
    required this.remainingScans,
    required this.hoursUntilReset,
  });
}

/// Result of cleanup operation
class CleanupResult {
  final bool success;
  final int deletedCount;
  final String message;

  CleanupResult({
    required this.success,
    required this.deletedCount,
    required this.message,
  });
}
