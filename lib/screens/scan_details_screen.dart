// lib/screens/scan_details_screen.dart
// Shows full scan details when user taps a scan in history
// Matches Wireframes 7.15 (Free) and 7.17 (Premium)

import 'package:flutter/material.dart';
import 'pricing_screen.dart';
import '../constants/colors.dart';

class ScanDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> scan;
  final bool isPremium;

  const ScanDetailsScreen({
    super.key,
    required this.scan,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = (scan['timestamp'] as dynamic).toDate();
    final score = (scan['riskScore'] as double).toInt();
    final summary = scan['resultSummary'] as String;
    final biometricType = scan['biometricType'] as String;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kSkyBlue,
        title: const Text("Scan Details", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
        foregroundColor: kAuthNavy,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scan Info
            Text(
              "Scan on ${timestamp.toString().split(' ')[0]} at ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kAuthNavy),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  "Biometric Type: ",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(biometricType),
              ],
            ),
            const SizedBox(height: 20),

            // Security Score or Status
            if (scan['status'] == 'failed') ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        "Biometric Authentication Failed",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "No vulnerability data was captured. Please ensure biometric sensors are clean and try again.",
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: kSkyBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Security Score",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kAuthNavy,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "$score/100",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(score),
                        ),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: score / 100,
                        backgroundColor: Colors.grey[200],
                        color: _getScoreColor(score),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),

            // Vulnerability Analysis
            Text(
              "Vulnerability Analysis",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kAuthNavy,
              ),
            ),
            const SizedBox(height: 10),
            if (!isPremium) ...[
              Text(
                summary,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kSkyBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kSkyBlue, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, color: kSkyBlue),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Upgrade to Premium to see detailed vulnerability analysis and mitigation strategies.",
                        style: TextStyle(color: kSkyBlue),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PricingScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSkyBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text("Upgrade", style: TextStyle(fontSize: 12, color: kAuthNavy, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
            if (isPremium) ...[
              Text(summary),
              const SizedBox(height: 20),
              Text(
                "Recommendations",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kAuthNavy,
                ),
              ),
              const SizedBox(height: 10),
              ..._getRecommendations(score).map((tip) => Text("• $tip")),
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    // Show export overlay
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: kAuthNavy,
                        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        contentTextStyle: const TextStyle(color: Colors.white),
                        title: const Text("Export Scan Report"),
                        content: const Text("Choose export format:"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Exporting as PDF...")),
                              );
                            },
                            child: const Text("PDF", style: TextStyle(color: kSkyBlue, fontWeight: FontWeight.bold)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Exporting as CSV...")),
                              );
                            },
                            child: const Text("CSV", style: TextStyle(color: kSkyBlue, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSkyBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  ),
                  child: Text(
                    "Export Report",
                    style: TextStyle(fontSize: 16, color: kAuthNavy, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAuthNavy,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                ),
                child: const Text("Return to History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  List<String> _getRecommendations(int score) {
    if (score >= 80) {
      return [
        "Your biometric system is secure. No immediate action required.",
        "Consider periodic recalibration for optimal performance.",
        "Enable real-time monitoring for continuous security.",
      ];
    } else if (score >= 60) {
      return [
        "Implement API throttling to prevent timing-based attacks.",
        "Recalibrate sensor in low-noise environment for better accuracy.",
        "Avoid reusing biometric templates across sessions.",
        "Upgrade to premium for real-time monitoring and federated learning.",
      ];
    } else {
      return [
        "Immediate action required: Implement secure biometric protocols.",
        "Conduct full system audit for side-channel vulnerabilities.",
        "Consult security documentation for mitigation strategies.",
        "Upgrade to premium for detailed forensic analysis and expert support.",
      ];
    }
  }
}