// lib/screens/loading_screen.dart
// Shows loading animation before transitioning to landing page (Wireframe 7.1)
// Simulates app initialization for 2 seconds

import 'package:flutter/material.dart';
import 'landing_page.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    // Simulate 2 seconds of loading, then navigate to landing page
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LandingPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text("Initializing BioShield...", style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}