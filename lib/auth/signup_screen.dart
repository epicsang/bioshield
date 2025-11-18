// lib/auth/signup_screen.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/validators.dart';
import '../widgets/error_overlay.dart';
import '../constants/colors.dart';
import 'auth_service.dart';

class SignupScreen extends StatefulWidget {
  final Function(UserModel) onSuccess;

  const SignupScreen({super.key, required this.onSuccess});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final AuthService authService = AuthService();

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAuthNavy,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
            decoration: BoxDecoration(
              color: kAuthNavy,
              borderRadius: BorderRadius.circular(42),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Welcome! — at very top
              const Text(
                "Welcome!",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20), // 👈 Reduced spacing

              // Username Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Username',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  TextField(
                    controller: usernameController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: kSkyBlue,
                      hintText: 'Username',
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
                ],
              ),
              const SizedBox(height: 20),

              // Email Field
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

              // Confirm Password Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Confirm Password',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  TextField(
                    controller: confirmPasswordController,
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
              const SizedBox(height: 10),

              Text(
                "Password must include uppercase, number, and special character",
                style: TextStyle(fontSize: 12, color: Colors.white70),
                textAlign: TextAlign.center,
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
                    if (usernameController.text.isEmpty ||
                        emailController.text.isEmpty ||
                        passwordController.text.isEmpty) {
                      await showDialog(
                        context: context,
                        builder: (ctx) => ErrorOverlay(
                          message: "Please fill in all fields.",
                          onRetry: () {},
                        ),
                      );
                      return;
                    }

                    if (passwordController.text != confirmPasswordController.text) {
                      await showDialog(
                        context: context,
                        builder: (ctx) => ErrorOverlay(
                          message: "Passwords do not match. Please try again.",
                          onRetry: () {},
                        ),
                      );
                      return;
                    }

                    if (!isValidPassword(passwordController.text)) {
                      await showDialog(
                        context: context,
                        builder: (ctx) => ErrorOverlay(
                          message: "Password must include:\n• Uppercase letter\n• Number\n• Special character",
                          onRetry: () {},
                        ),
                      );
                      return;
                    }

                    UserModel? user = await authService.signup(
                      emailController.text,
                      passwordController.text,
                      usernameController.text,
                    );

                    if (user != null) {
                      await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: kAuthNavy,
                          titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          contentTextStyle: const TextStyle(color: Colors.white),
                          title: const Text("📧 Email Sent"),
                          content: Text("A confirmation email has been sent to ${user.email}. Please verify to complete registration."),
                          actions: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: kSkyBlue),
                              onPressed: () {
                                Navigator.pop(ctx);
                                Future.delayed(const Duration(seconds: 1), () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: kAuthNavy,
                                      titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      contentTextStyle: const TextStyle(color: Colors.white),
                                      title: const Text("✅ Registration Complete"),
                                      content: const Text("Your account is now active. Welcome to BioShield!"),
                                      actions: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: kSkyBlue),
                                          onPressed: () => Navigator.pop(ctx),
                                          child: Text("Got it", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                });
                                widget.onSuccess(user);
                              },
                              child: Text("OK", style: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    } else {
                      await showDialog(
                        context: context,
                        builder: (ctx) => ErrorOverlay(
                          message: "Signup failed. Please try again.",
                          onRetry: () {},
                        ),
                      );
                    }
                  },
                  child: Text('Sign Up', style: TextStyle(fontSize: 18, color: kAuthNavy, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}