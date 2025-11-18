// lib/services/recommendation_engine.dart
// Recommendation Engine - Provides security recommendations based on vulnerabilities
// Maps vulnerability types to actionable mitigation strategies

import '../services/biometric_service.dart';

/// Priority levels for recommendations
enum Priority { low, medium, high, urgent }

/// Implementation effort estimates
enum EffortLevel { low, medium, high, veryHigh }

/// Mitigation strategy with implementation details
class Mitigation {
  final String title;
  final String description;
  final String implementation;
  final Priority priority;
  final EffortLevel estimatedEffort;
  final List<String> steps;

  Mitigation({
    required this.title,
    required this.description,
    required this.implementation,
    required this.priority,
    required this.estimatedEffort,
    required this.steps,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'implementation': implementation,
      'priority': priority.toString().split('.').last,
      'estimatedEffort': estimatedEffort.toString().split('.').last,
      'steps': steps,
    };
  }
}

/// Complete recommendation with implementation plan
class Recommendation {
  final String title;
  final String description;
  final Priority priority;
  final List<String> actionItems;
  final String codeExample;
  final int estimatedHours;

  Recommendation({
    required this.title,
    required this.description,
    required this.priority,
    required this.actionItems,
    required this.codeExample,
    required this.estimatedHours,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'priority': priority.toString().split('.').last,
      'actionItems': actionItems,
      'codeExample': codeExample,
      'estimatedHours': estimatedHours,
    };
  }
}

