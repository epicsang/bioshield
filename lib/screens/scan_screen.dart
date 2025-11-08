//original scan_screen

// lib/screens/scan_screen.dart
// Scan Screen — Simulates biometric authentication via Frida hooking
// Shows "Waiting for response" + 2 buttons to simulate good/bad result
// Matches Wireframes 7.14 (Free) and 7.16 (Premium)

import 'package:flutter/material.dart';
import 'dart:async';
import '../constants/colors.dart';

class ScanScreen extends StatefulWidget {
  final bool isPremium;

  const ScanScreen({super.key, required this.isPremium});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isWaiting = true;
  int _countdown = 60; // 👈 60-second timeout
  late Timer _timer;
  String _statusMessage = "Waiting for biometric authentication response..."; // 👈 FIXED: Declare _statusMessage

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        _simulateTimeout();
      }
    });
  }

  void _simulateTimeout() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Scan timed out. Please try again.")),
    );
    Navigator.pop(context);
  }

  void _simulateScan(bool isSuccess) {
    _timer.cancel(); // 👈 Cancel timer on action
    setState(() {
      _isWaiting = false;
      _statusMessage = isSuccess
          ? "Biometric authentication successful. Analyzing security..."
          : "Biometric authentication failed. No data captured.";
    });

    // Simulate analysis delay
    Future.delayed(const Duration(seconds: 2), () {
      // Generate random risk score if success
      int riskScore = isSuccess ? 40 + DateTime.now().millisecond % 55 : 0;
      String biometricType = "fingerprint";

      // Return result to DashboardScreen
      Navigator.pop(context, {
        'riskScore': riskScore,
        'biometricType': biometricType,
        'status': isSuccess ? "completed" : "failed",
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // 👈 Cancel timer on dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kSkyBlue,
        title: const Text("Run Biometric Scan", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
        foregroundColor: kAuthNavy,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status message with countdown
              Text(
                _isWaiting
                    ? "Waiting for biometric authentication response... ($_countdown s)"
                    : _statusMessage, // 👈 Now defined
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kAuthNavy),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Progress indicator if waiting
              if (_isWaiting)
                const CircularProgressIndicator(color: kAuthNavy),
              const SizedBox(height: 40),

              // Action buttons (only if waiting)
              if (_isWaiting)
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => _simulateScan(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
                      ),
                      child: const Text(
                        "Simulate Successful Scan",
                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => _simulateScan(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
                      ),
                      child: const Text(
                        "Simulate Failed Scan",
                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}