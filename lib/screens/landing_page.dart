// lib/screens/landing_page.dart
// Landing page with Sign In (top) and Sign Up (bottom) — matches Wireframe 7.1
// Uses kSkyBlue background, navy buttons, centered title, 8px radius, adaptive overlay heights

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';
import '../models/user_model.dart';
import 'dashboard_screen.dart';
import 'admin_dashboard_screen.dart';
import 'pricing_screen.dart';
import '../constants/colors.dart';
import '../auth/auth_service.dart';
import '../services/admin_service.dart';


class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {

  void _showAuthOverlay(bool isSignUp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(42)),
        child: Container(
          height: isSignUp
              ? MediaQuery.of(context).size.height * 0.8
              : MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: kAuthNavy,
            borderRadius: BorderRadius.vertical(top: Radius.circular(42)),
          ),
          child: isSignUp
              ? SignupScreen(onSuccess: _handleAuthSuccess)
              : LoginScreen(onSuccess: _handleAuthSuccess),
        ),
      ),
    );
  }

  void _handleAuthSuccess(UserModel user) async {
    Navigator.pop(context);

    // Check if email is verified — if not, show overlay
    final isVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    if (!isVerified) {
      _showEmailVerificationOverlay(user);
      return;
    }

    // Check if user is admin
    final adminService = AdminService();
    final isAdmin = await adminService.isAdmin();

    if (isAdmin) {
      // Admin user - go directly to admin dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
      return;
    }

    // If verified and not admin, proceed to regular dashboard
    if (!user.isPremium) {
      _showUpgradePrompt(user);
    } else {
      _navigateToDashboard(user);
    }
  }

  void _showEmailVerificationOverlay(UserModel user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kAuthNavy,
        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        contentTextStyle: const TextStyle(color: Colors.white),
        title: const Text("📧 Verify Your Email"),
        content: const Text("Please verify your email address before using the app. Check your inbox and click the verification link."),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.currentUser!.sendEmailVerification();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Verification email resent")),
              );
            },
            child: const Text("Resend Email", style: TextStyle(color: kSkyBlue)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kSkyBlue),
            onPressed: () async {
              final isVerified = await FirebaseAuth.instance.currentUser!.reload().then((_) => FirebaseAuth.instance.currentUser!.emailVerified);
              if (isVerified) {
                Navigator.pop(ctx);
                if (!user.isPremium) {
                  _showUpgradePrompt(user);
                } else {
                  _navigateToDashboard(user);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Email not verified yet")),
                );
              }
            },
            child: Text("I Verified My Email", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showUpgradePrompt(UserModel user) async {
    // Check if admin before showing upgrade prompt
    final adminService = AdminService();
    final isAdmin = await adminService.isAdmin();

    if (isAdmin) {
      // Admin user - go directly to admin dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
      return;
    }

    // Regular user - show upgrade prompt
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kAuthNavy,
        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        contentTextStyle: const TextStyle(color: Colors.white),
        title: const Text("🎉 Welcome!"),
        content: const Text("Want unlimited scans and full reports? Upgrade to Premium now!"),
        actions: [
          TextButton(
            onPressed: () => _navigateToDashboard(user),
            child: const Text("Continue with Free", style: TextStyle(color: Colors.white)),
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
            child: Text("View Pricing", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _navigateToDashboard(UserModel user) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardScreen(user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonWidth = MediaQuery.of(context).size.width * 0.8;
    final buttonHeight = 56.0;

    return Scaffold(
      backgroundColor: kSkyBlue,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // BioShield Icon
                Image.asset(
                  'assets/icon.png',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Secure Your Biometrics',
                  style: TextStyle(
                    fontSize: 18,
                    color: kTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),

                // Sign In Button
                SizedBox(
                  width: buttonWidth,
                  height: buttonHeight,
                  child: ElevatedButton(
                    onPressed: () => _showAuthOverlay(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAuthNavy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Sign Up Button with Overlay Background
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: buttonWidth,
                      height: buttonHeight,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0x1A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    SizedBox(
                      width: buttonWidth,
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: () => _showAuthOverlay(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kSkyBlue,
                          foregroundColor: kAuthNavy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: kAuthNavy, width: 1),
                          ),
                        ),
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}