/// Main recommendation engine
class RecommendationEngine {
  // Mitigation strategies database
  static final Map<VulnerabilityType, List<Mitigation>> _mitigationStrategies = {
    VulnerabilityType.timingAttack: [
      Mitigation(
        title: 'Implement Constant-Time Operations',
        description: 'Ensure all authentication paths take the same amount of time to prevent timing analysis',
        implementation: '''
// Add minimum authentication time
Future<bool> constantTimeAuth() async {
  final startTime = DateTime.now();
  final result = await performAuth();
  final elapsed = DateTime.now().difference(startTime);

  // Enforce minimum time of 200ms
  if (elapsed.inMilliseconds < 200) {
    await Future.delayed(
      Duration(milliseconds: 200 - elapsed.inMilliseconds)
    );
  }

  return result;
}''',
        priority: Priority.urgent,
        estimatedEffort: EffortLevel.medium,
        steps: [
          'Measure current authentication timing',
          'Identify fastest and slowest paths',
          'Add delays to normalize timing',
          'Test with multiple devices',
          'Verify timing consistency',
        ],
      ),
      Mitigation(
        title: 'Add Random Delays',
        description: 'Introduce random delays to mask actual processing time',
        implementation: '''
// Add random delay to prevent timing analysis
final random = Random.secure();
await Future.delayed(
  Duration(milliseconds: 50 + random.nextInt(100))
);''',
        priority: Priority.high,
        estimatedEffort: EffortLevel.low,
        steps: [
          'Use cryptographically secure random generator',
          'Add 50-150ms random delay',
          'Apply after authentication completes',
          'Test impact on user experience',
        ],
      ),
    ],

    VulnerabilityType.replayAttack: [
      Mitigation(
        title: 'Implement Nonce-Based Authentication',
        description: 'Use one-time tokens to prevent replay attacks',
        implementation: '''
// Generate unique nonce for each authentication
class AuthSession {
  final String nonce;
  final DateTime timestamp;

  AuthSession()
    : nonce = Uuid().v4(),
      timestamp = DateTime.now();

  bool isValid() {
    // Nonce expires after 5 minutes
    return DateTime.now().difference(timestamp).inMinutes < 5;
  }
}

// Store and validate nonces
final usedNonces = <String>{};

bool validateNonce(String nonce) {
  if (usedNonces.contains(nonce)) {
    return false; // Replay detected!
  }
  usedNonces.add(nonce);
  return true;
}''',
        priority: Priority.urgent,
        estimatedEffort: EffortLevel.high,
        steps: [
          'Generate unique nonce per auth attempt',
          'Store nonces with expiration',
          'Validate nonce before processing',
          'Clear expired nonces periodically',
          'Implement nonce synchronization',
        ],
      ),
      Mitigation(
        title: 'Add Timestamp Validation',
        description: 'Reject authentication requests with old timestamps',
        implementation: '''
// Validate authentication timestamp
bool validateTimestamp(DateTime authTime) {
  final now = DateTime.now();
  final diff = now.difference(authTime).abs();

  // Reject if more than 30 seconds old
  return diff.inSeconds < 30;
}''',
        priority: Priority.high,
        estimatedEffort: EffortLevel.low,
        steps: [
          'Include timestamp in auth request',
          'Validate timestamp on server',
          'Reject old requests',
          'Handle clock skew',
        ],
      ),
    ],

    VulnerabilityType.lowEntropy: [
      Mitigation(
        title: 'Increase Randomness Sources',
        description: 'Use multiple sources of randomness for better entropy',
        implementation: '''
// Use multiple entropy sources
import 'dart:math';
import 'package:crypto/crypto.dart';

class EntropyGenerator {
  final Random _random = Random.secure();

  List<int> generateHighEntropyData(int length) {
    // Combine multiple sources
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomBytes = List.generate(length, (_) => _random.nextInt(256));

    // Mix with system entropy
    final combined = "\$timestamp\${randomBytes.join()}";
    final hash = sha256.convert(combined.codeUnits);

    return hash.bytes.take(length).toList();
  }
}''',
        priority: Priority.medium,
        estimatedEffort: EffortLevel.medium,
        steps: [
          'Identify entropy sources',
          'Implement secure random generator',
          'Mix multiple entropy sources',
          'Test randomness quality',
          'Monitor entropy levels',
        ],
      ),
    ],

    VulnerabilityType.sideChannel: [
      Mitigation(
        title: 'Implement Noise Injection',
        description: 'Add computational noise to prevent side-channel analysis',
        implementation: '''
// Inject computational noise
void injectNoise() {
  final random = Random.secure();

  // Perform dummy operations
  for (int i = 0; i < random.nextInt(100); i++) {
    final dummy = random.nextDouble() * random.nextDouble();
    // Force calculation to prevent optimization
    if (dummy > 999999) print('');
  }
}

// Use during sensitive operations
Future<void> secureOperation() async {
  injectNoise(); // Before
  await performSensitiveTask();
  injectNoise(); // After
}''',
        priority: Priority.high,
        estimatedEffort: EffortLevel.low,
        steps: [
          'Identify sensitive operations',
          'Add noise before and after',
          'Randomize noise intensity',
          'Test performance impact',
          'Verify side-channel resistance',
        ],
      ),
    ],

    VulnerabilityType.weakImplementation: [
      Mitigation(
        title: 'Use BiometricPrompt with CryptoObject',
        description: 'Implement proper biometric authentication with crypto binding',
        implementation: '''
// Proper BiometricPrompt implementation
final authenticated = await auth.authenticate(
  localizedReason: 'Authenticate for secure access',
  options: const AuthenticationOptions(
    stickyAuth: true,
    biometricOnly: true, // No PIN/password fallback
    useErrorDialogs: true,
    sensitiveTransaction: true, // Mark as sensitive
  ),
);''',
        priority: Priority.urgent,
        estimatedEffort: EffortLevel.medium,
        steps: [
          'Update to latest local_auth package',
          'Configure BiometricPrompt properly',
          'Set biometricOnly to true',
          'Enable sensitiveTransaction',
          'Test on multiple devices',
        ],
      ),
    ],

    VulnerabilityType.networkTransmission: [
      Mitigation(
        title: 'Encrypt Biometric Data Transmission',
        description: 'Never transmit biometric data; if necessary, encrypt end-to-end',
        implementation: '''
// BEST PRACTICE: Don't transmit biometric data at all
// If you must send authentication result:

import 'package:encrypt/encrypt.dart';

Future<void> sendAuthResult(bool result) async {
  // Use TLS 1.3 minimum
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://your-api.com',
      connectTimeout: 5000,
      receiveTimeout: 3000,
    ),
  );

  // Only send boolean result, never biometric data
  await dio.post('/auth/verify', data: {
    'authenticated': result,
    'timestamp': DateTime.now().toIso8601String(),
    // Never include: fingerprint data, face data, etc.
  });
}''',
        priority: Priority.urgent,
        estimatedEffort: EffortLevel.high,
        steps: [
          'Remove biometric data transmission',
          'Use TLS 1.3 or higher',
          'Implement certificate pinning',
          'Only send boolean results',
          'Add request signing',
        ],
      ),
    ],
  };

