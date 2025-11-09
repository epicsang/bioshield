//original details screen
// lib/screens/scan_details_screen.dart
// Shows full scan details when user taps a scan in history
// Matches Wireframes 7.15 (Free) and 7.17 (Premium)



import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import '../constants/colors.dart';

class ScanDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> scan;
  final bool isPremium;
  final String jsonAssetPath; // e.g. 'assets/biometric_scan_01507198-...json'

  const ScanDetailsScreen({super.key,
    required this.scan,
    required this.isPremium,
    required this.jsonAssetPath});

  @override
  State<ScanDetailsScreen> createState() => _ScanDetailsScreenState();
}

class _ScanDetailsScreenState extends State<ScanDetailsScreen> {
  Map<String, dynamic>? scanData;
  @override
  void initState() {
    super.initState();
    _loadJsonFile();
  }

  Future<void> _loadJsonFile() async {
    // Change this line to the scanned JSON file name
    // Example: 'assets/biometric_scan_<unique-id>_autosave.json'
    final jsonStr = await rootBundle.loadString(
        'assets/biometric_scan_01507198-3e8d-42ce-bb92-ee115285c3f0_autosave.json');
    setState(() => scanData = json.decode(jsonStr));
  }

  bool _isEmpty(dynamic data) =>
      data == null ||
          (data is String && data.trim().isEmpty) ||
          (data is List && data.isEmpty) ||
          (data is Map && data.isEmpty);

