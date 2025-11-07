import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class BiometricAnalyzerPage extends StatefulWidget {
  const BiometricAnalyzerPage({Key? key}) : super(key: key);

  @override
  State<BiometricAnalyzerPage> createState() => _BiometricAnalyzerPageState();
}

class _BiometricAnalyzerPageState extends State<BiometricAnalyzerPage> {
  Map<String, dynamic>? _analysisResult;

  @override
  void initState() {
    super.initState();
    requestStoragePermission();
  }

  Future<void> requestStoragePermission() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Storage permission required")),
      );
    }
  }

  Future<void> pickAndAnalyzeFile() async {
    try {
      // Path: /storage/emulated/0/Download/
      final Directory downloadsDir = Directory("/storage/emulated/0/Download/");
      final List<FileSystemEntity> files = downloadsDir.listSync();

      // Find latest .json file
      final jsonFiles = files
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (jsonFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No JSON files found in Downloads.")),
        );
        return;
      }

      final File selectedFile = jsonFiles.first;
      final content = await selectedFile.readAsString();
      final output = analyzeScan(content);

      setState(() => _analysisResult = output);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Analyzed: ${selectedFile.path.split('/').last}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error reading file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to read JSON file.")),
      );
    }
  }

  /// Local rule-based analyzer (runs fully on-device)
  Map<String, dynamic> analyzeScan(String jsonContent) {
    final Map<String, dynamic> data = json.decode(jsonContent);
    int score = 0;
    List<String> weaknesses = [];
    List<String> recommendations = [];

    // === Rule-based checks ===
    if (data['hasCrypto'] == false) {
      score += 20;
      weaknesses.add("Missing CryptoObject validation");
      recommendations.add("Ensure proper CryptoObject usage with BiometricPrompt API");
    }

    if (data['tls_ok_hint'] == false) {
      score += 25;
      weaknesses.add("Weak or missing TLS configuration");
      recommendations.add("Upgrade to TLS 1.3 and enable certificate pinning");
    }

    if (data['durationMs'] != null && data['durationMs'] < 200) {
      score += 10;
      weaknesses.add("Suspiciously short authentication duration");
      recommendations.add("Review timing to detect possible replay or bypass attacks");
    }

    if (data['hooked_flag'] == true) {
      score += 30;
      weaknesses.add("Possible Frida hook detected");
      recommendations.add("Add anti-tampering protection and secure runtime checks");
    }

    if (data['network_flag'] == true) {
      score += 15;
      weaknesses.add("Biometric data may be transmitted over insecure network");
      recommendations.add("Encrypt biometric payloads and disable HTTP calls");
    }

    // Normalize score
    score = score.clamp(0, 100);

    return {
      "risk_score": score,
      "weaknesses": weaknesses,
      "recommendations": recommendations,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Biometric Vulnerability Analyzer")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: pickAndAnalyzeFile,
              icon: const Icon(Icons.analytics),
              label: const Text("Analyze Latest Biometric JSON"),
            ),
            const SizedBox(height: 20),

            if (_analysisResult != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Card(
                    color: Colors.grey[100],
                    margin: const EdgeInsets.all(8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("🔍 Analysis Results",
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          Text(
                            "Risk Score: ${_analysisResult!['risk_score']} / 100",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _analysisResult!['risk_score'] / 100,
                            color: _analysisResult!['risk_score'] > 70
                                ? Colors.red
                                : Colors.orangeAccent,
                            minHeight: 10,
                          ),
                          const SizedBox(height: 20),
                          const Text("⚠️ Weaknesses:",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ...?_analysisResult!['weaknesses']
                              ?.map<Widget>((w) => Text("• $w"))
                              .toList(),
                          const SizedBox(height: 20),
                          const Text("🛠 Recommendations:",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ...?_analysisResult!['recommendations']
                              ?.map<Widget>((r) => Text("• $r"))
                              .toList(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