  /// Generate recommendations based on vulnerabilities
  List<Recommendation> generateRecommendations(List<Vulnerability> vulnerabilities) {
    final recommendations = <Recommendation>[];
    final processedTypes = <VulnerabilityType>{};

    for (var vuln in vulnerabilities) {
      if (processedTypes.contains(vuln.type)) continue;
      processedTypes.add(vuln.type);

      final mitigations = _mitigationStrategies[vuln.type];
      if (mitigations == null || mitigations.isEmpty) continue;

      // Get the highest priority mitigation for this vulnerability type
      final primaryMitigation = mitigations.first;

      recommendations.add(Recommendation(
        title: primaryMitigation.title,
        description: primaryMitigation.description,
        priority: primaryMitigation.priority,
        actionItems: primaryMitigation.steps,
        codeExample: primaryMitigation.implementation,
        estimatedHours: _getEffortHours(primaryMitigation.estimatedEffort),
      ));
    }

    // Sort by priority (urgent first)
    recommendations.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    return recommendations;
  }

  /// Get all mitigations for a vulnerability type
  List<Mitigation> getMitigationsForType(VulnerabilityType type) {
    return _mitigationStrategies[type] ?? [];
  }

  /// Calculate total implementation effort
  int calculateTotalEffort(List<Recommendation> recommendations) {
    return recommendations.fold(
      0,
      (sum, rec) => sum + rec.estimatedHours,
    );
  }

  /// Generate implementation plan
  Map<String, dynamic> generateImplementationPlan(
    List<Vulnerability> vulnerabilities,
  ) {
    final recommendations = generateRecommendations(vulnerabilities);
    final totalHours = calculateTotalEffort(recommendations);
    final totalDays = (totalHours / 8).ceil();

    return {
      'recommendations': recommendations.map((r) => r.toMap()).toList(),
      'totalHours': totalHours,
      'estimatedDays': totalDays,
      'priority': _getOverallPriority(recommendations),
      'summary': _generateSummary(vulnerabilities, recommendations),
    };
  }

  /// Generate executive summary
  String _generateSummary(
    List<Vulnerability> vulnerabilities,
    List<Recommendation> recommendations,
  ) {
    final critical = vulnerabilities.where((v) => v.severity == Severity.critical).length;
    final high = vulnerabilities.where((v) => v.severity == Severity.high).length;
    final medium = vulnerabilities.where((v) => v.severity == Severity.medium).length;

    return '''
Security Analysis Summary:
- Total Vulnerabilities: ${vulnerabilities.length}
- Critical: $critical, High: $high, Medium: $medium
- Recommendations: ${recommendations.length}
- Action Required: ${_getOverallPriority(recommendations)}

Next Steps:
${recommendations.take(3).map((r) => '• ${r.title}').join('\n')}
''';
  }

  /// Convert effort level to hours
  int _getEffortHours(EffortLevel effort) {
    switch (effort) {
      case EffortLevel.low:
        return 2;
      case EffortLevel.medium:
        return 8;
      case EffortLevel.high:
        return 16;
      case EffortLevel.veryHigh:
        return 40;
    }
  }

  /// Get overall priority from recommendations
  String _getOverallPriority(List<Recommendation> recommendations) {
    if (recommendations.isEmpty) return 'None';

    final hasUrgent = recommendations.any((r) => r.priority == Priority.urgent);
    final hasHigh = recommendations.any((r) => r.priority == Priority.high);

    if (hasUrgent) return 'Urgent - Immediate action required';
    if (hasHigh) return 'High - Address within 1 week';
    return 'Medium - Address within 1 month';
  }