  @override
  Widget build(BuildContext context) {
    if (scanData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final meta = scanData!['metadata'];
    final device = meta['deviceInfo'];
    final vulns = scanData!['vulnerabilities'] ?? [];
    final timing = scanData!['timingData'];
    final apiFindings = scanData!['apiFindings'];
    final cryptoFindings = scanData!['cryptoFindings'];
    final storageFindings = scanData!['storageFindings'];
    final networkFindings = scanData!['networkFindings'];
    final memoryFindings = scanData!['memoryFindings'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Details'),
        backgroundColor: kSkyBlue,
        foregroundColor: kAuthNavy,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            // --- METADATA ---
            Text("1. Metadata",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18, color: kAuthNavy)),
            const SizedBox(height: 6),
            Text("Scan ID: ${meta['scanId']}"),
            Text("Timestamp: ${meta['timestamp']}"),
            Text("Device: ${device['manufacturer']} ${device['model']} (${device['device']})"),
            Text("Android Version: ${device['androidVersion']} (SDK ${device['sdkInt']})"),
            Text("Brand: ${device['brand']}"),
            Text("Fingerprint: ${device['fingerprint']}"),

            const Divider(height: 30),

            // --- VULNERABILITIES ---
            if (!_isEmpty(vulns)) ...[
              Text("2. Vulnerabilities",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18, color: kAuthNavy)),
              const SizedBox(height: 8),
              ...vulns.map<Widget>((v) => Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${v['type']} (${v['severity']})",
                          style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                      Text("Category: ${v['category']}"),
                      Text("Title: ${v['title']}"),
                      if (!_isEmpty(v['description']))
                        Text("Description: ${v['description']}"),
                      if (!_isEmpty(v['impact']))
                        Text("Impact: ${v['impact']}"),
                      if (!_isEmpty(v['mitigation']))
                        Text("Mitigation: ${v['mitigation']}"),
                      Text("Detected At: ${v['detectedAt']}"),
                    ],
                  ),
                ),
              )),
              const Divider(height: 30),
            ],

            // --- TIMING DATA ---
            if (!_isEmpty(timing)) ...[
              Text("3. Timing Data",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18, color: kAuthNavy)),
              const SizedBox(height: 8),
              ...((timing['attempts'] ?? []) as List).map((a) => Text(
                  "Result: ${a['result']}, Duration: ${a['duration']}s, Timestamp: ${a['timestamp']}")),
              const Divider(height: 30),
            ],

            // --- API FINDINGS ---
            if (!_isEmpty(apiFindings)) ...[
              Text("4. API Findings",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18, color: kAuthNavy)),
              const SizedBox(height: 8),
              ...apiFindings.map<Widget>((f) {
                final d = f['details'];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(d?['title'] ?? 'No title'),
                  subtitle: Text(
                      "Type: ${f['type']} | Category: ${f['category']}\nSubtitle: ${d?['subtitle'] ?? 'N/A'}"),
                );
              }),
              const Divider(height: 30),
            ],

            // --- OTHER FINDINGS ---
            if (!_isEmpty(cryptoFindings) ||
                !_isEmpty(storageFindings) ||
                !_isEmpty(networkFindings) ||
                !_isEmpty(memoryFindings)) ...[
              Text("5. Other Findings",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18, color: kAuthNavy)),
              if (!_isEmpty(cryptoFindings)) Text("Crypto Findings: ${cryptoFindings.toString()}"),
              if (!_isEmpty(storageFindings)) Text("Storage Findings: ${storageFindings.toString()}"),
              if (!_isEmpty(networkFindings)) Text("Network Findings: ${networkFindings.toString()}"),
              if (!_isEmpty(memoryFindings)) Text("Memory Findings: ${memoryFindings.toString()}"),
              const Divider(height: 30),
            ],

            // --- EXPORT BUTTON ---
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _showExportOptions(context, scanData!),
                style: ElevatedButton.styleFrom(
                    backgroundColor: kSkyBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                icon: const Icon(Icons.download, color: kAuthNavy),
                label: const Text("Export Report",
                    style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ------------------------- EXPORT FUNCTIONS --------------------------------
  // ---------------------------------------------------------------------------

  void _showExportOptions(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kAuthNavy,
        title: const Text("Export Scan Report",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Choose export format:",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              exportPdfFromJson(context, data);
            },
            child: const Text("PDF", style: TextStyle(color: kSkyBlue)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              exportCsvFromJson(context, data);
            },
            child: const Text("CSV", style: TextStyle(color: kSkyBlue)),
          ),
        ],
      ),
    );
  }

  // ----------------------------- PDF EXPORT ----------------------------------
  Future<void> exportPdfFromJson(
      BuildContext context, Map<String, dynamic> jsonData) async {
    try {
      final pdf = pw.Document();
      final meta = jsonData['metadata'];
      final vulns = jsonData['vulnerabilities'] ?? [];
      final timing = jsonData['timingData'];
      final apiFindings = jsonData['apiFindings'];
      final cryptoFindings = jsonData['cryptoFindings'];
      final storageFindings = jsonData['storageFindings'];
      final networkFindings = jsonData['networkFindings'];
      final memoryFindings = jsonData['memoryFindings'];
      final device = meta?['deviceInfo'];

      pdf.addPage(
        pw.MultiPage(
          build: (pw.Context ctx) => [
            pw.Header(level: 0, text: "Biometric Security Scan Report"),

            if (!_isEmpty(meta))
              pw.Column(children: [
                pw.Header(level: 1, text: "1. Metadata"),
                pw.Paragraph(text:
                "Scan ID: ${meta['scanId']}\nTimestamp: ${meta['timestamp']}\nDevice: ${device?['manufacturer']} ${device?['model']} (${device?['device']})\nAndroid Version: ${device?['androidVersion']}, SDK: ${device?['sdkInt']}\nBrand: ${device?['brand']}\nFingerprint: ${device?['fingerprint']}"),
              ]),

            if (!_isEmpty(vulns))
              pw.Column(children: [
                pw.Header(level: 1, text: "2. Vulnerabilities"),
                ...vulns.map<pw.Widget>((v) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                          "[${v['type']}] - Severity: ${v['severity']} | Category: ${v['category']}",
                          style:
                          pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Bullet(text: "Title: ${v['title']}"),
                      if (!_isEmpty(v['description']))
                        pw.Bullet(text: "Description: ${v['description']}"),
                      if (!_isEmpty(v['impact']))
                        pw.Bullet(text: "Impact: ${v['impact']}"),
                      if (!_isEmpty(v['mitigation']))
                        pw.Bullet(text: "Mitigation: ${v['mitigation']}"),
                      if (!_isEmpty(v['technicalDetails']))
                        pw.Bullet(
                            text:
                            "Technical Details: ${v['technicalDetails'].toString()}"),
                      if (!_isEmpty(v['references']))
                        pw.Bullet(
                            text:
                            "References:\n${(v['references'] as List).map((r) => '- $r').join('\n')}"),
                      pw.Text("Detected At: ${v['detectedAt']}",
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                )),
              ]),

            if (!_isEmpty(timing))
              pw.Column(children: [
                pw.Header(level: 1, text: "3. Timing Data"),
                if (!_isEmpty(timing['attempts']))
                  pw.Paragraph(
                      text:
                      "Attempts:\n${(timing['attempts'] as List).map((a) => '• Result: ${a['result']}, Duration: ${a['duration']}s, Timestamp: ${a['timestamp']}').join('\n')}"),
              ]),

            if (!_isEmpty(apiFindings))
              pw.Column(children: [
                pw.Header(level: 1, text: "4. API Findings"),
                ...apiFindings.map<pw.Widget>((f) {
                  final d = f['details'];
                  return pw.Paragraph(
                      text:
                      "Type: ${f['type']}\nCategory: ${f['category']}\nTitle: ${d?['title']}\nSubtitle: ${d?['subtitle']}\nDescription: ${d?['description'] ?? 'N/A'}");
                }).toList(),
              ]),

            if (!_isEmpty(cryptoFindings) ||
                !_isEmpty(storageFindings) ||
                !_isEmpty(networkFindings) ||
                !_isEmpty(memoryFindings))
              pw.Column(children: [
                pw.Header(level: 1, text: "5. Other Findings"),
                if (!_isEmpty(cryptoFindings))
                  pw.Paragraph(text: "Crypto Findings: ${cryptoFindings.toString()}"),
                if (!_isEmpty(storageFindings))
                  pw.Paragraph(text: "Storage Findings: ${storageFindings.toString()}"),
                if (!_isEmpty(networkFindings))
                  pw.Paragraph(text: "Network Findings: ${networkFindings.toString()}"),
                if (!_isEmpty(memoryFindings))
                  pw.Paragraph(text: "Memory Findings: ${memoryFindings.toString()}"),
              ]),
          ],
        ),
      );

      final dir = await getDownloadsDirectory();
      final scanId = jsonData['metadata']?['scanId'] ?? 'unknown';
      final file = File("${dir!.path}/scan_${scanId}_report.pdf");
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF report saved to: ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting PDF: $e')));
    }
  }

  // ----------------------------- CSV EXPORT ----------------------------------
  Future<void> exportCsvFromJson(
      BuildContext context, Map<String, dynamic> jsonData) async {
    try {
      final List<List<dynamic>> rows = [];
      rows.add(['Section', 'Field', 'Value']);

      void addRow(String section, String field, dynamic value) {
        if (_isEmpty(value)) return;
        rows.add([section, field, value]);
      }

      final meta = jsonData['metadata'];
      if (!_isEmpty(meta)) {
        addRow('metadata', 'scanId', meta['scanId']);
        addRow('metadata', 'timestamp', meta['timestamp']);
        final dev = meta['deviceInfo'];
        if (!_isEmpty(dev)) dev.forEach((k, v) => addRow('metadata_deviceInfo', k, v));
      }

      final vulns = jsonData['vulnerabilities'] ?? [];
      for (var i = 0; i < vulns.length; i++) {
        vulns[i].forEach((k, val) {
          if (!_isEmpty(val)) addRow('vulnerability_${i + 1}', k, val);
        });
      }

      final timing = jsonData['timingData'];
      if (!_isEmpty(timing) && !_isEmpty(timing['attempts'])) {
        for (var a in timing['attempts']) {
          a.forEach((k, v) => addRow('timing_attempt', k, v));
        }
      }

      final apiFindings = jsonData['apiFindings'] ?? [];
      for (var i = 0; i < apiFindings.length; i++) {
        final f = apiFindings[i];
        addRow('apiFinding_${i + 1}', 'type', f['type']);
        addRow('apiFinding_${i + 1}', 'category', f['category']);
        final d = f['details'];
        if (!_isEmpty(d)) d.forEach((k, v) => addRow('apiFinding_${i + 1}_details', k, v));
      }

      for (final cat
      in ['cryptoFindings', 'storageFindings', 'networkFindings', 'memoryFindings']) {
        final data = jsonData[cat];
        if (!_isEmpty(data)) addRow(cat, 'data', data.toString());
      }

      final csvData = const ListToCsvConverter().convert(rows);

      final dir = await getDownloadsDirectory();
      final scanId = jsonData['metadata']?['scanId'] ?? 'unknown';
      final file = File("${dir!.path}/scan_${scanId}_report.csv");
      await file.writeAsString(csvData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV report saved to: ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting CSV: $e')));
    }
  }
}
