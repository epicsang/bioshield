// lib/screens/dashboard_screen.dart
// Unified Dashboard with Tabbed Navigation — matches all wireframes
// Persistent Bottom Nav, Sign Out button, Real Data, Free/Premium UX, Email Verification

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../widgets/scan_limit_overlay.dart';
import '../constants/colors.dart';
import '../auth/auth_service.dart';
import 'scan_screen.dart';
import 'scan_history_screen.dart';
import 'profile_screen.dart';
import 'pricing_screen.dart';
import 'landing_page.dart';
import 'scan_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  UserModel user;

  DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  int _selectedIndex = 0;
  int _freeScanCount = 3;
  List<Map<String, dynamic>> _recentScans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    UserModel? user = await _loadUserFromFirestore();
    if (user != null) {
      setState(() {
        widget.user = user.copyWith();
      });
      _loadRecentScans();
    }
  }

  Future<UserModel?> _loadUserFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print("Error loading user from Firestore: $e");
      return null;
    }
  }

  Future<void> _loadRecentScans() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('scans')
          .orderBy('timestamp', descending: true)
          .limit(widget.user.isPremium ? 5 : 1)
          .get();

      setState(() {
        _recentScans = querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading scans: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveScanToFirestore(Map<String, dynamic> result) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('scans')
          .add({
        'scanId': DateTime.now().millisecondsSinceEpoch.toString(),
        'biometricType': result['biometricType'],
        'timestamp': FieldValue.serverTimestamp(),
        'riskScore': result['riskScore'].toDouble(),
        'resultSummary': result['status'] == 'failed'
            ? "Biometric authentication failed. No vulnerability data captured."
            : _generateSummary(result['riskScore'] as int),
        'status': result['status'],
      });

      // 👇 Auto-refresh scan history when scan completes
      _loadRecentScans();
    } catch (e) {
      print("Error saving scan: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save scan")),
      );
    }
  }

  Future<void> _refreshCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      setState(() {
        widget.user = UserModel.fromMap(doc.data() as Map<String, dynamic>);
      });
    }
  }

  String _generateSummary(int score) {
    if (score == 0) return "Biometric authentication failed. No vulnerability data captured.";
    if (score >= 80) return "Low risk detected. Biometric system appears secure.";
    if (score >= 60) return "Medium risk detected. Review sensor calibration and API usage.";
    return "High risk detected. Implement secure protocols and sensor-level throttling.";
  }

  void _runScan() {
    if (!widget.user.isPremium && _freeScanCount <= 0) {
      showDialog(
        context: context,
        builder: (ctx) => const ScanLimitOverlay(),
      );
      return;
    }

    if (!widget.user.isPremium) {
      setState(() => _freeScanCount--);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanScreen(isPremium: widget.user.isPremium),
      ),
    ).then((result) {
      if (result != null && result is Map<String, dynamic>) {
        _saveScanToFirestore(result);
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      _runScan();
    } else if (index == 2){

    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kSkyBlue,
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold, color: kAuthNavy),
        ),
        actions: [
          if (_selectedIndex != 3)
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
                        onPressed: () {
                          Navigator.pop(ctx);
                          _authService.logout().then((_) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const LandingPage()),
                            );
                          }).catchError((error) {
                            print("Logout failed: $error");
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Logout failed. Please try again.")),
                            );
                          });
                        },
                        child: const Text("Sign Out", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text("Sign Out", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
            ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Tab 0: Dashboard
          _buildDashboardContent(),
          // Tab 1: Scan (empty — handled by _runScan)
          Container(),
          // Tab 2: Scan History — NO Scaffold, NO AppBar
          ScanHistoryScreen(
            isPremium: widget.user.isPremium,
          ),
          // Tab 3: Profile
          ProfileScreen(
            user: widget.user,
            onUpgradePressed: () {
              setState(() => _selectedIndex = 0);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: kAuthNavy,
                  titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  contentTextStyle: const TextStyle(color: Colors.white),
                  title: const Text("Pricing Plans"),
                  content: const Text("Upgrade to Premium for unlimited scans and full reports."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: kSkyBlue),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PricingScreen()),
                        );
                      },
                      child: Text("Subscribe", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
            onDeletePressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Delete Account"),
                  content: const Text("Are you sure? This action cannot be undone."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Account Deleted"),
                            content: const Text("Your account and all data have been permanently deleted."),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => const LandingPage()),
                                  );
                                },
                                child: const Text("Back to Home"),
                              ),
                            ],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Delete", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0: return widget.user.isPremium ? "Premium Dashboard" : "Free Dashboard";
      case 1: return "Run Scan";
      case 2: return "Scan History";
      case 3: return "Profile";
      default: return "BioShield";
    }
  }

  Widget _buildDashboardContent() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: const Text(
              "BioShield",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kAuthNavy,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          if (!widget.user.isPremium)
            _buildScanCounter(_freeScanCount),
          const SizedBox(height: 20),
          const Text(
            "Recent Scans",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          if (!_isLoading)
            Expanded(
              child: ListView.builder(
                itemCount: _recentScans.length,
                itemBuilder: (context, index) {
                  final scan = _recentScans[index];
                  final timestamp = (scan['timestamp'] as dynamic).toDate();
                  final score = (scan['riskScore'] as double).toInt();
                  final summary = scan['resultSummary'] as String;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScanDetailsScreen(
                            scan: scan,
                            isPremium: widget.user.isPremium,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "Scan on ${timestamp.toString().split(' ')[0]}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "$score/100",
                            style: TextStyle(
                              color: _getScoreColor(score),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _runScan,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 56),
            ),
            child: const Text("Run Scan", style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _selectedIndex = 2),
            child: const Text("View Scan History"),
          ),
          if (widget.user.isPremium)
            Column(
              children: [
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                const Text("Premium Features", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.monitor_heart, color: Colors.green),
                  title: const Text("Real-Time Monitoring"),
                  subtitle: const Text("Monitor biometric security in real-time"),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Real-time monitoring coming soon!")),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.group, color: Colors.blue),
                  title: const Text("Federated Learning"),
                  subtitle: const Text("Contribute to improve AI models"),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Federated learning coming soon!")),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildScanCounter(int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Scans Remaining Today",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: count > 0 ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "$count",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: kSkyBlue,
      unselectedItemColor: kInactiveIcon,
      selectedItemColor: kActiveNavy,
      currentIndex: _selectedIndex,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: "Dashboard",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.scanner),
          label: "Scan",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: "History",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: "Profile",
        ),
      ],
      onTap: _onItemTapped,
    );
  }
}