// lib/main.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/loading_screen.dart';
import 'screens/landing_page.dart';
import 'screens/verification_required_screen.dart';
import 'constants/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Mobile Ads SDK
  await MobileAds.instance.initialize();

  final auth = FirebaseAuth.instance;

  // 👇 CHECK AUTH STATE BEFORE LAUNCHING UI
  final user = auth.currentUser;

  if (user != null) {
    // User is signed in — check if email is verified
    await user.reload(); // Force refresh from server
    if (!user.emailVerified) {
      // Not verified → show verification screen
      runApp(BioShieldApp(shouldShowVerificationOverlay: true));
      return;
    } else {
      // Verified → go straight to dashboard
      runApp(const BioShieldApp());
      return;
    }
  }

  // No user → show normal flow
  runApp(const BioShieldApp());
}

class BioShieldApp extends StatelessWidget {
  final bool shouldShowVerificationOverlay;

  const BioShieldApp({super.key, this.shouldShowVerificationOverlay = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kSkyBlue,
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: kSkyBlue,
          foregroundColor: kAuthNavy,
          titleTextStyle: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold),
        ),
        textTheme: TextTheme(
          titleLarge: TextStyle(color: kAuthNavy, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: kAuthNavy),
          bodyLarge: TextStyle(color: kTextPrimary),
          bodyMedium: TextStyle(color: kTextSecondary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kSkyBlue,
            foregroundColor: kAuthNavy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: kAuthNavy),
        ),
      ),
      darkTheme: ThemeData(
        scaffoldBackgroundColor: kAuthNavy,
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: kAuthNavy,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        textTheme: TextTheme(
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white54),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kSkyBlue,
            foregroundColor: kAuthNavy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
      ),
      themeMode: ThemeMode.system,
      home: shouldShowVerificationOverlay
          ? const VerificationRequiredScreen()
          : const LoadingScreen(),
    );
  }
}