// lib/services/frida_log_processor.dart
// Processes encrypted Frida Gadget logs from hooked apps
// - Decrypts AES-256-GCM encrypted logs
// - Extracts 12 ML features for spoof/anomaly detection
// - Uses TFLite ML models for spoof/anomaly detection
// - Uses rule-based side-channel analysis
// - Enforces free tier limits (3 scans per 24h)
// - Uploads processed data to Firebase

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'ml_inference_service.dart';

class FridaLogProcessor {
  // Encryption key matching Frida script
  static const String AES_KEY_B64 = "W7Yy9Np3F2e8Dqz0pY6Qv0T92oLk12BxVZtq8lZhg7s=";
  static final List<int> IV = List.filled(12, 0); // 12 bytes of zeros

  // Log file path (matching Frida script)
  static const String LOG_PATH = "/storage/emulated/0/Download/BioShield/logs.jsonl";

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Decrypt a single Base64-encoded AES-GCM ciphertext
  Future<String> _decryptLog(String encryptedBase64) async {
    try {
      // Decode the Base64 key and ciphertext
      final keyBytes = base64.decode(AES_KEY_B64);
      final ciphertextWithTag = base64.decode(encryptedBase64);

      // Create AES-GCM cipher
      final algorithm = AesGcm.with256bits();
      final secretKey = SecretKey(keyBytes);
      final nonce = IV;

      // Split ciphertext and MAC tag
      // AES-GCM tag is 16 bytes at the end
      final ciphertext = ciphertextWithTag.sublist(0, ciphertextWithTag.length - 16);
      final macBytes = ciphertextWithTag.sublist(ciphertextWithTag.length - 16);

      // Decrypt
      final secretBox = SecretBox(
        ciphertext,
        nonce: nonce,
        mac: Mac(macBytes),
      );

      final clearBytes = await algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return utf8.decode(clearBytes);
    } catch (e) {
      print('[FridaLogProcessor] Decryption failed: $e');
      return '';
    }
  }

