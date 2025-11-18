// lib/screens/admin_dashboard_screen.dart
// Main Admin Dashboard with analytics overview
// Matches Wireframe 7.10 with improved metrics

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/colors.dart';
import '../services/admin_service.dart';
import 'admin_users_screen.dart';
import 'admin_banners_screen.dart';
import 'admin_requests_screen.dart';
import 'landing_page.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();
  int _selectedIndex = 0;

  // Analytics data
  int _totalUsers = 0;
  int _premiumUsers = 0;
  int _scansToday = 0;
  double _avgSecurityScore = 0.0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _userGrowthData = [];
  Map<String, int> _vulnerabilityDistribution = {};
  Map<String, int> _vulnerabilityTypes = {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔄 Loading admin analytics...');

    try {
      // Check if user is admin first
      final isAdmin = await _adminService.isAdmin();
      if (!isAdmin) {
        print('❌ Current user is NOT an admin!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ You do not have admin privileges'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      print('✅ Admin verified, fetching data...');

      final totalUsers = await _adminService.getTotalUsers();
      final premiumUsers = await _adminService.getPremiumUsers();
      final scansToday = await _adminService.getScansToday();
      final avgScore = await _adminService.getAverageSecurityScore();
      final growthData = await _adminService.getUserGrowthData(days: 7);
      final vulnDist = await _adminService.getVulnerabilityDistribution();
      final vulnTypes = await _adminService.getVulnerabilityTypeDistribution();

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📊 ANALYTICS SUMMARY:');
      print('   Total Users: $totalUsers');
      print('   Premium Users: $premiumUsers');
      print('   Scans Today: $scansToday');
      print('   Avg Score: ${avgScore.toStringAsFixed(1)}');
      print('   Growth Data Points: ${growthData.length}');
      print('   Vulnerability Distribution: $vulnDist');
      print('   Vulnerability Types: $vulnTypes');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      setState(() {
        _totalUsers = totalUsers;
        _premiumUsers = premiumUsers;
        _scansToday = scansToday;
        _avgSecurityScore = avgScore;
        _userGrowthData = growthData;
        _vulnerabilityDistribution = vulnDist;
        _vulnerabilityTypes = vulnTypes;
        _isLoading = false;
      });

      print('✅ Analytics loaded successfully');
    } catch (e) {
      print('❌ Error loading analytics: $e');
      print('Stack trace: ${StackTrace.current}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load analytics: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kSkyBlue,
        title: const Text("Admin Dashboard", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
        foregroundColor: kAuthNavy,
        automaticallyImplyLeading: false,
        actions: [
          // Sign Out Button
          TextButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: kAuthNavy,
                  titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  contentTextStyle: const TextStyle(color: Colors.white),
                  title: const Text("Sign Out"),
                  content: const Text("Are you sure you want to sign out?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel", style: TextStyle(color: kInactiveIcon)),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx); // Close dialog

                        // Sign out
                        try {
                          await FirebaseAuth.instance.signOut();

                          // Navigate to landing page
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LandingPage()),
                                (route) => false, // Remove all previous routes
                          );
                        } catch (e) {
                          print("Logout failed: $e");
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Logout failed. Please try again.")),
                          );
                        }
                      },
                      child: const Text("Sign Out", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            child: const Text("Sign Out", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh, color: kAuthNavy),
            tooltip: 'Refresh Data',
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardOverview(),
          AdminUsersScreen(),
          AdminBannersScreen(),
          AdminRequestsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildDashboardOverview() {
    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Overview",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kAuthNavy),
            ),
            const SizedBox(height: 20),

            // Top Stats Cards
            Row(
              children: [
                Expanded(child: _buildStatCard("Total Users", _totalUsers.toString(), Icons.people, Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard("Premium", _premiumUsers.toString(), Icons.star, Colors.amber)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatCard("Scans Today", _scansToday.toString(), Icons.scanner, Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard("Avg Score", "${_avgSecurityScore.toStringAsFixed(1)}/100", Icons.security, Colors.orange)),
              ],
            ),
            const SizedBox(height: 30),

            // User Growth Chart
            const Text(
              "User Growth (Last 7 Days)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kAuthNavy),
            ),
            const SizedBox(height: 10),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildUserGrowthChart(),
            ),
            const SizedBox(height: 30),

            // Vulnerability Distribution
            const Text(
              "Security Score Distribution",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kAuthNavy),
            ),
            const SizedBox(height: 10),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildVulnerabilityChart(),
            ),
            const SizedBox(height: 30),

            // Most Common Vulnerabilities
            const Text(
              "Most Common Vulnerabilities",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kAuthNavy),
            ),
            const SizedBox(height: 10),
            _buildVulnerabilityTypesCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildUserGrowthChart() {
    if (_userGrowthData.isEmpty) {
      return const Center(child: Text("No data available"));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < _userGrowthData.length) {
                  return Text(_userGrowthData[value.toInt()]['date'], style: const TextStyle(fontSize: 10));
                }
                return const Text('');
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _userGrowthData.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value['signups'].toDouble());
            }).toList(),
            isCurved: true,
            color: kAuthNavy,
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: kSkyBlue.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildVulnerabilityChart() {
    if (_vulnerabilityDistribution.isEmpty) {
      return const Center(child: Text("No scan data available"));
    }

    final total = _vulnerabilityDistribution.values.fold(0, (sum, count) => sum + count);
    if (total == 0) {
      return const Center(child: Text("No scan data available"));
    }

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: _vulnerabilityDistribution['Low Risk (80-100)']!.toDouble(),
            color: Colors.green,
            title: '${((_vulnerabilityDistribution['Low Risk (80-100)']! / total) * 100).toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            value: _vulnerabilityDistribution['Medium Risk (60-79)']!.toDouble(),
            color: Colors.orange,
            title: '${((_vulnerabilityDistribution['Medium Risk (60-79)']! / total) * 100).toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            value: _vulnerabilityDistribution['High Risk (0-59)']!.toDouble(),
            color: Colors.red,
            title: '${((_vulnerabilityDistribution['High Risk (0-59)']! / total) * 100).toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  Widget _buildVulnerabilityTypesCard() {
    if (_vulnerabilityTypes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text("No vulnerability data available")),
      );
    }

    final totalVulnerabilities = _vulnerabilityTypes.values.fold(0, (sum, count) => sum + count);

    if (totalVulnerabilities == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.green.shade50,
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                "✅ No significant vulnerabilities detected!\nAll scans show healthy security scores.",
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "⚠️ $totalVulnerabilities vulnerability instances detected across all scans",
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Vulnerability breakdown
          ..._vulnerabilityTypes.entries.map((entry) {
            if (entry.value == 0) return const SizedBox.shrink();

            final percentage = ((entry.value / totalVulnerabilities) * 100).toStringAsFixed(0);

            Color iconColor;
            IconData iconData;
            switch (entry.key) {
              case 'Multiple Issues':
                iconColor = Colors.red;
                iconData = Icons.error;
                break;
              case 'Timing Attack Risk':
                iconColor = Colors.orange;
                iconData = Icons.schedule;
                break;
              case 'Low Sensor Entropy':
                iconColor = Colors.amber;
                iconData = Icons.blur_on;
                break;
              case 'Weak API Implementation':
                iconColor = Colors.deepOrange;
                iconData = Icons.api;
                break;
              default:
                iconColor = Colors.grey;
                iconData = Icons.info;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(iconData, color: iconColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: entry.value / totalVulnerabilities,
                          backgroundColor: Colors.grey.shade200,
                          color: iconColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "$percentage%",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "(${entry.value})",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: kSkyBlue,
      selectedItemColor: kActiveNavy,
      unselectedItemColor: kInactiveIcon,
      currentIndex: _selectedIndex,
      type: BottomNavigationBarType.fixed, // Prevents label shifting with 4+ items
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Overview"),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: "Users"),
        BottomNavigationBarItem(icon: Icon(Icons.campaign), label: "Banners"),
        BottomNavigationBarItem(icon: Icon(Icons.support_agent), label: "Requests"),
      ],
      onTap: (index) {
        setState(() => _selectedIndex = index);
      },
    );
  }
}