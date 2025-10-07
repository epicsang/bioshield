import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../widgets/error_overlay.dart';
import '../constants/colors.dart';
import '../auth/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final Function(UserModel) onSuccess;

  const LoginScreen({super.key, required this.onSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final ValueNotifier<bool> _isEmailVerifiedNotifier = ValueNotifier<bool>(true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAuthNavy,
      body: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(left: 30, right: 30, bottom: 30),
          decoration: BoxDecoration(
            color: kAuthNavy,
            borderRadius: BorderRadius.vertical(top: Radius.circular(42)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Welcome Back!",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Email Field with Dynamic Verification Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Email',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isEmailVerifiedNotifier,
                    builder: (context, isVerified, child) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        height: isVerified || emailController.text.isEmpty
                            ? 60 // Normal height
                            : 120, // Expanded height to show button
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Email TextField
                            TextField(
                              controller: emailController,
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: kSkyBlue,
                                hintText: 'example@email.com',
                                hintStyle: const TextStyle(color: Colors.grey),
                                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: kAuthNavy, width: 2),
                                ),
                              ),
                            ),
                            // Only show if email is NOT verified AND email is entered
                            if (!isVerified && emailController.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Email not verified. Please check your inbox.",
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await _authService.sendEmailVerification();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Verification email resent")),
                                        );
                                      },
                                      child: const Text(
                                        "Resend",
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Password Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Password',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  TextField(
                    controller: passwordController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: kSkyBlue,
                      hintText: '********',
                      hintStyle: const TextStyle(color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kAuthNavy, width: 2),
                      ),
                    ),
                    obscureText: true,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: kAuthNavy,
                          titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          contentTextStyle: const TextStyle(color: Colors.white),
                          title: const Text("Forgot Password"),
                          content: const Text("Enter your email to receive a reset link."),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: kSkyBlue),
                              onPressed: () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Password reset link sent (simulated)")),
                                );
                              },
                              child: Text("Send", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text("Forgot Password?", style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSkyBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
                      await showDialog(
                        context: context,
                        builder: (ctx) => ErrorOverlay(
                          message: "Please enter both email and password.",
                          onRetry: () {},
                        ),
                      );
                      return;
                    }

                    UserModel? user = await _authService.login(
                      emailController.text,
                      passwordController.text,
                    );

                    if (user != null) {
                      // Check email verification status
                      final isVerified = await _authService.isEmailVerified();
                      _isEmailVerifiedNotifier.value = isVerified; // Trigger UI update

                      if (!isVerified) {
                        // Block access and show message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please verify your email before using the app")),
                        );
                        return;
                      }

                      widget.onSuccess(user);
                    } else {
                      await showDialog(
                        context: context,
                        builder: (ctx) => ErrorOverlay(
                          message: "Invalid email or password. Please try again.",
                          onRetry: () {},
                        ),
                      );
                    }
                  },
                  child: Text('Login', style: TextStyle(fontSize: 18, color: kAuthNavy, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}