// lib/screens/scan_screen.dart
// Scan Screen — Monitors shared folder for Frida biometric logs
// Automatically detects and processes logs from any app

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/colors.dart';
import '../services/frida_log_processor.dart';
import '../services/permissions_service.dart';

class ScanScreen extends StatefulWidget {
  final bool isPremium;

  const ScanScreen({super.key, required this.isPremium});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isMonitoring = false;
  bool _isProcessing = false;
  String _statusMessage = "Ready to monitor";
  Timer? _checkTimer;
  int _logCount = 0;
  String _detectedPackage = "";

  // Log file path - matches Frida script
  static const String LOG_PATH = "/storage/emulated/0/Download/BioShield/logs.jsonl";

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    // Check permissions first
    final hasPermission = await PermissionsService.requestPermissionForScan(context);
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Storage permission required to read biometric logs'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isMonitoring = true;
      _statusMessage = "Monitoring for biometric logs...";
      _logCount = 0;
      _detectedPackage = "";
    });

    // Start checking for log files periodically
    _checkTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await _checkForNewLogs();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Monitoring started\nWatching: $LOG_PATH'),
          backgroundColor: kSkyBlue,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _stopMonitoring() async {
    _checkTimer?.cancel();
    setState(() {
      _isMonitoring = false;
      _statusMessage = "Monitoring stopped";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Monitoring stopped'),
      ),
    );
  }

  Future<void> _checkForNewLogs() async {
    if (_isProcessing || !_isMonitoring) return;

    try {
      // Check if log file exists
      final file = File(LOG_PATH);
      final exists = await file.exists();

      if (!exists) {
        setState(() {
          _statusMessage = "Waiting for biometric logs...\nNo log file found yet";
          _logCount = 0;
          _detectedPackage = "";
        });
        return;
      }

      // Count log entries
      final lines = await file.readAsLines();
      final nonEmptyLines = lines.where((line) => line.trim().isNotEmpty).toList();

      if (nonEmptyLines.isEmpty) {
        setState(() {
          _statusMessage = "Log file exists but empty\nWaiting for biometric events...";
          _logCount = 0;
          _detectedPackage = "";
        });
        return;
      }

      // Try to detect package name from first log entry
      String packageName = "unknown";
      try {
        // The log processor will decrypt and extract the package name
        // For now, just show we found logs
        setState(() {
          _isProcessing = true;
          _logCount = nonEmptyLines.length;
          _statusMessage = "Found ${nonEmptyLines.length} log entries!\nProcessing biometric data...";
        });
      } catch (e) {
        // Continue with processing
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isProcessing = false;
          _statusMessage = "Error: Not logged in";
        });
        return;
      }

      // Process the logs - processor will extract package name from logs
      final processor = FridaLogProcessor();

      // Read first log to get package name
      try {
        final firstLog = await processor.readAndDecryptLogs();
        if (firstLog.isNotEmpty && firstLog.first['package'] != null) {
          packageName = firstLog.first['package'];
          setState(() {
            _detectedPackage = packageName;
          });
        }
      } catch (e) {
        print('[ScanScreen] Could not extract package name: $e');
      }

      final result = await processor.processAndUpload(
        userId: user.uid,
        isPremium: widget.isPremium,
        packageName: packageName,
        appName: packageName.split('.').last,
      );

      if (result.success && result.scanData != null) {
        // Success! Stop monitoring
        _checkTimer?.cancel();
        setState(() {
          _isMonitoring = false;
          _isProcessing = false;
          _statusMessage = "Scan completed successfully!\nProcessed $_logCount events from $packageName";
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Scan completed!\nApp: $packageName\nEvents: $_logCount\n\nCheck Scan History for details.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }

        // Reset after delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _statusMessage = "Ready to monitor";
              _logCount = 0;
              _detectedPackage = "";
            });
          }
        });
      } else {
        // Processing failed
        setState(() {
          _isProcessing = false;
          _statusMessage = "Error: ${result.message}";
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('[ScanScreen] Error checking logs: $e');
      setState(() {
        _isProcessing = false;
        _statusMessage = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            // Title
            const Text(
              "Biometric Security Monitor",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kAuthNavy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Subtitle
            Text(
              widget.isPremium
                  ? "Automatically detect and analyze biometric authentication"
                  : "Automatically detect biometric authentication (3 scans/day)",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Status indicator
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isMonitoring ? kSkyBlue.withValues(alpha: 0.1) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isMonitoring ? kSkyBlue : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _isMonitoring ? Icons.radar : Icons.monitor_heart,
                    size: 60,
                    color: _isMonitoring ? kSkyBlue : Colors.grey,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _isMonitoring ? kAuthNavy : Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_detectedPackage.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: kAuthNavy.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kAuthNavy),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.apps, size: 16, color: kAuthNavy),
                          const SizedBox(width: 8),
                          Text(
                            _detectedPackage,
                            style: const TextStyle(
                              color: kAuthNavy,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_logCount > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: kSkyBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_logCount events detected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  if (_isProcessing) ...[
                    const SizedBox(height: 15),
                    const CircularProgressIndicator(color: kSkyBlue),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Start/Stop button
            ElevatedButton.icon(
              onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMonitoring ? Colors.red : kSkyBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
              label: Text(
                _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // File location info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder_open, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Monitoring Location',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LOG_PATH,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'How to Use',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Grant "Manage All Files" permission when prompted\n'
                    '2. Click "Start Monitoring"\n'
                    '3. Open any app with biometric authentication\n'
                    '4. BioShield automatically detects and analyzes logs\n'
                    '5. View detailed security reports in Scan History\n\n'
                    'Note: Works with any app using Frida hooks',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),

            if (!widget.isPremium) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kSkyBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kSkyBlue),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.star, color: kSkyBlue, size: 30),
                    const SizedBox(height: 8),
                    const Text(
                      'Upgrade to Premium',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kAuthNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Get unlimited scans, detailed ML analysis, and export reports',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
