// lib/services/biometric_service.dart
// Real biometric authentication with vulnerability detection
// Collects timing data, entropy, and system metrics

import 'package:local_auth/local_auth.dart';
import 'dart:async';
import 'dart:math';

/// Biometric capability check result
class BiometricCapability {
  final bool isSupported;
  final bool hasFingerprint;
  final bool hasFace;
  final bool hasIris;
  final String message;

  BiometricCapability({
    required this.isSupported,
    this.hasFingerprint = false,
    this.hasFace = false,
    this.hasIris = false,
    this.message = '',
  });

  static BiometricCapability get notSupported => BiometricCapability(
        isSupported: false,
        message: 'Device does not support biometric authentication',
      );

  static BiometricCapability get notAvailable => BiometricCapability(
        isSupported: false,
        message: 'Biometric authentication not available',
      );

  static BiometricCapability get error => BiometricCapability(
        isSupported: false,
        message: 'Error checking biometric support',
      );
}

/// Result of biometric scan with vulnerability analysis
class BiometricScanResult {
  final bool authenticated;
  final Duration duration;
  final List<Vulnerability> vulnerabilities;
  final double riskScore;
  final Map<String, dynamic> timingData;
  final Map<String, dynamic>? systemMetrics;
  final String? errorMessage;

  BiometricScanResult({
    required this.authenticated,
    required this.duration,
    required this.vulnerabilities,
    required this.riskScore,
    required this.timingData,
    this.systemMetrics,
    this.errorMessage,
  });

  factory BiometricScanResult.error(String message) {
    return BiometricScanResult(
      authenticated: false,
      duration: Duration.zero,
      vulnerabilities: [],
      riskScore: 0,
      timingData: {},
      errorMessage: message,
    );
  }
}

/// Vulnerability types
enum VulnerabilityType {
  timingAttack,
  replayAttack,
  lowEntropy,
  sideChannel,
  weakImplementation,
  insecureStorage,
  networkTransmission,
}

/// Severity levels
enum Severity { low, medium, high, critical }

/// Vulnerability detail
class Vulnerability {
  final VulnerabilityType type;
  final Severity severity;
  final String description;
  final String recommendation;

  Vulnerability({
    required this.type,
    required this.severity,
    required this.description,
    required this.recommendation,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'severity': severity.toString().split('.').last,
      'description': description,
      'recommendation': recommendation,
    };
  }
}

