// lib/services/scan_results_service.dart
// Service to read and parse biometric security scan results from analyzed apps

import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScanResultsService {
  /// Security scan results location
  /// Changed to /storage/emulated/0/BioShield for dedicated folder
  static const String RESULTS_PATH = '/storage/emulated/0/BioShield';

  /// Get all security scan result files
  Future<List<File>> getScanResultFiles() async {
    try {
      // Check storage permission - silently return empty list if not granted
      // (This is expected on first launch before user runs their first scan)
      if (!await _checkStoragePermission()) {
        return [];
      }

      final directory = Directory(RESULTS_PATH);
      if (!await directory.exists()) {
        return [];
      }

      // Find all biometric_scan_*.json files
      final files = await directory
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

      // Sort by modification time (newest first)
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return files;
    } catch (e) {
      // Only log actual errors (not permission denials)
      print('Error accessing scan result files: $e');
      return [];
    }
  }

  /// Get the most recent scan result
  Future<FridaScanResult?> getLatestScanResult() async {
    try {
      final files = await getScanResultFiles();
      if (files.isEmpty) {
        return null;
      }

      // Read the most recent file
      final latestFile = files.first;
      return await parseScanResult(latestFile);
    } catch (e) {
      print('Error getting latest scan result: $e');
      return null;
    }
  }

  /// Get the latest unimported scan result (for free users with scan limits)
  /// This prevents users from re-importing the same scan after daily reset
  Future<FridaScanResult?> getLatestUnimportedScanResult(String userId) async {
    try {
      // Get all scan files
      final files = await getScanResultFiles();
      if (files.isEmpty) {
        return null;
      }

      // Load imported scan IDs from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final importedIds = List<String>.from(doc.data()?['importedScanIds'] ?? []);

      // Find first unimported scan
      for (final file in files) {
        final result = await parseScanResult(file);
        if (result != null && !importedIds.contains(result.metadata.scanId)) {
          return result;
        }
      }

      // All scans have been imported
      return null;
    } catch (e) {
      print('Error getting latest unimported scan result: $e');
      return null;
    }
  }

  /// Mark a scan as imported in Firestore
  Future<void> markScanAsImported(String userId, String scanId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'importedScanIds': FieldValue.arrayUnion([scanId]),
      });
    } catch (e) {
      print('Error marking scan as imported: $e');
      // If field doesn't exist, create it
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set({
          'importedScanIds': [scanId],
        }, SetOptions(merge: true));
      } catch (e2) {
        print('Error creating importedScanIds field: $e2');
      }
    }
  }

  /// Check if there are any unimported scans available
  Future<bool> hasUnimportedScans(String userId) async {
    final unimportedScan = await getLatestUnimportedScanResult(userId);
    return unimportedScan != null;
  }

  /// Parse a scan result JSON file
  Future<FridaScanResult?> parseScanResult(File file) async {
    try {
      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      return FridaScanResult.fromJson(json);
    } catch (e) {
      print('Error parsing scan result: $e');
      return null;
    }
  }

  /// Check storage permission
  Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      // Check both storage and manageExternalStorage for Android 11+ compatibility
      final storageStatus = await Permission.storage.status;
      final manageStorageStatus = await Permission.manageExternalStorage.status;

      // Permission is granted if either is granted
      return storageStatus.isGranted || manageStorageStatus.isGranted;
    }
    return true;
  }

  /// Delete a scan result file
  Future<bool> deleteScanResult(File file) async {
    try {
      await file.delete();
      return true;
    } catch (e) {
      print('Error deleting scan result: $e');
      return false;
    }
  }

  /// Delete all scan results
  Future<int> deleteAllScanResults() async {
    try {
      final files = await getScanResultFiles();
      int count = 0;
      for (final file in files) {
        if (await deleteScanResult(file)) {
          count++;
        }
      }
      return count;
    } catch (e) {
      print('Error deleting all scan results: $e');
      return 0;
    }
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

class FridaScanResult {
  final ScanMetadata metadata;
  final List<Vulnerability> vulnerabilities;
  final TimingData timingData;
  final List<APIFinding> apiFindings;
  final List<CryptoFinding> cryptoFindings;
  final List<StorageFinding> storageFindings;
  final List<NetworkFinding> networkFindings;
  final List<MemoryFinding> memoryFindings;

  FridaScanResult({
    required this.metadata,
    required this.vulnerabilities,
    required this.timingData,
    required this.apiFindings,
    required this.cryptoFindings,
    required this.storageFindings,
    required this.networkFindings,
    required this.memoryFindings,
  });

  factory FridaScanResult.fromJson(Map<String, dynamic> json) {
    return FridaScanResult(
      metadata: ScanMetadata.fromJson(json['metadata'] ?? {}),
      vulnerabilities: (json['vulnerabilities'] as List<dynamic>?)
          ?.map((v) => Vulnerability.fromJson(v))
          .toList() ?? [],
      timingData: TimingData.fromJson(json['timingData'] ?? {}),
      apiFindings: (json['apiFindings'] as List<dynamic>?)
          ?.map((f) => APIFinding.fromJson(f))
          .toList() ?? [],
      cryptoFindings: (json['cryptoFindings'] as List<dynamic>?)
          ?.map((f) => CryptoFinding.fromJson(f))
          .toList() ?? [],
      storageFindings: (json['storageFindings'] as List<dynamic>?)
          ?.map((f) => StorageFinding.fromJson(f))
          .toList() ?? [],
      networkFindings: (json['networkFindings'] as List<dynamic>?)
          ?.map((f) => NetworkFinding.fromJson(f))
          .toList() ?? [],
      memoryFindings: (json['memoryFindings'] as List<dynamic>?)
          ?.map((f) => MemoryFinding.fromJson(f))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metadata': metadata.toJson(),
      'vulnerabilities': vulnerabilities.map((v) => v.toJson()).toList(),
      'timingData': timingData.toJson(),
      'apiFindings': apiFindings.map((f) => f.toJson()).toList(),
      'cryptoFindings': cryptoFindings.map((f) => f.toJson()).toList(),
      'storageFindings': storageFindings.map((f) => f.toJson()).toList(),
      'networkFindings': networkFindings.map((f) => f.toJson()).toList(),
      'memoryFindings': memoryFindings.map((f) => f.toJson()).toList(),
    };
  }

  /// Get risk score (0-100)
  int getRiskScore() {
    return metadata.riskScore ?? _calculateRiskScore();
  }

  int _calculateRiskScore() {
    int score = 100;
    for (final vuln in vulnerabilities) {
      switch (vuln.severity) {
        case 'CRITICAL':
          score -= 25;
          break;
        case 'HIGH':
          score -= 15;
          break;
        case 'MEDIUM':
          score -= 8;
          break;
        case 'LOW':
          score -= 3;
          break;
      }
    }
    return score.clamp(0, 100);
  }

  /// Get vulnerability counts by severity
  Map<String, int> getVulnerabilityCounts() {
    final counts = {
      'CRITICAL': 0,
      'HIGH': 0,
      'MEDIUM': 0,
      'LOW': 0,
    };

    for (final vuln in vulnerabilities) {
      final severity = vuln.severity ?? 'LOW';
      counts[severity] = (counts[severity] ?? 0) + 1;
    }

    return counts;
  }

  /// Get overall security status
  String getSecurityStatus() {
    final score = getRiskScore();
    if (score >= 80) return 'SECURE';
    if (score >= 60) return 'MODERATE';
    if (score >= 40) return 'VULNERABLE';
    return 'CRITICAL';
  }
}

class ScanMetadata {
  final String? scanId;
  final String? timestamp;
  final double? scanDuration;
  final String? targetPackage;
  final String? appVersion;
  final int? targetSdk;
  final int? riskScore;
  final DeviceInfo? deviceInfo;

  ScanMetadata({
    this.scanId,
    this.timestamp,
    this.scanDuration,
    this.targetPackage,
    this.appVersion,
    this.targetSdk,
    this.riskScore,
    this.deviceInfo,
  });

  factory ScanMetadata.fromJson(Map<String, dynamic> json) {
    return ScanMetadata(
      scanId: json['scanId'] as String?,
      timestamp: json['timestamp'] as String?,
      scanDuration: (json['scanDuration'] as num?)?.toDouble(),
      targetPackage: json['targetPackage'] as String?,
      appVersion: json['appVersion'] as String?,
      targetSdk: json['targetSdk'] as int?,
      riskScore: json['riskScore'] as int?,
      deviceInfo: json['deviceInfo'] != null
          ? DeviceInfo.fromJson(json['deviceInfo'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scanId': scanId,
      'timestamp': timestamp,
      'scanDuration': scanDuration,
      'targetPackage': targetPackage,
      'appVersion': appVersion,
      'targetSdk': targetSdk,
      'riskScore': riskScore,
      'deviceInfo': deviceInfo?.toJson(),
    };
  }

  DateTime? get scanDate {
    if (timestamp == null) return null;
    try {
      return DateTime.parse(timestamp!);
    } catch (e) {
      return null;
    }
  }
}

class DeviceInfo {
  final String? manufacturer;
  final String? model;
  final String? device;
  final String? androidVersion;
  final int? sdkInt;
  final String? brand;
  final String? fingerprint;

  DeviceInfo({
    this.manufacturer,
    this.model,
    this.device,
    this.androidVersion,
    this.sdkInt,
    this.brand,
    this.fingerprint,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      device: json['device'] as String?,
      androidVersion: json['androidVersion'] as String?,
      sdkInt: json['sdkInt'] as int?,
      brand: json['brand'] as String?,
      fingerprint: json['fingerprint'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'manufacturer': manufacturer,
      'model': model,
      'device': device,
      'androidVersion': androidVersion,
      'sdkInt': sdkInt,
      'brand': brand,
      'fingerprint': fingerprint,
    };
  }
}

class Vulnerability {
  final String? id;
  final String? type;
  final String? severity;
  final String? category;
  final String? title;
  final String? description;
  final Map<String, dynamic>? technicalDetails;
  final String? impact;
  final String? mitigation;
  final Map<String, dynamic>? codeSnippet;
  final List<String>? references;
  final String? detectedAt;

  Vulnerability({
    this.id,
    this.type,
    this.severity,
    this.category,
    this.title,
    this.description,
    this.technicalDetails,
    this.impact,
    this.mitigation,
    this.codeSnippet,
    this.references,
    this.detectedAt,
  });

  factory Vulnerability.fromJson(Map<String, dynamic> json) {
    return Vulnerability(
      id: json['id'] as String?,
      type: json['type'] as String?,
      severity: json['severity'] as String?,
      category: json['category'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      technicalDetails: json['technicalDetails'] as Map<String, dynamic>?,
      impact: json['impact'] as String?,
      mitigation: json['mitigation'] as String?,
      codeSnippet: json['codeSnippet'] as Map<String, dynamic>?,
      references: (json['references'] as List<dynamic>?)
          ?.map((r) => r.toString())
          .toList(),
      detectedAt: json['detectedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'severity': severity,
      'category': category,
      'title': title,
      'description': description,
      'technicalDetails': technicalDetails,
      'impact': impact,
      'mitigation': mitigation,
      'codeSnippet': codeSnippet,
      'references': references,
      'detectedAt': detectedAt,
    };
  }
}

class TimingData {
  final List<TimingAttempt> attempts;
  final List<int> successTimes;
  final List<int> failureTimes;
  final TimingAnalysis? analysis;

  TimingData({
    required this.attempts,
    required this.successTimes,
    required this.failureTimes,
    this.analysis,
  });

  factory TimingData.fromJson(Map<String, dynamic> json) {
    return TimingData(
      attempts: (json['attempts'] as List<dynamic>?)
          ?.map((a) => TimingAttempt.fromJson(a))
          .toList() ?? [],
      successTimes: (json['successTimes'] as List<dynamic>?)
          ?.map((t) => t as int)
          .toList() ?? [],
      failureTimes: (json['failureTimes'] as List<dynamic>?)
          ?.map((t) => t as int)
          .toList() ?? [],
      analysis: json['analysis'] != null
          ? TimingAnalysis.fromJson(json['analysis'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attempts': attempts.map((a) => a.toJson()).toList(),
      'successTimes': successTimes,
      'failureTimes': failureTimes,
      'analysis': analysis?.toJson(),
    };
  }
}

class TimingAttempt {
  final String result;
  final int duration;
  final String timestamp;
  final int? errorCode;
  final String? errorMessage;

  TimingAttempt({
    required this.result,
    required this.duration,
    required this.timestamp,
    this.errorCode,
    this.errorMessage,
  });

  factory TimingAttempt.fromJson(Map<String, dynamic> json) {
    return TimingAttempt(
      result: json['result'] as String,
      duration: json['duration'] as int,
      timestamp: json['timestamp'] as String,
      errorCode: json['errorCode'] as int?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'result': result,
      'duration': duration,
      'timestamp': timestamp,
      'errorCode': errorCode,
      'errorMessage': errorMessage,
    };
  }
}

class TimingAnalysis {
  final int successCount;
  final int failureCount;
  final int successAverage;
  final int failureAverage;
  final int successStdDev;
  final int failureStdDev;
  final int timingDifference;
  final String percentDifference;
  final int sampleSize;

  TimingAnalysis({
    required this.successCount,
    required this.failureCount,
    required this.successAverage,
    required this.failureAverage,
    required this.successStdDev,
    required this.failureStdDev,
    required this.timingDifference,
    required this.percentDifference,
    required this.sampleSize,
  });

  factory TimingAnalysis.fromJson(Map<String, dynamic> json) {
    return TimingAnalysis(
      successCount: json['successCount'] as int? ?? 0,
      failureCount: json['failureCount'] as int? ?? 0,
      successAverage: json['successAverage'] as int? ?? 0,
      failureAverage: json['failureAverage'] as int? ?? 0,
      successStdDev: json['successStdDev'] as int? ?? 0,
      failureStdDev: json['failureStdDev'] as int? ?? 0,
      timingDifference: json['timingDifference'] as int? ?? 0,
      percentDifference: json['percentDifference']?.toString() ?? '0',
      sampleSize: json['sampleSize'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'successCount': successCount,
      'failureCount': failureCount,
      'successAverage': successAverage,
      'failureAverage': failureAverage,
      'successStdDev': successStdDev,
      'failureStdDev': failureStdDev,
      'timingDifference': timingDifference,
      'percentDifference': percentDifference,
      'sampleSize': sampleSize,
    };
  }
}

class APIFinding {
  final String type;
  final String category;
  final String? title;
  final String? description;
  final Map<String, dynamic>? details;
  final String? timestamp;

  APIFinding({
    required this.type,
    required this.category,
    this.title,
    this.description,
    this.details,
    this.timestamp,
  });

  factory APIFinding.fromJson(Map<String, dynamic> json) {
    return APIFinding(
      type: json['type'] as String? ?? 'UNKNOWN',
      category: json['category'] as String? ?? 'General',
      title: json['title'] as String?,
      description: json['description'] as String?,
      details: json['details'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'category': category,
      'title': title,
      'description': description,
      'details': details,
      'timestamp': timestamp,
    };
  }
}

class CryptoFinding {
  final String type;
  final String category;
  final String? title;
  final String? description;
  final String? algorithm;
  final String? fileName;
  final String? timestamp;

  CryptoFinding({
    required this.type,
    required this.category,
    this.title,
    this.description,
    this.algorithm,
    this.fileName,
    this.timestamp,
  });

  factory CryptoFinding.fromJson(Map<String, dynamic> json) {
    return CryptoFinding(
      type: json['type'] as String? ?? 'UNKNOWN',
      category: json['category'] as String? ?? 'General',
      title: json['title'] as String?,
      description: json['description'] as String?,
      algorithm: json['algorithm'] as String?,
      fileName: json['fileName'] as String?,
      timestamp: json['timestamp'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'category': category,
      'title': title,
      'description': description,
      'algorithm': algorithm,
      'fileName': fileName,
      'timestamp': timestamp,
    };
  }
}

class StorageFinding {
  final String type;
  final String category;
  final String? title;
  final String? key;
  final String? fileName;
  final String? timestamp;

  StorageFinding({
    required this.type,
    required this.category,
    this.title,
    this.key,
    this.fileName,
    this.timestamp,
  });

  factory StorageFinding.fromJson(Map<String, dynamic> json) {
    return StorageFinding(
      type: json['type'] as String? ?? 'UNKNOWN',
      category: json['category'] as String? ?? 'General',
      title: json['title'] as String?,
      key: json['key'] as String?,
      fileName: json['fileName'] as String?,
      timestamp: json['timestamp'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'category': category,
      'title': title,
      'key': key,
      'fileName': fileName,
      'timestamp': timestamp,
    };
  }
}

class NetworkFinding {
  final String type;
  final String url;
  final String? timestamp;

  NetworkFinding({
    required this.type,
    required this.url,
    this.timestamp,
  });

  factory NetworkFinding.fromJson(Map<String, dynamic> json) {
    return NetworkFinding(
      type: json['type'] as String? ?? 'CONNECTION',
      url: json['url'] as String? ?? '',
      timestamp: json['timestamp'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'url': url,
      'timestamp': timestamp,
    };
  }
}

class MemoryFinding {
  final String type;
  final String className;
  final String? timestamp;

  MemoryFinding({
    required this.type,
    required this.className,
    this.timestamp,
  });

  factory MemoryFinding.fromJson(Map<String, dynamic> json) {
    return MemoryFinding(
      type: json['type'] as String? ?? 'UNKNOWN',
      className: json['className'] as String? ?? '',
      timestamp: json['timestamp'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'className': className,
      'timestamp': timestamp,
    };
  }
}
