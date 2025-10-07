// lib/screens/update_profile_screen.dart
// Update Profile Screen — updates both Firestore and Firebase Authentication
// Matches Wireframes 7.6, 7.6b

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../constants/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UpdateProfileScreen extends StatefulWidget {
  final UserModel user;
  final Function(UserModel) onSave;

  const UpdateProfileScreen({
    super.key,
    required this.user,
    required this.onSave,
  });

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _emailController = TextEditingController(text: widget.user.email);
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    // Validate password if entered
    if (_passwordController.text.isNotEmpty &&
        _passwordController.text != _confirmPasswordController.text) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kAuthNavy,
          titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          contentTextStyle: const TextStyle(color: Colors.white),
          title: const Text("Error"),
          content: const Text("Passwords do not match."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    if (_passwordController.text.isNotEmpty && !isValidPassword(_passwordController.text)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kAuthNavy,
          titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          contentTextStyle: const TextStyle(color: Colors.white),
          title: const Text("Invalid Password"),
          content: const Text("Password must include uppercase, number, and special character."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not logged in")),
        );
        return;
      }

      // 👇 Update email with verification (replaces deprecated updateEmail)
      if (_emailController.text != widget.user.email) {
        await user.verifyBeforeUpdateEmail(_emailController.text);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Verification email sent to ${_emailController.text}. Please verify to update your email."),
          ),
        );
      }

      // Update password in Firebase Authentication (if entered)
      if (_passwordController.text.isNotEmpty) {
        await user.updatePassword(_passwordController.text);
      }

      // Update profile in Firestore (username + email)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'username': _usernameController.text,
        'email': _emailController.text, // 👈 Will be updated after email verification
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Show success dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kAuthNavy,
          titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          contentTextStyle: const TextStyle(color: Colors.white),
          title: const Text("✅ Profile Updated"),
          content: const Text("Your profile has been successfully updated."),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kSkyBlue),
              onPressed: () {
                Navigator.pop(ctx);
                // Return updated user to parent
                widget.onSave(
                  UserModel(
                    uid: user.uid,
                    username: _usernameController.text,
                    email: _emailController.text, // 👈 UI shows new email immediately (Firestore)
                    isPremium: widget.user.isPremium,
                  ),
                );
              },
              child: Text("Got it", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      print("Error updating profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update profile. Please try again.")),
      );
    }
  }

  bool isValidPassword(String password) {
    final passwordRegex = RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>]).{6,}$');
    return passwordRegex.hasMatch(password);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kSkyBlue,
        title: const Text("Update Profile", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
        foregroundColor: kAuthNavy,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Username", style: TextStyle(fontWeight: FontWeight.bold, color: kAuthNavy)),
              TextField(controller: _usernameController),
              const SizedBox(height: 20),
              const Text("Email", style: TextStyle(fontWeight: FontWeight.bold, color: kAuthNavy)),
              TextField(controller: _emailController),
              const SizedBox(height: 20),
              const Text("New Password (optional)", style: TextStyle(fontWeight: FontWeight.bold, color: kAuthNavy)),
              TextField(
                controller: _passwordController,
                obscureText: true,
              ),
              const SizedBox(height: 20),
              const Text("Confirm New Password", style: TextStyle(fontWeight: FontWeight.bold, color: kAuthNavy)),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSkyBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _saveProfile,
                  child: Text(
                    "Save Changes",
                    style: TextStyle(fontSize: 16, color: kAuthNavy, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}