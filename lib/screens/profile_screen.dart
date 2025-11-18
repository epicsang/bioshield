// lib/screens/profile_screen.dart
// Profile screen — shows real username/email from UserModel
// Matches Wireframe 7.5

import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../constants/colors.dart';
import '../auth/auth_service.dart';
import 'update_profile_screen.dart';
import 'dashboard_screen.dart';

class ProfileScreen extends StatelessWidget {
  final UserModel user; // 👈 Declare user parameter
  final VoidCallback onUpgradePressed;
  final VoidCallback onDeletePressed;

  const ProfileScreen({
    super.key,
    required this.user, // 👈 Required in constructor
    required this.onUpgradePressed,
    required this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Account Details",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kAuthNavy),
            ),
            const SizedBox(height: 20),
            _buildProfileRow("Username", user.username), // 👈 Now 'user' is defined
            _buildProfileRow("Email", user.email),       // 👈 Now 'user' is defined
            _buildProfileRow("Membership", user.isPremium ? "Premium" : "Free"),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UpdateProfileScreen(
                        user: user, // 👈 Pass user to UpdateProfileScreen
                        onSave: (updatedUser) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Profile updated")),
                          );
                          // 👇 Trigger refresh in DashboardScreen
                          Navigator.pop(context);
                          // 👇 Navigate back to Dashboard and refresh user
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DashboardScreen(user: updatedUser),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSkyBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  "Update Profile",
                  style: TextStyle(fontSize: 16, color: kAuthNavy, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!user.isPremium) // 👈 Now 'user' is defined
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onUpgradePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text("Upgrade to Premium", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDeletePressed,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Suspend Account", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // Show confirmation dialog
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: kAuthNavy,
                      titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      contentTextStyle: const TextStyle(color: Colors.white),
                      title: const Text("Logout"),
                      content: const Text("Are you sure you want to logout?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: kSkyBlue),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Logout", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );

                  if (shouldLogout == true) {
                    // Perform logout
                    final authService = AuthService();
                    await authService.logout();

                    // Navigate to login screen by popping all routes
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  "Logout",
                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, color: kAuthNavy),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 16, color: kTextPrimary),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}