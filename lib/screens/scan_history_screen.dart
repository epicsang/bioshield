// lib/screens/scan_history_screen.dart
// Scan History Screen — groups scans by day, tap to view details
// Matches Wireframes 7.9a (Free) and 7.9b (Premium)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/colors.dart';
import '../models/user_model.dart';
import 'pricing_screen.dart';
import 'scan_details_screen.dart';



class ScanHistoryScreen extends StatelessWidget {
  final bool isPremium;
  final String jsonAssetPath;
  const ScanHistoryScreen({super.key,
    required this.isPremium,
    required this.jsonAssetPath});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('scans')
            .orderBy('timestamp', descending: true)
            .limit(isPremium ? 100 : 1)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No scans found. Run a scan from the Dashboard to get started.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final scans = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Scan History",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kAuthNavy),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView.builder(
                  itemCount: scans.length,
                  itemBuilder: (context, index) {
                    final scan = scans[index];
                    final timestamp = (scan['timestamp'] as Timestamp).toDate();
                    final score = (scan['riskScore'] as double).toInt();
                    final summary = scan['resultSummary'] as String;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScanDetailsScreen(
                              scan: scan,
                              isPremium: isPremium,
                              jsonAssetPath: jsonAssetPath,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Scan at ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (scan['status'] == 'failed')
                                    const Text(
                                      "Authentication Failed",
                                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                    ),
                                  if (!isPremium && scan['status'] != 'failed')
                                    Text(
                                      summary,
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            if (scan['status'] != 'failed')
                              Text(
                                "$score/100",
                                style: TextStyle(
                                  color: _getScoreColor(score),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (scan['status'] == 'failed')
                              const Icon(Icons.error, color: Colors.red),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              if (isPremium)
                ElevatedButton(
                  onPressed: () {
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    "Export Report",
                    style: TextStyle(fontSize: 16, color: kAuthNavy, fontWeight: FontWeight.bold),
                  ),
                ),

              if (!isPremium)
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
                          "Upgrade to Premium to view full scan history, export reports, and access detailed vulnerability analysis with actionable tips.",
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
          );
        },
      ),
    );
  }
}

Color _getScoreColor(int score) {
  if (score >= 80) return Colors.green;
  if (score >= 60) return Colors.orange;
  return Colors.red;
}