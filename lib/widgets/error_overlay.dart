// lib/widgets/error_overlay.dart
import 'package:flutter/material.dart';
import '../constants/colors.dart';

class ErrorOverlay extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorOverlay({
    super.key,
    required this.message,
    required this.onRetry,
  });

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
                  Icon(Icons.error, color: kAuthNavy, size: 20), // 👈 Navy icon
                  const SizedBox(width: 8),
                  Text(
                    "Error",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kAuthNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message,
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
                    onRetry();
                  },
                  child: const Text("Try Again"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}