  /// Read and decrypt all logs from the file
  Future<List<Map<String, dynamic>>> readAndDecryptLogs() async {
    final List<Map<String, dynamic>> logs = [];

    try {
      final file = File(LOG_PATH);

      if (!await file.exists()) {
        print('[FridaLogProcessor] No log file found at $LOG_PATH');
        return logs;
      }

      final lines = await file.readAsLines();
      print('[FridaLogProcessor] Found ${lines.length} encrypted log entries');

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        try {
          // Decrypt the line
          final decrypted = await _decryptLog(line);

          if (decrypted.isNotEmpty) {
            // Parse JSON
            final logObj = json.decode(decrypted) as Map<String, dynamic>;
            logs.add(logObj);
          }
        } catch (e) {
          print('[FridaLogProcessor] Failed to process line $i: $e');
        }
      }

      print('[FridaLogProcessor] Decrypted ${logs.length} logs successfully');
      return logs;

    } catch (e) {
      print('[FridaLogProcessor] Error reading log file: $e');
      return logs;
    }
  }

  /// Extract 12 ML features from raw log events
  /// Returns Map with features for spoof detector and anomaly detector
  /// Now includes side-channel attack detection
  Map<String, dynamic> extractMLFeatures(List<Map<String, dynamic>> logs, String packageName) {
    if (logs.isEmpty) {
      return _getDefaultFeatures(packageName);
    }

    // Separate events by type
    final authStartEvents = logs.where((log) =>
      log['event'] == 'auth_started' ||
      log['event'] == 'androidx_auth_started' ||
      log['event'] == 'fingerprint_auth_started'
    ).toList();

    final successEvents = logs.where((log) => log['event'] == 'success').toList();
    final failedEvents = logs.where((log) => log['event'] == 'failed').toList();
    final errorEvents = logs.where((log) => log['event'] == 'error').toList();

    // Side-channel attack detection
    final sideChannelAnalysis = _detectSideChannelAttacks(logs);

    // Calculate timing features
    final timingFeatures = _calculateTimingFeatures(logs);

    // Feature 1-4: Latency and duration metrics
    final sensorLatency = timingFeatures['sensor_latency'] ?? 0.0;
    final detectionLatency = timingFeatures['detection_latency'] ?? 0.0;
    final completionLatency = timingFeatures['completion_latency'] ?? 0.0;
    final totalDuration = timingFeatures['total_duration'] ?? 0.0;

    // Feature 5: Retry count (failed + error events)
    final retryCount = failedEvents.length + errorEvents.length;

    // Feature 6: Failure reason (encoded)
    // 0=success, 1=user_canceled, 2=timeout, 3=lockout, 4=no_biometric, 5=other
    int failureReason = 0;
    if (errorEvents.isNotEmpty) {
      final lastError = errorEvents.last;
      final errorCode = lastError['errorCode'] ?? 0;
      failureReason = _encodeErrorCode(errorCode);
    }

    // Feature 7-9: System metrics (mock values for now - can be enhanced with device_info_plus)
    final cpuLoad = _estimateCPULoad(logs);
    final thermalState = 0; // 0=normal, 1=warm, 2=hot (requires native integration)
    final screenState = 1; // 1=on, 0=off (requires native integration)

    // Feature 10: Entropy (timing pattern randomness)
    final entropy = _calculateEntropy(logs);

    // Feature 11: hasCrypto (check if CryptoObject was used)
    final hasCrypto = authStartEvents.any((log) => log['hasCrypto'] == true) ? 1 : 0;

    // Feature 12: networkFlag (check for suspicious network activity from logs)
    final networkFlag = logs.any((log) => log['networkFlag'] == 1 || log['networkFlag'] == true) ? 1 : 0;

    // Temporal features for anomaly detector
    final now = DateTime.now();
    final timeOfDay = now.hour + (now.minute / 60.0); // 0.0-23.99
    final dayOfWeek = now.weekday; // 1=Monday, 7=Sunday

    return {
      // Raw event counts
      'total_events': logs.length,
      'success_count': successEvents.length,
      'failed_count': failedEvents.length,
      'error_count': errorEvents.length,

      // 12 Features for Spoof Detector
      'spoof_features': {
        'sensor_latency': sensorLatency,
        'detection_latency': detectionLatency,
        'completion_latency': completionLatency,
        'total_duration': totalDuration,
        'retry_count': retryCount,
        'failure_reason': failureReason,
        'cpu_load': cpuLoad,
        'thermal_state': thermalState,
        'screen_state': screenState,
        'entropy': entropy,
        'hasCrypto': hasCrypto,
        'networkFlag': networkFlag,
      },

      // 12 Features for Anomaly Detector
      'anomaly_features': {
        'sensor_latency': sensorLatency,
        'detection_latency': detectionLatency,
        'completion_latency': completionLatency,
        'total_duration': totalDuration,
        'retry_count': retryCount,
        'failure_reason': failureReason,
        'cpu_load': cpuLoad,
        'thermal_state': thermalState,
        'screen_state': screenState,
        'entropy': entropy,
        'timeOfDay': timeOfDay,
        'dayOfWeek': dayOfWeek,
      },

      // Side-Channel Attack Analysis
      'side_channel_analysis': {
        'has_timing_attack': sideChannelAnalysis['has_timing_attack'],
        'has_constant_time_leak': sideChannelAnalysis['has_constant_time_leak'],
        'timing_variance': sideChannelAnalysis['timing_variance'],
        'timing_entropy': sideChannelAnalysis['timing_entropy'],
        'suspicious_patterns': sideChannelAnalysis['suspicious_patterns'],
        'side_channel_score': sideChannelAnalysis['side_channel_score'],
        'vulnerabilities': sideChannelAnalysis['vulnerabilities'],
        'total_duration_ms': sideChannelAnalysis['total_duration_ms'],
      },

      // Metadata
      'package_name': packageName,
      'timestamp': FieldValue.serverTimestamp(),
      'raw_logs': logs, // Store raw logs for debugging
    };
  }

  /// Calculate timing-based features from log events
  Map<String, double> _calculateTimingFeatures(List<Map<String, dynamic>> logs) {
    if (logs.length < 2) {
      return {
        'sensor_latency': 0.0,
        'detection_latency': 0.0,
        'completion_latency': 0.0,
        'total_duration': 0.0,
      };
    }

    // Sort logs by timestamp
    final sortedLogs = List<Map<String, dynamic>>.from(logs);
    sortedLogs.sort((a, b) {
      final aTime = a['timestamp'] ?? 0;
      final bTime = b['timestamp'] ?? 0;
      return aTime.compareTo(bTime);
    });

    // Find first auth_started and last success/error event
    final firstAuthIndex = sortedLogs.indexWhere((log) =>
      log['event'] == 'auth_started' ||
      log['event'] == 'androidx_auth_started' ||
      log['event'] == 'fingerprint_auth_started'
    );

    final lastResultIndex = sortedLogs.lastIndexWhere((log) =>
      log['event'] == 'success' ||
      log['event'] == 'error'
    );

    if (firstAuthIndex == -1 || lastResultIndex == -1) {
      return {
        'sensor_latency': 0.0,
        'detection_latency': 0.0,
        'completion_latency': 0.0,
        'total_duration': 0.0,
      };
    }

    final startTime = sortedLogs[firstAuthIndex]['timestamp'] as int;
    final endTime = sortedLogs[lastResultIndex]['timestamp'] as int;
    final totalDuration = (endTime - startTime) / 1000.0; // Convert to seconds

    // Estimate sensor latency (time until first failed/success)
    final firstResultIndex = sortedLogs.indexWhere((log) =>
      log['event'] == 'success' ||
      log['event'] == 'failed'
    );

    double sensorLatency = 0.0;
    if (firstResultIndex > firstAuthIndex) {
      final firstResultTime = sortedLogs[firstResultIndex]['timestamp'] as int;
      sensorLatency = (firstResultTime - startTime) / 1000.0;
    }

    // Detection latency (time between attempts)
    double detectionLatency = sensorLatency * 0.6; // Estimate

    // Completion latency (time from last attempt to final result)
    double completionLatency = totalDuration - sensorLatency;

    return {
      'sensor_latency': sensorLatency,
      'detection_latency': detectionLatency,
      'completion_latency': completionLatency,
      'total_duration': totalDuration,
    };
  }

  /// Encode BiometricPrompt error code to failure reason
  int _encodeErrorCode(int errorCode) {
    // BiometricPrompt error codes
    switch (errorCode) {
      case 10: // ERROR_USER_CANCELED
      case 13: // ERROR_NEGATIVE_BUTTON
        return 1; // user_canceled
      case 3: // ERROR_TIMEOUT
        return 2; // timeout
      case 7: // ERROR_LOCKOUT
      case 9: // ERROR_LOCKOUT_PERMANENT
        return 3; // lockout
      case 11: // ERROR_NO_BIOMETRICS
      case 12: // ERROR_HW_NOT_PRESENT
        return 4; // no_biometric
      default:
        return 5; // other
    }
  }

  /// Estimate CPU load based on event timing patterns
  double _estimateCPULoad(List<Map<String, dynamic>> logs) {
    // Simple heuristic: more events in shorter time = higher load
    if (logs.length < 2) return 0.1;

    final timestamps = logs
        .where((log) => log['timestamp'] != null)
        .map((log) => log['timestamp'] as int)
        .toList();

    if (timestamps.length < 2) return 0.1;

    timestamps.sort();
    final duration = (timestamps.last - timestamps.first) / 1000.0; // seconds

    if (duration == 0) return 0.5;

    final eventRate = logs.length / duration;
    return (eventRate / 10).clamp(0.0, 1.0); // Normalize to 0-1
  }

  /// Calculate entropy of timing patterns
  double _calculateEntropy(List<Map<String, dynamic>> logs) {
    if (logs.length < 3) return 0.0;

    // Calculate intervals between events
    final timestamps = logs
        .where((log) => log['timestamp'] != null)
        .map((log) => log['timestamp'] as int)
        .toList();

    if (timestamps.length < 3) return 0.0;

    timestamps.sort();
    final intervals = <int>[];
    for (int i = 1; i < timestamps.length; i++) {
      intervals.add(timestamps[i] - timestamps[i - 1]);
    }

    // Calculate Shannon entropy of interval distribution
    final intervalCounts = <int, int>{};
    for (final interval in intervals) {
      final bucket = (interval / 100).floor() * 100; // 100ms buckets
      intervalCounts[bucket] = (intervalCounts[bucket] ?? 0) + 1;
    }

    double entropy = 0.0;
    final total = intervals.length.toDouble();
    for (final count in intervalCounts.values) {
      final p = count / total;
      if (p > 0) {
        entropy -= p * (math.log(p) / math.ln10); // log base 10
      }
    }

    return entropy;
  }

  /// Detect side-channel attacks through timing analysis
  /// Returns analysis with detected vulnerabilities and risk indicators
  Map<String, dynamic> _detectSideChannelAttacks(List<Map<String, dynamic>> logs) {
    if (logs.length < 3) {
      return {
        'has_timing_attack': false,
        'has_constant_time_leak': false,
        'timing_variance': 0.0,
        'suspicious_patterns': 0,
        'side_channel_score': 0.0,
        'vulnerabilities': [],
      };
    }

    final vulnerabilities = <String>[];
    int suspiciousPatterns = 0;
    double sideChannelScore = 0.0;

    // Extract all timestamps
    final timestamps = logs
        .where((log) => log['timestamp'] != null)
        .map((log) => log['timestamp'] as int)
        .toList();

    if (timestamps.length < 3) {
      return {
        'has_timing_attack': false,
        'has_constant_time_leak': false,
        'timing_variance': 0.0,
        'suspicious_patterns': 0,
        'side_channel_score': 0.0,
        'vulnerabilities': [],
      };
    }

    timestamps.sort();

    // Calculate timing intervals between events
    final intervals = <int>[];
    for (int i = 1; i < timestamps.length; i++) {
      intervals.add(timestamps[i] - timestamps[i - 1]);
    }

    // 1. TIMING ATTACK DETECTION
    // Group events into authentication sessions (events within 1 second = same session)
    // Check each session for suspicious timing
    final sessions = <List<int>>[];
    List<int> currentSession = [timestamps[0]];

    for (int i = 1; i < timestamps.length; i++) {
      final gap = timestamps[i] - timestamps[i - 1];
      if (gap > 1000) {
        // New session (gap > 1 second)
        sessions.add(List.from(currentSession));
        currentSession = [timestamps[i]];
      } else {
        currentSession.add(timestamps[i]);
      }
    }
    sessions.add(currentSession);

    print('[SideChannel] Total events: ${logs.length}, Sessions detected: ${sessions.length}');

    // Check each authentication session for timing attacks
    int sessionNumber = 0;
    for (final session in sessions) {
      sessionNumber++;
      if (session.length >= 2) {
        final sessionDuration = session.last - session.first;
        print('[SideChannel] Session $sessionNumber: ${session.length} events, Duration: ${sessionDuration}ms');

        if (sessionDuration < 100) {
          vulnerabilities.add('TIMING_ATTACK: Session $sessionNumber completed in ${sessionDuration}ms (< 100ms minimum)');
          suspiciousPatterns++;
          sideChannelScore += 30.0;
          print('[SideChannel] ⚠️ TIMING ATTACK DETECTED in session $sessionNumber: ${sessionDuration}ms');
        }
      }
    }

    // 2. CONSTANT-TIME OPERATION LEAK DETECTION
    // Calculate variance in timing intervals
    final timingVariance = _calculateVariance(intervals);

    // Very low variance indicates constant-time leak (automated/scripted)
    if (timingVariance < 10.0 && intervals.length >= 3) {
      vulnerabilities.add('CONSTANT_TIME_LEAK: Timing variance = ${timingVariance.toStringAsFixed(2)}ms (expected > 50ms for human interaction)');
      suspiciousPatterns++;
      sideChannelScore += 25.0;
    }

    // Very high variance might indicate timing channel exploitation
    if (timingVariance > 5000.0) {
      vulnerabilities.add('TIMING_CHANNEL_EXPLOIT: Extremely high variance = ${timingVariance.toStringAsFixed(2)}ms (possible probing attack)');
      suspiciousPatterns++;
      sideChannelScore += 20.0;
    }

    // 3. PATTERN-BASED SIDE-CHANNEL DETECTION
    // Check for repeating timing patterns (replay attack indicator)
    if (_hasRepeatingPattern(intervals)) {
      vulnerabilities.add('REPLAY_PATTERN: Detected repeating timing intervals (possible replay attack)');
      suspiciousPatterns++;
      sideChannelScore += 35.0;
    }

    // 4. STATISTICAL TIMING ANALYSIS
    // Check for timing correlations with success/failure
    final timingByOutcome = _analyzeTimingByOutcome(logs);
    if (timingByOutcome['correlation_detected'] == true) {
      vulnerabilities.add('TIMING_CORRELATION: Success/failure timing correlation detected (${timingByOutcome['description']})');
      suspiciousPatterns++;
      sideChannelScore += 30.0;
    }

    // 5. ENTROPY-BASED DETECTION
    // Calculate Shannon entropy of timing intervals
    final timingEntropy = _calculateTimingEntropy(intervals);
    if (timingEntropy < 0.5) {
      vulnerabilities.add('LOW_TIMING_ENTROPY: Entropy = ${timingEntropy.toStringAsFixed(3)} (expected > 1.0 for natural behavior)');
      suspiciousPatterns++;
      sideChannelScore += 15.0;
    }

    // Cap score at 100
    sideChannelScore = sideChannelScore.clamp(0.0, 100.0);

    // Calculate overall duration for reporting
    final totalDuration = timestamps.last - timestamps.first;

    return {
      'has_timing_attack': suspiciousPatterns > 0,
      'has_constant_time_leak': timingVariance < 10.0,
      'timing_variance': timingVariance,
      'timing_entropy': timingEntropy,
      'suspicious_patterns': suspiciousPatterns,
      'side_channel_score': sideChannelScore,
      'vulnerabilities': vulnerabilities,
      'total_duration_ms': totalDuration,
      'intervals': intervals,
    };
  }

  /// Calculate variance of a list of numbers
  double _calculateVariance(List<int> values) {
    if (values.isEmpty) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => math.pow(v - mean, 2));
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;

    return variance;
  }

  /// Detect repeating patterns in timing intervals
  bool _hasRepeatingPattern(List<int> intervals) {
    if (intervals.length < 4) return false;

    // Check for exact repeating patterns (tolerance of 5ms)
    const tolerance = 5;

    for (int i = 0; i < intervals.length - 1; i++) {
      for (int j = i + 1; j < intervals.length; j++) {
        if ((intervals[i] - intervals[j]).abs() < tolerance) {
          // Found a match, check if it's part of a pattern
          int matches = 2; // Already found 2 matching intervals
          for (int k = 0; k < intervals.length; k++) {
            if (k != i && k != j && (intervals[k] - intervals[i]).abs() < tolerance) {
              matches++;
            }
          }

          // If more than 50% of intervals are similar, it's a pattern
          if (matches > intervals.length / 2) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Analyze timing differences between successful and failed attempts
  Map<String, dynamic> _analyzeTimingByOutcome(List<Map<String, dynamic>> logs) {
    final successTimes = <int>[];
    final failureTimes = <int>[];

    // Group events by outcome
    int? lastStartTime;
    for (var log in logs) {
      final event = log['event'] as String?;
      final timestamp = log['timestamp'] as int?;

      if (timestamp == null) continue;

      if (event == 'auth_started' || event == 'androidx_auth_started' || event == 'fingerprint_auth_started') {
        lastStartTime = timestamp;
      } else if (lastStartTime != null) {
        final duration = timestamp - lastStartTime;

        if (event == 'success') {
          successTimes.add(duration);
        } else if (event == 'failed' || event == 'error') {
          failureTimes.add(duration);
        }
      }
    }

    // Need at least 2 of each to compare
    if (successTimes.length < 2 || failureTimes.length < 2) {
      return {'correlation_detected': false};
    }

    // Calculate average times
    final avgSuccess = successTimes.reduce((a, b) => a + b) / successTimes.length;
    final avgFailure = failureTimes.reduce((a, b) => a + b) / failureTimes.length;

    // If there's a significant timing difference (>50ms), it's a side-channel leak
    final timingDiff = (avgSuccess - avgFailure).abs();

    if (timingDiff > 50) {
      return {
        'correlation_detected': true,
        'description': 'Success avg: ${avgSuccess.toStringAsFixed(0)}ms, Failure avg: ${avgFailure.toStringAsFixed(0)}ms (diff: ${timingDiff.toStringAsFixed(0)}ms)',
        'timing_diff_ms': timingDiff,
      };
    }

    return {'correlation_detected': false};
  }

  /// Calculate Shannon entropy of timing intervals
  double _calculateTimingEntropy(List<int> intervals) {
    if (intervals.isEmpty) return 0.0;

    // Bucket intervals into 50ms buckets
    final buckets = <int, int>{};
    for (final interval in intervals) {
      final bucket = (interval / 50).floor() * 50;
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
    }

    // Calculate Shannon entropy
    double entropy = 0.0;
    final total = intervals.length.toDouble();

    for (final count in buckets.values) {
      final p = count / total;
      if (p > 0) {
        entropy -= p * (math.log(p) / math.ln2); // log base 2
      }
    }

    return entropy;
  }

  /// Get default features when no logs available
  Map<String, dynamic> _getDefaultFeatures(String packageName) {
    return {
      'total_events': 0,
      'success_count': 0,
      'failed_count': 0,
      'error_count': 0,
      'spoof_features': {
        'sensor_latency': 0.0,
        'detection_latency': 0.0,
        'completion_latency': 0.0,
        'total_duration': 0.0,
        'retry_count': 0,
        'failure_reason': 0,
        'cpu_load': 0.0,
        'thermal_state': 0,
        'screen_state': 1,
        'entropy': 0.0,
        'hasCrypto': 0,
        'networkFlag': 0,
      },
      'anomaly_features': {
        'sensor_latency': 0.0,
        'detection_latency': 0.0,
        'completion_latency': 0.0,
        'total_duration': 0.0,
        'retry_count': 0,
        'failure_reason': 0,
        'cpu_load': 0.0,
        'thermal_state': 0,
        'screen_state': 1,
        'entropy': 0.0,
        'timeOfDay': DateTime.now().hour.toDouble(),
        'dayOfWeek': DateTime.now().weekday,
      },
      'package_name': packageName,
      'timestamp': FieldValue.serverTimestamp(),
      'raw_logs': [],
    };
  }

  /// Process logs and upload to Firebase
  /// Returns ProcessResult with success status and scan data
  Future<ProcessResult> processAndUpload({
    required String userId,
    required bool isPremium,
    required String packageName,
    required String appName,
  }) async {
    try {
      // Check scan limits for free users
      if (!isPremium) {
        final canScan = await _checkScanLimit(userId);
        if (!canScan.allowed) {
          return ProcessResult(
            success: false,
            message: 'Scan limit reached. ${canScan.remainingScans}/3 scans used. Reset in ${canScan.hoursUntilReset}h',
            scanData: null,
          );
        }
      }

      // Read and decrypt logs
      final logs = await readAndDecryptLogs();

      if (logs.isEmpty) {
        return ProcessResult(
          success: false,
          message: 'No biometric events found in log file',
          scanData: null,
        );
      }

      // Extract ML features
      final features = extractMLFeatures(logs, packageName);

      // ===== ML INFERENCE INTEGRATION =====
      // Initialize ML service
      final mlService = MLInferenceService();
      try {
        await mlService.initialize();
      } catch (e) {
        print('[FridaLogProcessor] Warning: ML models failed to initialize: $e');
      }

      // Run ML-based spoof detection
      SpoofResult? spoofResult;
      AnomalyResult? anomalyResult;

      try {
        final spoofFeatures = features['spoof_features'] as Map<String, dynamic>;
        spoofResult = await mlService.detectSpoof(spoofFeatures);

        final anomalyFeatures = features['anomaly_features'] as Map<String, dynamic>;
        anomalyResult = await mlService.detectAnomaly(anomalyFeatures);
      } catch (e) {
        print('[FridaLogProcessor] Warning: ML inference failed: $e');
      }

      // Calculate risk score combining rule-based + ML analysis
      final sideChannelData = features['side_channel_analysis'] as Map<String, dynamic>;
      final sideChannelScore = (sideChannelData['side_channel_score'] as num).toDouble();
      final vulnerabilities = List<String>.from(sideChannelData['vulnerabilities'] as List);

      // Add ML-based vulnerabilities
      if (spoofResult != null && spoofResult.classification == SpoofClassification.spoof) {
        vulnerabilities.add('ML_SPOOF_DETECTED: ${(spoofResult.confidence * 100).toStringAsFixed(1)}% confidence (${spoofResult.classification.displayName})');
      }
      if (anomalyResult != null && anomalyResult.isAnomaly) {
        vulnerabilities.add('ML_ANOMALY_DETECTED: ${(anomalyResult.confidence * 100).toStringAsFixed(1)}% confidence (Anomalous behavior pattern)');
      }

      // Combine scores: 70% rule-based + 30% ML-based
      double mlRiskScore = 0.0;
      if (spoofResult != null && anomalyResult != null) {
        // Convert ML probabilities to risk scores (0-100)
        final spoofRisk = spoofResult.spoofScore * 100;
        final anomalyRisk = anomalyResult.confidence * 100;
        mlRiskScore = (spoofRisk * 0.6 + anomalyRisk * 0.4); // Weight spoof detection higher
      }

      final combinedRiskScore = (sideChannelScore * 0.7 + mlRiskScore * 0.3).clamp(0.0, 100.0);

      // Update side_channel_analysis with combined data
      sideChannelData['side_channel_score'] = combinedRiskScore;
      sideChannelData['vulnerabilities'] = vulnerabilities;
      sideChannelData['ml_spoof_result'] = spoofResult != null ? {
        'classification': spoofResult.classification.toString().split('.').last,
        'confidence': spoofResult.confidence,
        'spoof_score': spoofResult.spoofScore,
        'genuine_score': spoofResult.genuineScore,
      } : null;
      sideChannelData['ml_anomaly_result'] = anomalyResult != null ? {
        'is_anomaly': anomalyResult.isAnomaly,
        'confidence': anomalyResult.confidence,
        'normal_score': anomalyResult.normalScore,
      } : null;

      // Invert score for UI: combined risk (0=secure, 100=risky) -> security score (0=risky, 100=secure)
      final securityScore = 100 - combinedRiskScore;

      String resultSummary;
      String status = 'completed';

      if (combinedRiskScore >= 70) {
        resultSummary = 'Critical: ${vulnerabilities.length} vulnerabilities detected';
      } else if (combinedRiskScore >= 40) {
        resultSummary = 'Warning: Moderate security risks found';
      } else if (combinedRiskScore > 0) {
        resultSummary = 'Minor issues detected';
      } else {
        resultSummary = 'No security issues detected';
      }

      // Create scan document
      final scanData = {
        ...features,
        'app_name': appName,
        'user_id': userId,
        'is_premium': isPremium,
        'timestamp': FieldValue.serverTimestamp(), // Changed from scan_timestamp for UI compatibility
        'riskScore': securityScore, // For UI compatibility - inverted from side_channel_score
        'resultSummary': resultSummary, // For UI compatibility
        'status': status, // For UI compatibility
      };

      // Upload to Firebase
      final scanRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('scans')
          .add(scanData);

      // Also upload to global scans collection for ML training
      await _firestore
          .collection('ml_training_data')
          .doc(scanRef.id)
          .set(scanData);

      print('[FridaLogProcessor] Successfully uploaded scan ${scanRef.id}');

      // Clear processed logs
      await clearLogs();

      return ProcessResult(
        success: true,
        message: 'Scan processed successfully! Analyzed ${logs.length} events',
        scanData: {...scanData, 'scan_id': scanRef.id},
      );

    } catch (e) {
      print('[FridaLogProcessor] Error processing logs: $e');
      return ProcessResult(
        success: false,
        message: 'Error processing scan: $e',
        scanData: null,
      );
    }
  }

  /// Check if user can perform a scan (free tier limit)
  Future<ScanLimitCheck> _checkScanLimit(String userId) async {
    try {
      final now = DateTime.now();
      final windowStart = now.subtract(const Duration(hours: 24));

      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('scans')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(windowStart))
          .get();

      final recentScansCount = querySnapshot.docs.length;
      const limit = 3;

      if (recentScansCount >= limit) {
        // Calculate hours until reset
        if (querySnapshot.docs.isNotEmpty) {
          final oldestScan = querySnapshot.docs
              .map((doc) => (doc.data()['timestamp'] as Timestamp).toDate())
              .reduce((a, b) => a.isBefore(b) ? a : b);

          final resetTime = oldestScan.add(const Duration(hours: 24));
          final hoursUntilReset = resetTime.difference(now).inHours;

          return ScanLimitCheck(
            allowed: false,
            remainingScans: 0,
            hoursUntilReset: hoursUntilReset > 0 ? hoursUntilReset : 0,
          );
        }
      }

      return ScanLimitCheck(
        allowed: true,
        remainingScans: limit - recentScansCount,
        hoursUntilReset: 0,
      );
    } catch (e) {
      print('[FridaLogProcessor] Error checking scan limit: $e');
      // On error, allow scan (fail open)
      return ScanLimitCheck(allowed: true, remainingScans: 3, hoursUntilReset: 0);
    }
  }

  /// Delete processed logs
  Future<void> clearLogs() async {
    try {
      final file = File(LOG_PATH);
      if (await file.exists()) {
        await file.delete();
        print('[FridaLogProcessor] Log file cleared');
      }
    } catch (e) {
      print('[FridaLogProcessor] Error clearing logs: $e');
    }
  }

  /// Check if log file exists
  Future<bool> hasLogs() async {
    try {
      final file = File(LOG_PATH);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get log file info
  Future<LogFileInfo> getLogFileInfo() async {
    try {
      final file = File(LOG_PATH);
      if (!await file.exists()) {
        return LogFileInfo(exists: false, lineCount: 0, sizeBytes: 0);
      }

      final lines = await file.readAsLines();
      final stat = await file.stat();

      return LogFileInfo(
        exists: true,
        lineCount: lines.length,
        sizeBytes: stat.size,
      );
    } catch (e) {
      return LogFileInfo(exists: false, lineCount: 0, sizeBytes: 0);
    }
  }
}

/// Result of processing and uploading logs
class ProcessResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? scanData;

  ProcessResult({
    required this.success,
    required this.message,
    this.scanData,
  });
}

/// Scan limit check result
class ScanLimitCheck {
  final bool allowed;
  final int remainingScans;
  final int hoursUntilReset;

  ScanLimitCheck({
    required this.allowed,
    required this.remainingScans,
    required this.hoursUntilReset,
  });
}

/// Log file info
class LogFileInfo {
  final bool exists;
  final int lineCount;
  final int sizeBytes;

  LogFileInfo({
    required this.exists,
    required this.lineCount,
    required this.sizeBytes,
  });
}