  /// Generate FREE user summary - Generic recommendations based on risk score
  String generateFreeSummary(int riskScore) {
    if (riskScore >= 70) {
      return '''
⚠️ HIGH RISK DETECTED

Your biometric implementation has significant security concerns that need immediate attention.

Generic Recommendations:
• Review your biometric authentication implementation
• Ensure you're using the latest security libraries
• Consider upgrading to Premium for detailed security recommendations

Upgrade to Premium to get:
• Detailed vulnerability analysis
• Step-by-step fix instructions with code examples
• Priority-based action items
• ML-powered spoof detection insights
''';
    } else if (riskScore >= 40) {
      return '''
⚠️ MEDIUM RISK

Your biometric implementation has some security issues that should be addressed.

Generic Recommendations:
• Review authentication timing patterns
• Implement additional security measures
• Test on multiple devices

Upgrade to Premium for detailed analysis and specific recommendations.
''';
    } else {
      return '''
✅ LOW RISK

Your biometric implementation appears to follow good security practices.

General Advice:
• Continue monitoring for new vulnerabilities
• Keep security libraries updated
• Regular security audits recommended

Upgrade to Premium for:
• Continuous monitoring
• Detailed security reports
• Expert recommendations
''';
    }
  }

  /// Generate PREMIUM user summary - Detailed with ML insights and specific recommendations
  Map<String, dynamic> generatePremiumSummary({
    required int riskScore,
    required Map<String, dynamic>? mlResults,
    required int eventCount,
    required int successCount,
    required int failCount,
    required int errorCount,
  }) {
    // Extract ML results
    final spoofDetection = mlResults?['spoofDetection'];
    final anomalyDetection = mlResults?['anomalyDetection'];

    // Determine vulnerabilities based on scan data
    final vulnerabilities = <String>[];
    final recommendations = <Map<String, dynamic>>[];

    // Analyze spoof detection results
    if (spoofDetection != null) {
      final classification = spoofDetection['classification'];
      final confidence = (spoofDetection['confidence'] as num?)?.toDouble() ?? 0.0;

      if (classification == 'spoof' || classification == 'Spoof Detected') {
        vulnerabilities.add('Potential spoofing attack detected (${(confidence * 100).toStringAsFixed(1)}% confidence)');
        recommendations.add({
          'title': 'Implement Anti-Spoofing Measures',
          'priority': 'URGENT',
          'description': 'Your biometric authentication may be vulnerable to spoofing attacks.',
          'actions': [
            'Use BiometricPrompt with crypto binding',
            'Enable liveness detection if available',
            'Implement challenge-response authentication',
            'Add secondary verification for high-value transactions',
          ],
        });
      } else if (classification == 'uncertain') {
        vulnerabilities.add('Uncertain biometric authenticity (${(confidence * 100).toStringAsFixed(1)}% confidence)');
        recommendations.add({
          'title': 'Strengthen Biometric Verification',
          'priority': 'HIGH',
          'description': 'Authentication patterns show inconsistencies that may indicate security issues.',
          'actions': [
            'Review authentication flow for timing inconsistencies',
            'Implement additional verification steps',
            'Monitor for repeated uncertain results',
          ],
        });
      }
    }

    // Analyze anomaly detection results
    if (anomalyDetection != null && anomalyDetection['isAnomaly'] == true) {
      final confidence = (anomalyDetection['confidence'] as num?)?.toDouble() ?? 0.0;
      vulnerabilities.add('Anomalous behavior patterns detected (${(confidence * 100).toStringAsFixed(1)}% confidence)');
      recommendations.add({
        'title': 'Investigate Anomalous Patterns',
        'priority': 'HIGH',
        'description': 'ML analysis detected unusual authentication patterns.',
        'actions': [
          'Review authentication timing and frequency',
          'Check for automated attack attempts',
          'Implement rate limiting',
          'Add logging for security monitoring',
        ],
      });
    }

    // Analyze error/failure patterns
    if (errorCount > 0) {
      vulnerabilities.add('$errorCount authentication errors detected');
      recommendations.add({
        'title': 'Fix Authentication Errors',
        'priority': 'HIGH',
        'description': 'Authentication errors may indicate implementation issues.',
        'actions': [
          'Review error logs for root causes',
          'Ensure proper exception handling',
          'Test on multiple device models',
          'Update to latest biometric libraries',
        ],
      });
    }

    if (failCount > successCount) {
      vulnerabilities.add('High failure rate: $failCount failures vs $successCount successes');
      recommendations.add({
        'title': 'Improve Authentication Success Rate',
        'priority': 'MEDIUM',
        'description': 'More authentication attempts are failing than succeeding.',
        'actions': [
          'Improve user guidance during authentication',
          'Check biometric sensor quality',
          'Review authentication timeout settings',
          'Consider fallback authentication methods',
        ],
      });
    }

    // Generate overall assessment
    String overallAssessment;
    String securityGrade;

    if (riskScore >= 70) {
      overallAssessment = 'CRITICAL - Immediate action required';
      securityGrade = 'F';
    } else if (riskScore >= 60) {
      overallAssessment = 'HIGH RISK - Address within 48 hours';
      securityGrade = 'D';
    } else if (riskScore >= 40) {
      overallAssessment = 'MEDIUM RISK - Address within 1 week';
      securityGrade = 'C';
    } else if (riskScore >= 20) {
      overallAssessment = 'LOW RISK - Continue monitoring';
      securityGrade = 'B';
    } else {
      overallAssessment = 'SECURE - Good security posture';
      securityGrade = 'A';
    }

    return {
      'overallAssessment': overallAssessment,
      'securityGrade': securityGrade,
      'riskScore': riskScore,
      'vulnerabilities': vulnerabilities,
      'recommendations': recommendations,
      'mlInsights': {
        'spoofDetection': spoofDetection,
        'anomalyDetection': anomalyDetection,
      },
      'statistics': {
        'totalEvents': eventCount,
        'successCount': successCount,
        'failCount': failCount,
        'errorCount': errorCount,
        'successRate': eventCount > 0 ? ((successCount / eventCount) * 100).toStringAsFixed(1) : '0.0',
      },
      'detailedSummary': _buildDetailedSummary(
        riskScore,
        vulnerabilities,
        recommendations,
        spoofDetection,
        anomalyDetection,
      ),
    };
  }

