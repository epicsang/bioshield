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
                  try {
                    final user = _auth.currentUser;
                    if (user != null) {
                      await user.sendEmailVerification();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Verification email sent!")),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to send email.")),
                    );
                  }
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