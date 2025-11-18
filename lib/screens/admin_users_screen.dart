// lib/screens/admin_users_screen.dart
// User Management Screen - View, Edit, Suspend, Delete users
// Matches Wireframe 7.11

import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/admin_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterRole = 'All'; // All, Free, Premium, Admin

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔄 Loading users for admin...');

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

      print('✅ Admin verified, fetching users...');

      final users = await _adminService.getAllUsers();

      print('📊 Found ${users.length} users');

      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });

      print('✅ Users loaded successfully');
    } catch (e) {
      print('❌ Error loading users: $e');
      print('Stack trace: ${StackTrace.current}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load users: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  void _filterUsers() {
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesSearch = user['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            user['username'].toString().toLowerCase().contains(_searchQuery.toLowerCase());

        final role = user['role'] as String? ?? 'free';
        final isPremium = user['isPremium'] as bool;

        final matchesRole = _filterRole == 'All' ||
            (_filterRole == 'Admin' && role == 'admin') ||
            (_filterRole == 'Premium' && role != 'admin' && isPremium) ||
            (_filterRole == 'Free' && role != 'admin' && !isPremium);

        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "User Management",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kAuthNavy),
          ),
          const SizedBox(height: 20),

          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: "Search by email or username",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _filterUsers();
            },
          ),
          const SizedBox(height: 16),

          // Filter Chips
          Wrap(
            spacing: 8,
            children: [
              const Text("Filter: ", style: TextStyle(fontWeight: FontWeight.bold)),
              ChoiceChip(
                label: const Text("All"),
                selected: _filterRole == 'All',
                onSelected: (selected) {
                  setState(() => _filterRole = 'All');
                  _filterUsers();
                },
              ),
              ChoiceChip(
                label: const Text("Free"),
                selected: _filterRole == 'Free',
                onSelected: (selected) {
                  setState(() => _filterRole = 'Free');
                  _filterUsers();
                },
              ),
              ChoiceChip(
                label: const Text("Premium"),
                selected: _filterRole == 'Premium',
                onSelected: (selected) {
                  setState(() => _filterRole = 'Premium');
                  _filterUsers();
                },
              ),
              ChoiceChip(
                label: const Text("Admin"),
                selected: _filterRole == 'Admin',
                selectedColor: Colors.purple.shade200,
                onSelected: (selected) {
                  setState(() => _filterRole = 'Admin');
                  _filterUsers();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // User List
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!_isLoading && _filteredUsers.isEmpty)
            const Expanded(child: Center(child: Text("No users found"))),
          if (!_isLoading && _filteredUsers.isNotEmpty)
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadUsers,
                child: ListView.builder(
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    return _buildUserCard(user);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = user['role'] as String? ?? 'free';
    final isUserAdmin = role == 'admin';
    final isPremium = user['isPremium'] as bool;
    final isSuspended = user['accountStatus'] == 'suspended';

    // Determine display values
    Color roleColor;
    String roleLabel;
    IconData roleIcon;

    if (isUserAdmin) {
      roleColor = Colors.purple;
      roleLabel = "Admin";
      roleIcon = Icons.admin_panel_settings;
    } else if (isPremium) {
      roleColor = Colors.amber;
      roleLabel = "Premium";
      roleIcon = Icons.star;
    } else {
      roleColor = Colors.blue;
      roleLabel = "Free";
      roleIcon = Icons.person;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: isUserAdmin ? Colors.purple.shade300 : Colors.grey.shade300,
          width: isUserAdmin ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isSuspended
            ? Colors.red.shade50
            : isUserAdmin
            ? Colors.purple.shade50
            : Colors.white,
      ),
      child: Row(
        children: [
          // User Icon
          CircleAvatar(
            backgroundColor: roleColor,
            child: Icon(roleIcon, color: Colors.white),
          ),
          const SizedBox(width: 16),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['username'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  user['email'],
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        roleLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isSuspended)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Suspended",
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Actions Menu - Disabled for admins
          if (isUserAdmin)
            Tooltip(
              message: "Cannot modify admin accounts",
              child: Icon(Icons.lock, color: Colors.grey.shade400),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => _handleUserAction(value, user),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'toggle_premium', child: Text("Toggle Premium")),
                PopupMenuItem(
                  value: isSuspended ? 'activate' : 'suspend',
                  child: Text(isSuspended ? "Activate" : "Suspend"),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _handleUserAction(String action, Map<String, dynamic> user) async {
    switch (action) {
      case 'toggle_premium':
        await _adminService.updateUserRole(user['uid'], !user['isPremium']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${user['username']} role updated")),
        );
        _loadUsers();
        break;

      case 'suspend':
        await _adminService.suspendUser(user['uid']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${user['username']} suspended")),
        );
        _loadUsers();
        break;

      case 'activate':
        await _adminService.activateUser(user['uid']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${user['username']} activated")),
        );
        _loadUsers();
        break;

      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: kAuthNavy,
            titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            contentTextStyle: const TextStyle(color: Colors.white),
            title: const Text("⚠️ Delete User"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Are you sure you want to delete ${user['username']}?"),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "⚠️ Note: This will delete their Firestore data, but the Firebase Authentication account will remain.\n\n"
                        "The user will NOT be able to log in (no user document), but you must manually delete their auth account from Firebase Console.",
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel", style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await _adminService.deleteUser(user['uid']);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${user['username']} deleted from Firestore.\n"
                  "Manually delete auth account from Firebase Console."),
              duration: const Duration(seconds: 5),
            ),
          );
          _loadUsers();
        }
        break;
    }
  }
}