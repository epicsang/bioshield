// lib/widgets/scan_limit_overlay.dart
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../screens/pricing_screen.dart';

class ScanLimitOverlay extends StatelessWidget {
  const ScanLimitOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: kSkyBlue, // 👈 Sky blue background
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kAuthNavy, width: 1), // 👈 Navy border
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: kAuthNavy, size: 20), // 👈 Navy icon
                  const SizedBox(width: 8),
                  Text(
                    "Scan Limit Reached",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kAuthNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "You've used all 3 free scans for today. Upgrade to Premium for unlimited scans and full vulnerability reports.",
                style: TextStyle(color: kAuthNavy),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSkyBlue, // 👈 Sky blue button
                    foregroundColor: kAuthNavy,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PricingScreen()),
                    );
                  },
                  child: const Text("View Pricing"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}