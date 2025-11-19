// lib/screens/scan_history_screen.dart
// Scan History Screen — groups scans by day with calendar view
// Free users: Only 3 most recent scans unlocked
// Premium users: All scans unlocked

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import '../models/user_model.dart';
import 'pricing_screen.dart';
import 'scan_details_screen.dart';
import '../services/export_service.dart';
import '../services/biometric_service.dart';
import '../services/recommendation_engine.dart';

class ScanHistoryScreen extends StatefulWidget {
  final bool isPremium;
  final String jsonAssetPath;

  const ScanHistoryScreen({
    super.key,
    required this.isPremium,
    required this.jsonAssetPath,
  });

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _scansByDate = {};
  List<Map<String, dynamic>> _allScans = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  List<Map<String, dynamic>> _getScansForDay(DateTime day) {
    final normalized = _normalizeDate(day);
    return _scansByDate[normalized] ?? [];
  }

  bool _isScanUnlocked(int scanIndex) {
    // Premium users can view all scans
    if (widget.isPremium) return true;

    // Free users can only view the 3 most recent scans
    return scanIndex < 3;
  }

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
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  const Text(
                    "No scans found",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Run a scan to get started",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Process scans and group by date
          _allScans = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();

          _scansByDate = {};
          for (var scan in _allScans) {
            final timestamp = (scan['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            final normalized = _normalizeDate(timestamp);

            if (_scansByDate[normalized] == null) {
              _scansByDate[normalized] = [];
            }
            _scansByDate[normalized]!.add(scan);
          }

          final scansForSelectedDay = _getScansForDay(_selectedDay ?? _focusedDay);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Scan History",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kAuthNavy,
                ),
              ),
              const SizedBox(height: 20),

              // Calendar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  eventLoader: _getScansForDay,
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: kSkyBlue.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: kSkyBlue,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: kAuthNavy,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    formatButtonShowsNext: false,
                    formatButtonDecoration: BoxDecoration(
                      color: kSkyBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    formatButtonTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Scans for selected day
              Text(
                scansForSelectedDay.isEmpty
                    ? "No scans on ${DateFormat('MMM d, y').format(_selectedDay ?? _focusedDay)}"
                    : "Scans on ${DateFormat('MMM d, y').format(_selectedDay ?? _focusedDay)} (${scansForSelectedDay.length})",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kAuthNavy,
                ),
              ),
              const SizedBox(height: 12),

              // List of scans for the selected day
              Expanded(
                child: scansForSelectedDay.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text(
                              "No scans on this day",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: scansForSelectedDay.length,
                        itemBuilder: (context, index) {
                          final scan = scansForSelectedDay[index];
                          final globalIndex = _allScans.indexOf(scan);
                          final isUnlocked = _isScanUnlocked(globalIndex);

                          final timestamp = (scan['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                          final score = ((scan['riskScore'] as num?) ?? 0).toInt();
                          final summary = (scan['resultSummary'] as String?) ?? 'No summary available';

                          return GestureDetector(
                            onTap: () {
                              if (isUnlocked) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ScanDetailsScreen(
                                      scan: scan,
                                      isPremium: widget.isPremium,
                                      jsonAssetPath: widget.jsonAssetPath,
                                    ),
                                  ),
                                );
                              } else {
                                // Show upgrade prompt for locked scans
                                _showUpgradePrompt(context);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isUnlocked ? Colors.white : Colors.grey.shade100,
                                border: Border.all(
                                  color: isUnlocked ? Colors.grey.shade300 : Colors.grey.shade400,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: isUnlocked ? kAuthNavy : Colors.grey,
                                              ),
                                            ),
                                            if (!isUnlocked) ...[
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.lock,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (scan['status'] == 'failed')
                                          const Text(
                                            "Authentication Failed",
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        if (isUnlocked && scan['status'] != 'failed')
                                          Text(
                                            summary,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        if (!isUnlocked)
                                          const Text(
                                            "Upgrade to view",
                                            style: TextStyle(
                                              color: kSkyBlue,
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isUnlocked && scan['status'] != 'failed')
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getScoreColor(score).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _getScoreColor(score),
                                        ),
                                      ),
                                      child: Text(
                                        "$score/100",
                                        style: TextStyle(
                                          color: _getScoreColor(score),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
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

              // Bottom action buttons
              if (widget.isPremium)
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: kAuthNavy,
                        titleTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        contentTextStyle: const TextStyle(color: Colors.white),
                        title: const Text("Export Scan Report"),
                        content: const Text("Choose export format:"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _exportAsPDF();
                            },
                            child: const Text(
                              "PDF",
                              style: TextStyle(
                                color: kSkyBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _exportAsCSV();
                            },
                            child: const Text(
                              "CSV",
                              style: TextStyle(
                                color: kSkyBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSkyBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    "Export Report",
                    style: TextStyle(
                      fontSize: 16,
                      color: kAuthNavy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (!widget.isPremium)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kSkyBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kSkyBlue, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, color: kSkyBlue),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Viewing 3 most recent scans. Upgrade to Premium for unlimited history and export reports.",
                          style: TextStyle(color: kSkyBlue),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PricingScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kSkyBlue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: const Text(
                          "Upgrade",
                          style: TextStyle(
                            fontSize: 12,
                            color: kAuthNavy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  void _showUpgradePrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock, color: kSkyBlue, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Premium Feature',
              style: TextStyle(color: kAuthNavy),
            ),
          ],
        ),
        content: const Text(
          'Upgrade to Premium to view all your scan history and access detailed vulnerability analysis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PricingScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kSkyBlue,
              foregroundColor: kAuthNavy,
            ),
            child: const Text(
              'Upgrade Now',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAsCSV() async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Exporting scans as CSV..."),
        backgroundColor: kSkyBlue,
      ),
    );

    try {
      final exportService = ExportService();

      // Prepare scan data for CSV export
      final csvData = _allScans.map((scan) {
        return {
          'scanId': scan['scanId'] ?? 'N/A',
          'timestamp': (scan['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'biometricType': scan['biometricType'] ?? 'fingerprint',
          'riskScore': scan['riskScore'] ?? 0,
          'status': scan['status'] ?? 'unknown',
          'duration': scan['duration'] ?? 0,
          'vulnerabilities': scan['vulnerabilities'] ?? [],
          'resultSummary': scan['resultSummary'] ?? 'No summary',
        };
      }).toList();

      final result = await exportService.exportToCSV(scanResults: csvData);

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✓ CSV exported successfully!\nSaved to: ${result.filePath}",
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✗ Export failed: ${result.errorMessage}",
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✗ Export error: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _exportAsPDF() async {
    if (!mounted) return;

    // Show scan selection dialog
    final selectedScan = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kAuthNavy,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(color: Colors.white),
        title: const Text("Select Scan for PDF Export"),
        content: SizedBox(
          width: double.maxFinite,
          child: _allScans.isEmpty
              ? const Text("No scans available to export")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _allScans.length,
                  itemBuilder: (context, index) {
                    final scan = _allScans[index];
                    final timestamp = (scan['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final score = ((scan['riskScore'] as num?) ?? 0).toInt();

                    return ListTile(
                      title: Text(
                        DateFormat('MMM d, y - HH:mm').format(timestamp),
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        "Risk Score: $score/100",
                        style: const TextStyle(color: kSkyBlue),
                      ),
                      onTap: () => Navigator.pop(ctx, scan),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (selectedScan == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Exporting scan as PDF..."),
        backgroundColor: kSkyBlue,
      ),
    );

    try {
      final exportService = ExportService();

      // Convert vulnerabilities to proper format
      final vulnList = (selectedScan['vulnerabilities'] as List<dynamic>?)
          ?.map((v) {
            final vulnMap = v as Map<String, dynamic>;
            return Vulnerability(
              type: VulnerabilityType.values.firstWhere(
                (e) => e.toString() == 'VulnerabilityType.${vulnMap['type']}',
                orElse: () => VulnerabilityType.spoofAttempt,
              ),
              severity: Severity.values.firstWhere(
                (e) => e.toString() == 'Severity.${vulnMap['severity']}',
                orElse: () => Severity.medium,
              ),
              description: vulnMap['description'] ?? 'Unknown',
              recommendation: vulnMap['recommendation'] ?? 'No recommendation',
            );
          })
          .toList() ?? [];

      // Generate basic recommendations
      final recommendations = [
        Recommendation(
          title: 'Review Security Settings',
          description: 'Check your biometric authentication settings and ensure they meet security standards.',
          priority: Priority.high,
          estimatedHours: 1,
        ),
      ];

      final result = await exportService.exportToPDF(
        scanResult: selectedScan,
        vulnerabilities: vulnList,
        recommendations: recommendations,
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✓ PDF exported successfully!\nSaved to: ${result.filePath}",
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✗ Export failed: ${result.errorMessage}",
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✗ Export error: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

Color _getScoreColor(int score) {
  if (score >= 80) return Colors.green;
  if (score >= 60) return Colors.orange;
  return Colors.red;
}
