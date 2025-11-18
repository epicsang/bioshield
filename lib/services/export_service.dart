// lib/services/export_service.dart
// Export Service - Handles CSV and PDF export of scan results
// Premium feature for detailed security reports

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../services/biometric_service.dart';
import '../services/recommendation_engine.dart';

/// Export format enum
enum ExportFormat { csv, pdf, json }

/// Export result with file path
class ExportResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;

  ExportResult.success(this.filePath)
      : success = true,
        errorMessage = null;

  ExportResult.error(this.errorMessage)
      : success = false,
        filePath = null;
}

/// Main export service
class ExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final _fileNameFormat = DateFormat('yyyyMMdd_HHmmss');

  /// Export scan results to CSV
  Future<ExportResult> exportToCSV({
    required List<Map<String, dynamic>> scanResults,
    String? customFileName,
  }) async {
    try {
      // Prepare CSV data
      List<List<dynamic>> rows = [];

      // Header row
      rows.add([
        'Scan ID',
        'Date/Time',
        'Biometric Type',
        'Risk Score',
        'Status',
        'Duration (ms)',
        'Vulnerabilities',
        'Severity',
        'Recommendations',
      ]);

      // Data rows
      for (var scan in scanResults) {
        final timestamp = scan['timestamp'] is DateTime
            ? _dateFormat.format(scan['timestamp'])
            : scan['timestamp'].toString();

        final vulnerabilities = scan['vulnerabilities'] as List<dynamic>? ?? [];
        final vulnSummary = vulnerabilities
            .map((v) => v['description'] ?? 'Unknown')
            .join('; ');

        final severity = vulnerabilities.isNotEmpty
            ? vulnerabilities
                .map((v) => v['severity'] ?? 'unknown')
                .join(', ')
            : 'none';

        rows.add([
          scan['scanId'] ?? 'N/A',
          timestamp,
          scan['biometricType'] ?? 'fingerprint',
          scan['riskScore'] ?? 0,
          scan['status'] ?? 'unknown',
          scan['duration'] ?? 0,
          vulnSummary,
          severity,
          scan['resultSummary'] ?? 'No summary available',
        ]);
      }

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);

      // Save to file
      final directory = await _getExportDirectory();
      final fileName = customFileName ??
          'bioshield_scan_export_${_fileNameFormat.format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(csv);

      print('✅ CSV exported successfully: ${file.path}');
      return ExportResult.success(file.path);
    } catch (e) {
      print('❌ CSV export error: $e');
      return ExportResult.error(e.toString());
    }
  }

  /// Export scan results to PDF with detailed report
  Future<ExportResult> exportToPDF({
    required Map<String, dynamic> scanResult,
    required List<Vulnerability> vulnerabilities,
    required List<Recommendation> recommendations,
    String? customFileName,
  }) async {
    try {
      final pdf = pw.Document();

      // Generate PDF pages
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            _buildPDFHeader(),
            pw.SizedBox(height: 20),
            _buildScanSummary(scanResult),
            pw.SizedBox(height: 20),
            _buildRiskScoreSection(scanResult),
            pw.SizedBox(height: 20),
            _buildVulnerabilitiesSection(vulnerabilities),
            pw.SizedBox(height: 20),
            _buildRecommendationsSection(recommendations),
            pw.SizedBox(height: 20),
            _buildFooter(),
          ],
        ),
      );

      // Save to file
      final directory = await _getExportDirectory();
      final fileName = customFileName ??
          'bioshield_report_${_fileNameFormat.format(DateTime.now())}.pdf';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(await pdf.save());

      print('✅ PDF exported successfully: ${file.path}');
      return ExportResult.success(file.path);
    } catch (e) {
      print('❌ PDF export error: $e');
      return ExportResult.error(e.toString());
    }
  }

  /// Build PDF header
  pw.Widget _buildPDFHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'BioShield Security Report',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Biometric Authentication Vulnerability Analysis',
          style: const pw.TextStyle(
            fontSize: 14,
            color: PdfColors.grey700,
          ),
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  /// Build scan summary section
  pw.Widget _buildScanSummary(Map<String, dynamic> scanResult) {
    final timestamp = scanResult['timestamp'] is DateTime
        ? _dateFormat.format(scanResult['timestamp'])
        : scanResult['timestamp'].toString();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Scan Summary',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            _buildPDFTableRow('Scan ID', scanResult['scanId'] ?? 'N/A'),
            _buildPDFTableRow('Date/Time', timestamp),
            _buildPDFTableRow(
                'Biometric Type', scanResult['biometricType'] ?? 'fingerprint'),
            _buildPDFTableRow('Status', scanResult['status'] ?? 'unknown'),
            _buildPDFTableRow(
                'Duration', '${scanResult['duration'] ?? 0}ms'),
            _buildPDFTableRow(
                'Authenticated', scanResult['authenticated']?.toString() ?? 'false'),
          ],
        ),
      ],
    );
  }

  /// Build risk score section
  pw.Widget _buildRiskScoreSection(Map<String, dynamic> scanResult) {
    final riskScore = (scanResult['riskScore'] ?? 0).toInt();
    final color = _getRiskColor(riskScore.toDouble());

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Risk Score',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '$riskScore / 100',
                style: pw.TextStyle(
                  fontSize: 36,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
              pw.Text(
                _getRiskLevel(riskScore.toDouble()),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            scanResult['resultSummary'] ?? 'No summary available',
            style: const pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Build vulnerabilities section
  pw.Widget _buildVulnerabilitiesSection(List<Vulnerability> vulnerabilities) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Vulnerabilities Detected (${vulnerabilities.length})',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        if (vulnerabilities.isEmpty)
          pw.Text('No vulnerabilities detected. System appears secure.')
        else
          ...vulnerabilities.map((vuln) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _getSeverityColor(vuln.severity)),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          vuln.type.toString().split('.').last,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: pw.BoxDecoration(
                            color: _getSeverityColor(vuln.severity),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            vuln.severity.toString().split('.').last.toUpperCase(),
                            style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      vuln.description,
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Recommendation: ${vuln.recommendation}',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  /// Build recommendations section
  pw.Widget _buildRecommendationsSection(List<Recommendation> recommendations) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Security Recommendations (${recommendations.length})',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        if (recommendations.isEmpty)
          pw.Text('No specific recommendations at this time.')
        else
          ...recommendations.take(5).map((rec) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '• ${rec.title}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      rec.description,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Estimated effort: ${rec.estimatedHours} hours',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  /// Build PDF footer
  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text(
          'Generated by BioShield - ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
          ),
        ),
        pw.Text(
          'This report is confidential and for authorized use only.',
          style: const pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey500,
          ),
        ),
      ],
    );
  }

  /// Helper: Build PDF table row
  pw.TableRow _buildPDFTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value),
        ),
      ],
    );
  }

  /// Get export directory
  Future<Directory> _getExportDirectory() async {
    // Try to use Downloads folder first
    try {
      final directory = Directory('/storage/emulated/0/Download');
      if (await directory.exists()) {
        return directory;
      }
    } catch (e) {
      print('Cannot access Downloads folder: $e');
    }

    // Fallback to app documents directory
    return await getApplicationDocumentsDirectory();
  }

  /// Get risk color based on score
  PdfColor _getRiskColor(double score) {
    if (score >= 80) return PdfColors.green;
    if (score >= 60) return PdfColors.orange;
    return PdfColors.red;
  }

  /// Get risk level text
  String _getRiskLevel(double score) {
    if (score >= 80) return 'LOW RISK';
    if (score >= 60) return 'MEDIUM RISK';
    if (score >= 40) return 'HIGH RISK';
    return 'CRITICAL RISK';
  }

  /// Get severity color
  PdfColor _getSeverityColor(Severity severity) {
    switch (severity) {
      case Severity.critical:
        return PdfColors.red900;
      case Severity.high:
        return PdfColors.red;
      case Severity.medium:
        return PdfColors.orange;
      case Severity.low:
        return PdfColors.yellow;
    }
  }
}
