import 'dart:io';
import 'package:bioshield/services/gadget_file_reader_service.dart';
import 'package:bioshield/services/firebase_log_upload_service.dart';

/// Comprehensive scan service that orchestrates the full scan workflow
///
/// Simplified Workflow (File-based):
/// 1. Read logs from shared storage (/storage/emulated/0/BioShield/logs/)
/// 2. Generate scan report from logs
/// 3. Upload logs and report to Firebase
/// 4. Delete processed log files
/// 5. Return scan report to UI
///
/// No ContentProvider IPC needed - just simple file reading!
class ComprehensiveScanService {
  final _fileReaderService = GadgetFileReaderService();
  final _firebaseService = FirebaseLogUploadService();

  static const String resultsPath = '/storage/emulated/0/BioShield';

  /// Perform complete scan: read logs, upload to Firebase, generate report
  ///
  /// [packageName] - Package name of the hooked app (optional, for Firebase tagging)
  /// [uploadToFirebase] - Whether to upload logs to Firebase (default: true)
  /// Returns scan report with risk assessment
  Future<ScanResult> performCompleteScan(String packageName, {bool uploadToFirebase = true}) async {
    try {
      // Step 1: Read logs from shared storage
      final logs = await _fileReaderService.readAllLogs();

      if (logs.isEmpty) {
        return ScanResult(
          success: false,
          error: 'No logs found. Please trigger biometric authentication in the hooked app first.',
          packageName: packageName,
        );
      }

      // Step 2: Generate scan report from logs
      final report = _generateReport(logs);

      // Step 3: Upload to Firebase (if enabled)
      if (uploadToFirebase) {
        final uploadedCount = await _firebaseService.uploadLogEventsBatch(packageName, logs);
        await _firebaseService.uploadAndUpdateLatestReport(packageName, report);
      }

      // Step 4: Delete processed log files
      await _fileReaderService.clearLogs();

      // Step 5: Delete local scan result files
      await _deleteLocalScanResults(packageName);

      return ScanResult(
        success: true,
        report: report,
        logsCount: logs.length,
        uploadedToFirebase: uploadToFirebase,
        packageName: packageName,
      );
    } catch (e) {
      return ScanResult(
        success: false,
        error: e.toString(),
        packageName: packageName,
      );
    }
  }

  /// Quick scan: read logs and generate report without Firebase upload
  Future<ScanResult> performQuickScan(String packageName) async {
    return performCompleteScan(packageName, uploadToFirebase: false);
  }

  /// Read logs only without generating report or uploading
  Future<List<Map<String, dynamic>>> readLogsOnly(String packageName) async {
    try {
      return await _fileReaderService.readAllLogs();
    } catch (e) {
      return [];
    }
  }

  /// Generate report from logs
  Map<String, dynamic> _generateReport(List<Map<String, dynamic>> logs) {
    int successCount = 0;
    int failCount = 0;
    int errorCount = 0;
    List<double> timings = [];

    for (var log in logs) {
      final success = log['success'] ?? false;
      final totalLatency = log['totalLatency'];

      if (success == true) {
        successCount++;
      } else {
        failCount++;
      }

      if (totalLatency != null) {
        timings.add((totalLatency is int) ? totalLatency.toDouble() : totalLatency);
      }
    }

    // Calculate risk score
    int riskScore = 0;
    if (failCount > successCount) riskScore += 30;
    if (errorCount > 0) riskScore += 20;
    if (timings.isNotEmpty) {
      final avgTiming = timings.reduce((a, b) => a + b) / timings.length;
      if (avgTiming < 100) riskScore += 40; // Suspiciously fast
      if (avgTiming > 5000) riskScore += 20; // Suspiciously slow
    }

    riskScore = riskScore.clamp(0, 100);

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'totalEvents': logs.length,
      'successCount': successCount,
      'failCount': failCount,
      'errorCount': errorCount,
      'riskScore': riskScore,
      'riskLevel': riskScore > 70 ? 'HIGH' : riskScore > 40 ? 'MEDIUM' : 'LOW',
      'averageTiming': timings.isNotEmpty ? timings.reduce((a, b) => a + b) / timings.length : 0,
    };
  }

  /// Delete local scan result files
  Future<int> _deleteLocalScanResults([String? packageName]) async {
    try {
      final directory = Directory(resultsPath);
      if (!await directory.exists()) {
        return 0;
      }

      final files = await directory
          .list()
          .where((entity) {
            if (entity is File) {
              final name = entity.path.split(Platform.pathSeparator).last;
              return name.startsWith('biometric_scan_') && name.endsWith('.json');
            }
            return false;
          })
          .cast<File>()
          .toList();

      int deletedCount = 0;
      for (final file in files) {
        try {
          await file.delete();
          deletedCount++;
        } catch (e) {
          // Ignore deletion errors
        }
      }

      return deletedCount;
    } catch (e) {
      return 0;
    }
  }

  /// Get scan history from Firebase
  Future<List<Map<String, dynamic>>> getScanHistory(String packageName, {int limit = 10}) async {
    try {
      return await _firebaseService.getReportsForApp(packageName, limit: limit);
    } catch (e) {
      return [];
    }
  }

  /// Get latest scan report from Firebase
  Future<Map<String, dynamic>?> getLatestScanReport(String packageName) async {
    try {
      return await _firebaseService.getLatestReport(packageName);
    } catch (e) {
      return null;
    }
  }

  /// Clear all logs
  Future<void> clearAllData(String packageName, {bool clearFirebase = true}) async {
    try {
      // Clear local logs
      await _fileReaderService.clearLogs();

      // Clear Firebase data
      if (clearFirebase) {
        await _firebaseService.clearLogsForApp(packageName);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get upload statistics from Firebase
  Future<Map<String, dynamic>> getUploadStats(String packageName) async {
    try {
      return await _firebaseService.getUploadStats(packageName);
    } catch (e) {
      return {
        'totalLogs': 0,
        'totalReports': 0,
        'packageName': packageName,
      };
    }
  }
}

/// Result of a scan operation
class ScanResult {
  final bool success;
  final Map<String, dynamic>? report;
  final int? logsCount;
  final bool uploadedToFirebase;
  final String? error;
  final String packageName;

  ScanResult({
    required this.success,
    this.report,
    this.logsCount,
    this.uploadedToFirebase = false,
    this.error,
    required this.packageName,
  });

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'report': report,
      'logsCount': logsCount,
      'uploadedToFirebase': uploadedToFirebase,
      'error': error,
      'packageName': packageName,
    };
  }

  @override
  String toString() {
    if (!success) {
      return 'ScanResult{success: false, error: $error}';
    }
    return 'ScanResult{success: true, logsCount: $logsCount, riskLevel: ${report?['riskLevel']}, uploaded: $uploadedToFirebase}';
  }
}
