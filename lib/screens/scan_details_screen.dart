// lib/screens/scan_details_screen.dart
// Scan Details Screen with Tabs: Overview, Timing Analysis, Mitigations

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../constants/colors.dart';

class ScanDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> scan;
  final bool isPremium;
  final String jsonAssetPath;

  const ScanDetailsScreen({
    super.key,
    required this.scan,
    required this.isPremium,
    required this.jsonAssetPath,
  });

  @override
  State<ScanDetailsScreen> createState() => _ScanDetailsScreenState();
}

class _ScanDetailsScreenState extends State<ScanDetailsScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? scanData;
  late TabController _tabController;
  Map<String, dynamic>? deviceInfo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadScanData();
    _loadDeviceInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;

      setState(() {
        deviceInfo = {
          'manufacturer': androidInfo.manufacturer,
          'model': androidInfo.model,
          'device': androidInfo.device,
          'androidVersion': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt.toString(),
          'brand': androidInfo.brand,
          'fingerprint': androidInfo.fingerprint,
        };
      });
    } catch (e) {
      print('[ScanDetails] Error loading device info: $e');
    }
  }

  Future<void> _loadScanData() async {
    final sideChannelData = widget.scan['side_channel_analysis'] as Map<String, dynamic>? ?? {};
    final vulnerabilities = (sideChannelData['vulnerabilities'] as List?)?.cast<String>() ?? [];

    // Handle timestamp
    final timestampValue = widget.scan['timestamp'];
    String timestampString;
    if (timestampValue is Timestamp) {
      timestampString = timestampValue.toDate().toString();
    } else if (timestampValue is DateTime) {
      timestampString = timestampValue.toString();
    } else {
      timestampString = DateTime.now().toString();
    }

    setState(() {
      scanData = {
        'metadata': {
          'scanId': widget.scan['scanId'] ?? widget.scan['id'] ?? 'unknown',
          'timestamp': timestampString,
          'appName': widget.scan['app_name'] ?? 'Unknown App',
          'packageName': widget.scan['package_name'] ?? 'Unknown',
          'riskScore': ((widget.scan['riskScore'] ?? 0) as num).toInt(),
        },
        'vulnerabilities': vulnerabilities,
        'sideChannelData': sideChannelData,
        'mlResults': {
          'spoofDetection': sideChannelData['ml_spoof_result'],
          'anomalyDetection': sideChannelData['ml_anomaly_result'],
        },
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (scanData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final meta = scanData!['metadata'];

    return Scaffold(
      appBar: AppBar(
        title: Text('${meta['appName']} - Scan Details'),
        backgroundColor: kSkyBlue,
        foregroundColor: kAuthNavy,
        bottom: TabBar(
          controller: _tabController,
          labelColor: kAuthNavy,
          unselectedLabelColor: kAuthNavy.withValues(alpha: 0.6),
          indicatorColor: kAuthNavy,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.timer), text: 'Timing'),
            Tab(icon: Icon(Icons.security), text: 'Mitigations'),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildTimingTab(),
          _buildMitigationsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final meta = scanData!['metadata'];
    final vulns = scanData!['vulnerabilities'] as List;
    final mlResults = scanData!['mlResults'] as Map<String, dynamic>;
    final score = meta['riskScore'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Risk Score Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _getScoreColor(score).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getScoreColor(score), width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Security Score', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text('$score/100', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _getScoreColor(score))),
                  ],
                ),
                Icon(_getScoreIcon(score), size: 60, color: _getScoreColor(score)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Metadata
          const Text('Scan Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kAuthNavy)),
          const SizedBox(height: 10),
          _buildInfoRow('Scan ID', meta['scanId']),
          _buildInfoRow('Timestamp', meta['timestamp']),
          _buildInfoRow('App Name', meta['appName']),
          _buildInfoRow('Package', meta['packageName']),

          if (deviceInfo != null) ...[
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),
            const Text('Device Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kAuthNavy)),
            const SizedBox(height: 10),
            _buildInfoRow('Manufacturer', deviceInfo!['manufacturer']),
            _buildInfoRow('Model', deviceInfo!['model']),
            _buildInfoRow('Android', '${deviceInfo!['androidVersion']} (API ${deviceInfo!['sdkInt']})'),
            _buildInfoRow('Brand', deviceInfo!['brand']),
          ],

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),

          // Vulnerabilities
          const Text('Detected Threats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kAuthNavy)),
          const SizedBox(height: 10),
          if (vulns.isEmpty)
            const Text('No vulnerabilities detected', style: TextStyle(color: Colors.green))
          else
            ...vulns.map((v) => _buildVulnerabilityCard(v)),

          // ML Results
          if (mlResults['spoofDetection'] != null || mlResults['anomalyDetection'] != null) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            const Text('ML Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kAuthNavy)),
            const SizedBox(height: 10),
            if (mlResults['spoofDetection'] != null) _buildMLResultCard('Spoof Detection', mlResults['spoofDetection']),
            if (mlResults['anomalyDetection'] != null) _buildMLResultCard('Anomaly Detection', mlResults['anomalyDetection']),
          ],
        ],
      ),
    );
  }

  Widget _buildTimingTab() {
    // Check if timing data exists
    final vulns = scanData!['vulnerabilities'] as List<String>;

    final hasTimingAttacks = vulns.any((v) => v.contains('TIMING') || v.contains('CONSTANT_TIME') || v.contains('CORRELATION'));

    if (!hasTimingAttacks) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 80, color: Colors.green.shade300),
              const SizedBox(height: 20),
              const Text('No Timing Vulnerabilities', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('This scan did not detect any timing-related security issues.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Timing Attack Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kAuthNavy)),
          const SizedBox(height: 10),
          const Text('Timing attacks exploit predictable delays in biometric authentication to bypass security.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),

          ...vulns.where((v) => v.contains('TIMING') || v.contains('CONSTANT_TIME') || v.contains('CORRELATION')).map((v) => _buildVulnerabilityCard(v)),

          const SizedBox(height: 20),
          const Text('Recommendations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildRecommendationCard('Implement constant-time authentication', 'Ensure all authentication paths take the same amount of time'),
          _buildRecommendationCard('Add random delays', 'Introduce 50-150ms random delays to mask timing patterns'),
          _buildRecommendationCard('Use secure timing functions', 'Avoid timing-dependent conditional branches'),
        ],
      ),
    );
  }

  Widget _buildMitigationsTab() {
    final vulns = scanData!['vulnerabilities'] as List<String>;
    final score = scanData!['metadata']['riskScore'] as int;

    if (vulns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user, size: 80, color: Colors.green.shade300),
              const SizedBox(height: 20),
              const Text('Secure Implementation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('No security vulnerabilities detected. Continue following best practices.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Security Recommendations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kAuthNavy)),
          const SizedBox(height: 10),
          Text('Based on $score/100 security score, here are recommended fixes:', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),

          // Generate mitigations for each threat
          ...vulns.map((v) => _buildMitigationSection(v)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildVulnerabilityCard(String vulnerability) {
    // Parse vulnerability type and details
    final parts = vulnerability.split(':');
    final vulnType = parts.isNotEmpty ? parts[0].trim() : 'UNKNOWN';
    final vulnDetails = parts.length > 1 ? parts.sublist(1).join(':').trim() : 'No details available';

    // Get user-friendly info
    final info = _getVulnerabilityInfo(vulnType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: info['color'].withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: info['color'], width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(info['icon'], color: info['color'], size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    info['title'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: info['color'],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info['description'],
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.analytics, size: 16, color: kAuthNavy),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vulnDetails,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getVulnerabilityInfo(String vulnType) {
    switch (vulnType) {
      case 'CONSTANT_TIME_LEAK':
        return {
          'title': 'Constant-Time Leak Detected',
          'description': 'The authentication timing is too consistent, suggesting automated/scripted attacks rather than human interaction.',
          'icon': Icons.speed,
          'color': Colors.red,
        };
      case 'TIMING_CHANNEL_EXPLOIT':
        return {
          'title': 'Timing Channel Exploitation',
          'description': 'Extremely high timing variance detected, indicating possible timing-based probing attacks.',
          'icon': Icons.query_stats,
          'color': Colors.red,
        };
      case 'LOW_TIMING_ENTROPY':
        return {
          'title': 'Low Timing Entropy',
          'description': 'The timing patterns lack randomness expected from natural human behavior, suggesting replay or automation.',
          'icon': Icons.shuffle_on_outlined,
          'color': Colors.orange,
        };
      case 'ML_SPOOF_DETECTED':
        return {
          'title': 'ML Spoof Detection Alert',
          'description': 'Machine learning model detected potential spoofing attempt based on biometric patterns.',
          'icon': Icons.psychology,
          'color': Colors.red,
        };
      case 'ML_ANOMALY_DETECTED':
        return {
          'title': 'ML Anomaly Detected',
          'description': 'Unusual authentication patterns detected that deviate from normal behavior.',
          'icon': Icons.warning_amber_rounded,
          'color': Colors.orange,
        };
      case 'TIMING_ATTACK':
        return {
          'title': 'Timing Attack Vulnerability',
          'description': 'Authentication completed too quickly, making it vulnerable to timing-based attacks.',
          'icon': Icons.timer_off,
          'color': Colors.red,
        };
      case 'REPLAY_ATTACK':
        return {
          'title': 'Replay Attack Detected',
          'description': 'Authentication can be replayed without proper session validation or nonce implementation.',
          'icon': Icons.replay,
          'color': Colors.red,
        };
      default:
        return {
          'title': vulnType.replaceAll('_', ' ').toLowerCase().split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' '),
          'description': 'A security vulnerability was detected in the biometric authentication flow.',
          'icon': Icons.security,
          'color': Colors.orange,
        };
    }
  }

  Widget _buildMLResultCard(String title, Map<String, dynamic> result) {
    final classification = result['classification'] ?? 'unknown';
    final confidence = ((result['confidence'] ?? 0) * 100).toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Classification: $classification'),
            Text('Confidence: $confidence%'),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(String title, String description) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMitigationSection(String vulnerability) {
    // Parse vulnerability type and details
    final parts = vulnerability.split(':');
    final vulnType = parts.isNotEmpty ? parts[0].trim() : 'UNKNOWN';
    final vulnDetails = parts.length > 1 ? parts.sublist(1).join(':').trim() : '';

    String title = 'Security Mitigation';
    String description = 'Implement security best practices';
    List<Map<String, String>> steps = [];
    String priority = 'Medium';
    Color priorityColor = Colors.orange;

    switch (vulnType) {
      case 'CONSTANT_TIME_LEAK':
        title = 'Fix Constant-Time Leak';
        description = vulnDetails.isNotEmpty ? vulnDetails : 'Authentication timing is too consistent';
        priority = 'High';
        priorityColor = Colors.red;
        steps = [
          {
            'title': 'Add Timing Randomization',
            'detail': 'Introduce random delays between 50-150ms to mask timing patterns',
            'code': 'Thread.sleep((50 + Random().nextInt(100)).toLong())'
          },
          {
            'title': 'Implement Noise Injection',
            'detail': 'Add computational noise to prevent timing analysis',
            'code': 'val noise = System.nanoTime() % 1000'
          },
          {
            'title': 'Use Constant-Time Operations',
            'detail': 'Ensure all authentication paths take the same time regardless of input',
            'code': 'MessageDigest.isEqual(a, b) // timing-safe comparison'
          },
        ];
        break;

      case 'TIMING_CHANNEL_EXPLOIT':
        title = 'Fix Timing Channel Exploitation';
        description = vulnDetails.isNotEmpty ? vulnDetails : 'High timing variance detected';
        priority = 'Critical';
        priorityColor = Colors.red.shade900;
        steps = [
          {
            'title': 'Implement Rate Limiting',
            'detail': 'Limit authentication attempts to prevent timing probes',
            'code': 'val maxAttempts = 3; val cooldown = 30000ms'
          },
          {
            'title': 'Add Fixed Authentication Window',
            'detail': 'Set minimum and maximum authentication times',
            'code': 'val minAuthTime = 200; val maxAuthTime = 2000'
          },
          {
            'title': 'Monitor for Attack Patterns',
            'detail': 'Detect and block rapid authentication attempts',
            'code': 'if (attempts > threshold) blockUser()'
          },
        ];
        break;

      case 'LOW_TIMING_ENTROPY':
        title = 'Fix Low Timing Entropy';
        description = vulnDetails.isNotEmpty ? vulnDetails : 'Timing patterns lack randomness';
        priority = 'High';
        priorityColor = Colors.orange.shade900;
        steps = [
          {
            'title': 'Increase Timing Randomness',
            'detail': 'Add more variability to authentication timing',
            'code': 'val delay = SecureRandom().nextInt(200) + 100'
          },
          {
            'title': 'Implement Jitter',
            'detail': 'Add unpredictable delays throughout the authentication flow',
            'code': 'Thread.sleep(Random().nextInt(50).toLong())'
          },
          {
            'title': 'Use Hardware RNG',
            'detail': 'Leverage hardware random number generation for timing',
            'code': 'SecureRandom.getInstanceStrong()'
          },
        ];
        break;

      case 'ML_SPOOF_DETECTED':
        title = 'Fix ML Spoof Detection Alert';
        description = vulnDetails.isNotEmpty ? vulnDetails : 'ML model detected spoofing attempt';
        priority = 'Critical';
        priorityColor = Colors.red.shade900;
        steps = [
          {
            'title': 'Enable Liveness Detection',
            'detail': 'Use BiometricPrompt with STRONG authentication',
            'code': 'setAllowedAuthenticators(BIOMETRIC_STRONG)'
          },
          {
            'title': 'Implement CryptoObject',
            'detail': 'Bind biometric to cryptographic operations',
            'code': 'BiometricPrompt.CryptoObject(cipher)'
          },
          {
            'title': 'Add Challenge-Response',
            'detail': 'Verify biometric freshness with server nonce',
            'code': 'val nonce = server.getNonce(); verify(biometric, nonce)'
          },
          {
            'title': 'Enable Hardware-Backed Storage',
            'detail': 'Use StrongBox or TEE for biometric keys',
            'code': 'setIsStrongBoxBacked(true)'
          },
        ];
        break;

      case 'ML_ANOMALY_DETECTED':
        title = 'Fix ML Anomaly Detection';
        description = vulnDetails.isNotEmpty ? vulnDetails : 'Unusual authentication patterns detected';
        priority = 'High';
        priorityColor = Colors.orange.shade900;
        steps = [
          {
            'title': 'Review Authentication Flow',
            'detail': 'Check for automated or scripted access patterns',
            'code': 'Review logs for: rapid attempts, perfect timing'
          },
          {
            'title': 'Implement Rate Limiting',
            'detail': 'Prevent brute-force and automated attacks',
            'code': 'val maxAttemptsPerHour = 10'
          },
          {
            'title': 'Add Behavioral Analysis',
            'detail': 'Monitor user behavior patterns over time',
            'code': 'trackUserBehavior(userId, authPattern)'
          },
          {
            'title': 'Enable MFA for Anomalies',
            'detail': 'Require additional verification for unusual patterns',
            'code': 'if (isAnomalous) requestSecondFactor()'
          },
        ];
        break;

      case 'TIMING_ATTACK':
        title = 'Fix Timing Attack Vulnerability';
        description = vulnDetails.isNotEmpty ? vulnDetails : 'Authentication too fast';
        priority = 'High';
        priorityColor = Colors.red;
        steps = [
          {
            'title': 'Set Minimum Authentication Time',
            'detail': 'Ensure authentication takes at least 200ms',
            'code': 'val startTime = System.currentTimeMillis()\nval elapsed = System.currentTimeMillis() - startTime\nif (elapsed < 200) Thread.sleep(200 - elapsed)'
          },
          {
            'title': 'Add Processing Delays',
            'detail': 'Introduce computational work to extend auth time',
            'code': 'PBKDF2.hash(biometric, iterations=1000)'
          },
        ];
        break;

      case 'REPLAY_ATTACK':
        title = 'Fix Replay Attack Vulnerability';
        description = vulnDetails.isNotEmpty ? vulnDetails : 'Authentication can be replayed';
        priority = 'Critical';
        priorityColor = Colors.red.shade900;
        steps = [
          {
            'title': 'Implement Nonce-Based Auth',
            'detail': 'Use one-time tokens that cannot be reused',
            'code': 'val nonce = UUID.randomUUID(); validateOnce(nonce)'
          },
          {
            'title': 'Add Timestamp Validation',
            'detail': 'Reject authentication attempts older than 60 seconds',
            'code': 'if (timestamp < now - 60000) reject()'
          },
          {
            'title': 'Use Session Tokens',
            'detail': 'Bind biometric to unique session identifiers',
            'code': 'val sessionId = createSession(); bind(biometric, sessionId)'
          },
        ];
        break;

      default:
        title = 'Security Mitigation Required';
        description = vulnDetails.isNotEmpty ? vulnDetails : 'Security vulnerability detected';
        steps = [
          {
            'title': 'Review Security Best Practices',
            'detail': 'Follow Android biometric security guidelines',
            'code': 'https://developer.android.com/training/sign-in/biometric-auth'
          },
        ];
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Icon(Icons.build_circle, color: priorityColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Priority: $priority',
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.construction, size: 20, color: kAuthNavy),
                    SizedBox(width: 8),
                    Text('Implementation Steps:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 12),
                ...steps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final step = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: kSkyBlue,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: kAuthNavy,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                step['title']!,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          step['detail']!,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: kAuthNavy.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: kAuthNavy.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.code, size: 16, color: kAuthNavy),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  step['code']!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: kAuthNavy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _getScoreIcon(int score) {
    if (score >= 80) return Icons.check_circle;
    if (score >= 60) return Icons.warning;
    return Icons.error;
  }
}
