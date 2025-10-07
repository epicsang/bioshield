// lib/screens/pricing_screen.dart
// Pricing screen — matches Wireframe 7.8
// Handles real payment simulation and Firestore update for Premium status

import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../auth/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';
import '../models/user_model.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kSkyBlue,
        title: const Text("Pricing Plans", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
        foregroundColor: kAuthNavy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kAuthNavy),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Choose Your Plan",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kAuthNavy),
            ),
            const SizedBox(height: 10),
            const Text(
              "Unlock unlimited scans, full reports, export logs, and more.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // Monthly Plan Card
            _buildPlanCard(
              context,
              title: "Monthly Plan",
              price: "\$19.99/month",
              features: [
                "✓ Unlimited biometric scans",
                "✓ Full vulnerability reports",
                "✓ Export scan logs (PDF/CSV)",
                "✓ Real-time monitoring (coming soon)",
                "✓ Federated learning contribution",
              ],
              onSubscribe: () => _showPaymentOverlay(context, "Monthly"),
            ),

            const SizedBox(height: 20),

            // Yearly Plan Card
            _buildPlanCard(
              context,
              title: "Yearly Plan",
              price: "\$199.99/year",
              features: [
                "✓ Everything in Monthly Plan",
                "✓ 16% savings vs monthly",
                "✓ Priority support",
                "✓ Early access to new features",
              ],
              onSubscribe: () => _showPaymentOverlay(context, "Yearly"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, {
    required String title,
    required String price,
    required List<String> features,
    required VoidCallback onSubscribe,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: kAuthNavy, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(price, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kAuthNavy)),
          const SizedBox(height: 15),
          ...features.map((feature) => Text(feature)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kSkyBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onSubscribe,
              child: Text("Subscribe", style: TextStyle(fontSize: 16, color: kAuthNavy, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentOverlay(BuildContext context, String plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kAuthNavy,
        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        contentTextStyle: const TextStyle(color: Colors.white),
        title: Text("💳 Payment Details - $plan"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Card Number", style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                decoration: InputDecoration(
                  hintText: "1234 5678 9012 3456",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 15),
              const Text("Expiry Date", style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "MM",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "YY",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Text("CVV", style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  hintText: "123",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kSkyBlue),
            onPressed: () {
              Navigator.pop(ctx);
              // Simulate payment processing
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Processing payment...")),
              );

              Future.delayed(const Duration(seconds: 2), () async {
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("User not logged in")),
                    );
                    return;
                  }

                  // Update user document in Firestore — set isPremium = true
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({
                    'membership.isPremium': true,
                    'membership.subscriptionStart': FieldValue.serverTimestamp(),
                    'membership.subscriptionEnd': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
                  });

                  // Show success dialog
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: kAuthNavy,
                      titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      contentTextStyle: const TextStyle(color: Colors.white),
                      title: const Text("🎉 Payment Successful!"),
                      content: const Text("You are now a Premium user! Enjoy unlimited scans and full reports!"),
                      actions: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: kSkyBlue),
                          onPressed: () {
                            Navigator.pop(ctx); // Close dialog
                            Navigator.pop(context); // Close pricing screen
                            // Refresh Dashboard to reflect Premium status
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DashboardScreen(
                                  user: UserModel(
                                    uid: user.uid,
                                    username: "Loading...",
                                    email: user.email ?? "user@example.com",
                                    isPremium: true,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Text("Go to Dashboard", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  print("Error upgrading to Premium: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to upgrade. Please try again.")),
                  );
                }
              });
            },
            child: Text("Pay Now", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}