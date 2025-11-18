// lib/screens/verification_required_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'landing_page.dart';

class VerificationRequiredScreen extends StatefulWidget {
  const VerificationRequiredScreen({super.key});

  @override
  State<VerificationRequiredScreen> createState() => _VerificationRequiredScreenState();
}

class _VerificationRequiredScreenState extends State<VerificationRequiredScreen> {
  late final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _emailSent = false;

  @override
  void initState() {
    super.initState();
    // Automatically send verification email when screen loads
    _sendVerificationEmail();
  }

  Future<void> _sendVerificationEmail() async {
    if (_emailSent) return; // Don't send multiple times

    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        setState(() {
          _emailSent = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Verification email sent! Please check your inbox.")),
          );
        }
      }
    } catch (e) {
      print("Error sending verification email: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 60),
              const SizedBox(height: 20),
              const Text(
                "Email Not Verified",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Please verify your email address before continuing.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () async {
                  setState(() {
                    _emailSent = false;
                  });
                  await _sendVerificationEmail();
                },
                child: const Text("Resend Verification Email"),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () async {
                  await _auth.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LandingPage()),
                  );
                },
                child: const Text("Sign Out and Sign In Again"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}