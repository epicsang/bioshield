// lib/screens/pricing_screen.dart
// Pricing screen — Secure Stripe Payment Links integration
// No secret keys, no backend required

import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/payment_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';
import '../models/user_model.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  final PaymentService _paymentService = PaymentService();
  bool _isProcessing = false;

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
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                  const SizedBox(height: 10),

                  // Security Badge
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Secure payment by Stripe • No card details stored",
                            style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Monthly Plan Card
                  _buildPlanCard(
                    context,
                    title: "Monthly Plan",
                    price: "\$9.99/month",
                    savings: null,
                    features: [
                      "✓ Unlimited biometric scans",
                      "✓ Full vulnerability reports",
                      "✓ Export scan logs (PDF/CSV)",
                      "✓ Real-time monitoring",
                      "✓ Email support",
                    ],
                    plan: SubscriptionPlan.monthly,
                  ),

                  const SizedBox(height: 20),

                  // Yearly Plan Card (with savings badge)
                  _buildPlanCard(
                    context,
                    title: "Yearly Plan",
                    price: "\$99.99/year",
                    savings: "Save \$19.89 (17%)",
                    features: [
                      "✓ Everything in Monthly Plan",
                      "✓ 17% savings vs monthly",
                      "✓ Priority support",
                      "✓ Early access to new features",
                      "✓ Annual security reports",
                    ],
                    plan: SubscriptionPlan.yearly,
                    isRecommended: true,
                  ),

                  const SizedBox(height: 30),

                  // How it works section
                  _buildHowItWorks(),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String title,
    required String price,
    String? savings,
    required List<String> features,
    required SubscriptionPlan plan,
    bool isRecommended = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(
          color: isRecommended ? Colors.green : kAuthNavy,
          width: isRecommended ? 3 : 2,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isRecommended ? Colors.green.shade50 : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "BEST VALUE",
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            price,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kAuthNavy),
          ),
          if (savings != null) ...[
            const SizedBox(height: 5),
            Text(
              savings,
              style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 15),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(feature, style: const TextStyle(fontSize: 14)),
              )),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecommended ? Colors.green : kSkyBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _handleSubscribe(plan),
              child: Text(
                "Subscribe Now",
                style: TextStyle(
                  fontSize: 16,
                  color: isRecommended ? Colors.white : kAuthNavy,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "How Payment Works",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kAuthNavy),
          ),
          const SizedBox(height: 12),
          _buildStep("1", "Click Subscribe to open secure Stripe payment page"),
          _buildStep("2", "Enter your payment details on Stripe (not stored in our app)"),
          _buildStep("3", "Complete payment and you'll be redirected back"),
          _buildStep("4", "Your account will be upgraded to Premium automatically"),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Powered by Stripe - Industry-leading payment security",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                number,
                style: TextStyle(
                  color: kAuthNavy,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubscribe(SubscriptionPlan plan) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to subscribe")),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kAuthNavy,
        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        contentTextStyle: const TextStyle(color: Colors.white),
        title: Text(plan == SubscriptionPlan.monthly ? "Subscribe Monthly?" : "Subscribe Yearly?"),
        content: Text(
          "You will be redirected to Stripe to complete the payment of ${PaymentService.getPricing(plan).toStringAsFixed(2)} USD.\n\n"
          "Your account will be upgraded automatically after payment.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kSkyBlue),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              "Continue to Payment",
              style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      // Open Stripe Payment Link
      final result = await _paymentService.openPaymentLink(plan: plan);

      setState(() => _isProcessing = false);

      if (result.success) {
        // Show pending message
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: kAuthNavy,
            titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            contentTextStyle: const TextStyle(color: Colors.white),
            title: const Text("Payment In Progress"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: kSkyBlue),
                const SizedBox(height: 16),
                const Text(
                  "Complete your payment on the Stripe page.\n\n"
                  "Your account will be upgraded automatically once payment is confirmed.",
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context); // Go back to dashboard
                },
                child: const Text("I'll Complete Later", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errorMessage ?? "Failed to open payment page")),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
}