  String _buildDetailedSummary(
    int riskScore,
    List<String> vulnerabilities,
    List<Map<String, dynamic>> recommendations,
    Map<String, dynamic>? spoofDetection,
    Map<String, dynamic>? anomalyDetection,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('=== DETAILED SECURITY ANALYSIS ===\n');

    // ML Analysis Section
    buffer.writeln('ML-POWERED ANALYSIS:');
    if (spoofDetection != null) {
      buffer.writeln('• Spoof Detection: ${spoofDetection['classification']}');
      buffer.writeln('  Confidence: ${((spoofDetection['confidence'] as num) * 100).toStringAsFixed(1)}%');
    }
    if (anomalyDetection != null) {
      buffer.writeln('• Anomaly Detection: ${anomalyDetection['isAnomaly'] ? 'ANOMALY DETECTED' : 'Normal'}');
      buffer.writeln('  Confidence: ${((anomalyDetection['confidence'] as num) * 100).toStringAsFixed(1)}%');
    }
    buffer.writeln();

    // Vulnerabilities Section
    if (vulnerabilities.isNotEmpty) {
      buffer.writeln('VULNERABILITIES FOUND:');
      for (var i = 0; i < vulnerabilities.length; i++) {
        buffer.writeln('${i + 1}. ${vulnerabilities[i]}');
      }
      buffer.writeln();
    }

    // Recommendations Section
    if (recommendations.isNotEmpty) {
      buffer.writeln('RECOMMENDED ACTIONS:');
      for (var i = 0; i < recommendations.length; i++) {
        final rec = recommendations[i];
        buffer.writeln('\n${i + 1}. ${rec['title']} [${rec['priority']}]');
        buffer.writeln('   ${rec['description']}');
        buffer.writeln('   Steps:');
        for (var action in rec['actions'] as List) {
          buffer.writeln('   • $action');
        }
      }
    }

    return buffer.toString();
  }
}
