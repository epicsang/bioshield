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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 32),
            const SizedBox(width: 12),
            Expanded(child: Text(vulnerability, style: const TextStyle(fontSize: 14))),
          ],
        ),
      ),
    );
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
    String title = 'Security Mitigation';
    String description = 'Implement security best practices';
    List<String> steps = [];

    if (vulnerability.contains('TIMING_ATTACK')) {
      title = 'Fix Timing Attack';
      description = 'Detected: Authentication completed in < 100ms, vulnerable to timing analysis';
      steps = [
        'Add minimum 200ms authentication time',
        'Implement constant-time operations',
        'Add random delays (50-150ms)',
        'Use secure timing functions',
      ];
    } else if (vulnerability.contains('CONSTANT_TIME')) {
      title = 'Fix Constant-Time Leak';
      description = 'Detected: Authentication timing variance detected';
      steps = [
        'Ensure all code paths take same time',
        'Avoid timing-dependent branches',
        'Use timing-safe comparison functions',
        'Add noise injection',
      ];
    } else if (vulnerability.contains('REPLAY_ATTACK')) {
      title = 'Fix Replay Attack';
      description = 'Detected: Authentication can be replayed';
      steps = [
        'Implement nonce-based authentication',
        'Add timestamp validation',
        'Use one-time tokens',
        'Implement session management',
      ];
    } else if (vulnerability.contains('ML_SPOOF')) {
      title = 'Fix ML Spoof Detection';
      description = 'Detected: ML model detected spoofing attempt';
      steps = [
        'Use BiometricPrompt with CryptoObject',
        'Enable liveness detection',
        'Implement challenge-response',
        'Add secondary verification',
      ];
    } else if (vulnerability.contains('ML_ANOMALY')) {
      title = 'Fix ML Anomaly Detection';
      description = 'Detected: Unusual authentication patterns';
      steps = [
        'Review authentication flow',
        'Implement rate limiting',
        'Add behavioral monitoring',
        'Check for automated attacks',
      ];
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: const Icon(Icons.build, color: kAuthNavy),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recommended Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...steps.map((step) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 16)),
                      Expanded(child: Text(step)),
                    ],
                  ),
                )),
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