/// Main biometric service
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Timing data collection
  DateTime? _authStartTime;
  DateTime? _authEndTime;
  final List<Map<String, dynamic>> _timingHistory = [];

  /// Check biometric support on device
  Future<BiometricCapability> checkBiometricSupport() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!isDeviceSupported) return BiometricCapability.notSupported;
      if (!canCheckBiometrics) return BiometricCapability.notAvailable;

      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      return BiometricCapability(
        isSupported: true,
        hasFingerprint: availableBiometrics.contains(BiometricType.fingerprint),
        hasFace: availableBiometrics.contains(BiometricType.face),
        hasIris: availableBiometrics.contains(BiometricType.iris),
        message: 'Biometric authentication available',
      );
    } catch (e) {
      print('❌ Error checking biometric support: $e');
      return BiometricCapability.error;
    }
  }

  /// Perform biometric authentication with vulnerability analysis
  Future<BiometricScanResult> authenticateWithBiometrics({
    required String reason,
    bool collectTimingData = true,
  }) async {
    try {
      print('🔐 Starting biometric authentication...');

      // Start timing
      _authStartTime = DateTime.now();

      // Collect pre-auth metrics
      final preAuthMetrics = await _collectSystemMetrics();
      print('📊 Pre-auth metrics collected');

      // Perform authentication
      print('👆 Requesting biometric authentication...');
      final bool authenticated = await _localAuth.authenticate(
        localizedReason: reason,
      );

      // End timing
      _authEndTime = DateTime.now();
      final duration = _authEndTime!.difference(_authStartTime!);

      print('⏱️ Authentication completed in ${duration.inMilliseconds}ms');
      print('✅ Authentication result: $authenticated');

      // Collect post-auth metrics
      final postAuthMetrics = await _collectSystemMetrics();

      // Record timing data
      final timingData = {
        'startTime': _authStartTime!.millisecondsSinceEpoch,
        'endTime': _authEndTime!.millisecondsSinceEpoch,
        'durationMs': duration.inMilliseconds,
        'authenticated': authenticated,
      };

      _timingHistory.add(timingData);
      if (_timingHistory.length > 10) {
        _timingHistory.removeAt(0);
      }

      // Analyze for vulnerabilities
      print('🔍 Analyzing for vulnerabilities...');
      final vulnerabilities = await _analyzeVulnerabilities(
        duration: duration,
        preMetrics: preAuthMetrics,
        postMetrics: postAuthMetrics,
        authenticated: authenticated,
      );

      print('⚠️ Found ${vulnerabilities.length} vulnerabilities');

      // Calculate risk score
      final riskScore = _calculateRiskScore(vulnerabilities, duration);
      print('📊 Risk Score: $riskScore/100');

      return BiometricScanResult(
        authenticated: authenticated,
        duration: duration,
        vulnerabilities: vulnerabilities,
        riskScore: riskScore,
        timingData: timingData,
        systemMetrics: {
          'pre': preAuthMetrics,
          'post': postAuthMetrics,
        },
      );
    } catch (e) {
      print('❌ Biometric authentication error: $e');
      return BiometricScanResult.error(e.toString());
    }
  }

  /// Collect system metrics for analysis
  Future<Map<String, dynamic>> _collectSystemMetrics() async {
    return {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'entropy': _calculateEntropy(),
      'randomSample': Random().nextDouble(),
      // In production, you would collect:
      // - Memory usage
      // - CPU usage
      // - Network activity
      // - Process information
    };
  }

  /// Analyze for vulnerabilities
  Future<List<Vulnerability>> _analyzeVulnerabilities({
    required Duration duration,
    required Map<String, dynamic> preMetrics,
    required Map<String, dynamic> postMetrics,
    required bool authenticated,
  }) async {
    List<Vulnerability> vulnerabilities = [];

    // 1. Check for timing attacks
    if (duration.inMilliseconds < 100) {
      vulnerabilities.add(Vulnerability(
        type: VulnerabilityType.timingAttack,
        severity: Severity.high,
        description:
            'Authentication completed too quickly (${duration.inMilliseconds}ms). This may indicate a timing attack vulnerability.',
        recommendation:
            'Implement minimum authentication time of at least 200ms to prevent timing-based attacks.',
      ));
    }

    if (duration.inMilliseconds > 10000) {
      vulnerabilities.add(Vulnerability(
        type: VulnerabilityType.weakImplementation,
        severity: Severity.medium,
        description:
            'Authentication took unusually long (${duration.inMilliseconds}ms). This may indicate performance issues.',
        recommendation:
            'Optimize biometric authentication implementation for better performance.',
      ));
    }

    // 2. Check for replay attacks (pattern detection)
    if (_detectReplayPattern()) {
      vulnerabilities.add(Vulnerability(
        type: VulnerabilityType.replayAttack,
        severity: Severity.critical,
        description:
            'Suspicious pattern detected in authentication attempts. Possible replay attack.',
        recommendation:
            'Implement nonce-based authentication and challenge-response mechanisms.',
      ));
    }

    // 3. Check entropy levels
    final entropyDiff = (postMetrics['entropy'] as double) -
        (preMetrics['entropy'] as double);
    if (entropyDiff.abs() < 0.1) {
      vulnerabilities.add(Vulnerability(
        type: VulnerabilityType.lowEntropy,
        severity: Severity.medium,
        description:
            'Low entropy detected during authentication (${entropyDiff.toStringAsFixed(3)}). System randomness may be insufficient.',
        recommendation:
            'Increase randomization sources and implement proper PRNG seeding.',
      ));
    }

    // 4. Check for consistent timing (potential side-channel)
    if (_timingHistory.length >= 5) {
      final variance = _calculateTimingVariance();
      if (variance < 10) {
        vulnerabilities.add(Vulnerability(
          type: VulnerabilityType.sideChannel,
          severity: Severity.high,
          description:
              'Authentication times show very low variance ($variance). This may leak information through timing side-channels.',
          recommendation:
              'Add random delays and implement constant-time operations to mask timing patterns.',
        ));
      }
    }

    return vulnerabilities;
  }

  /// Calculate risk score based on vulnerabilities and timing
  double _calculateRiskScore(
      List<Vulnerability> vulnerabilities, Duration duration) {
    if (vulnerabilities.isEmpty && duration.inMilliseconds >= 200) {
      return 100.0; // Perfect score
    }

    double score = 100.0;

    // Deduct points for each vulnerability
    for (var vuln in vulnerabilities) {
      switch (vuln.severity) {
        case Severity.critical:
          score -= 30;
          break;
        case Severity.high:
          score -= 20;
          break;
        case Severity.medium:
          score -= 10;
          break;
        case Severity.low:
          score -= 5;
          break;
      }
    }

    // Additional penalty for very short duration
    if (duration.inMilliseconds < 50) {
      score -= 15;
    }

    return score.clamp(0, 100);
  }

  /// Calculate entropy (randomness measure)
  double _calculateEntropy() {
    final random = Random();
    final samples = List.generate(100, (_) => random.nextDouble());

    // Simple entropy calculation based on distribution variance
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    double variance = 0;
    for (var sample in samples) {
      variance += pow(sample - mean, 2).toDouble();
    }
    variance /= samples.length;

    // Normalize to 0-1 range (higher variance = higher entropy)
    return (variance * 12).clamp(0, 1); // Scale factor for 0-1 range
  }

  /// Detect replay attack patterns
  bool _detectReplayPattern() {
    if (_timingHistory.length < 3) return false;

    // Check if last 3 timings are suspiciously similar
    final last3 = _timingHistory.skip(_timingHistory.length - 3).toList();
    final durations =
        last3.map((t) => t['durationMs'] as int).toList();

    // Calculate standard deviation
    final mean = durations.reduce((a, b) => a + b) / durations.length;
    final variance = durations
            .map((d) => pow(d - mean, 2))
            .reduce((a, b) => a + b) /
        durations.length;

    // If standard deviation is very low, might be replay
    return variance < 5;
  }

  /// Calculate variance in timing
  double _calculateTimingVariance() {
    if (_timingHistory.isEmpty) return 0;

    final durations = _timingHistory
        .map((t) => (t['durationMs'] as int).toDouble())
        .toList();

    final mean = durations.reduce((a, b) => a + b) / durations.length;
    final variance = durations
            .map((d) => pow(d - mean, 2))
            .reduce((a, b) => a + b) /
        durations.length;

    return variance;
  }

  /// Get timing history for analysis
  List<Map<String, dynamic>> get timingHistory => List.unmodifiable(_timingHistory);

  /// Clear timing history
  void clearHistory() {
    _timingHistory.clear();
  }
}
