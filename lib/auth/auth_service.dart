// Handles Firebase authentication and Firestore user document management
// Matches wireframes: 7.2 (Signup), 7.3 (Login), 7.2c (Upgrade Prompt)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Sign up a new user with email and password
  // Creates user document in Firestore with default Free membership
  // Automatically sends verification email
  Future<UserModel?> signup(String email, String password, String name) async {
    try {
      // Create Firebase Auth account
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send verification email immediately after account creation
      await cred.user!.sendEmailVerification();
      print('✅ Verification email sent to $email');

      // Create user document in Firestore
      final userModel = UserModel(
        uid: cred.user!.uid,
        username: name,
        email: email,
        isPremium: false, // Default: Free user
      );

      // Save to Firestore 'users' collection
      await _db.collection('users').doc(cred.user!.uid).set(userModel.toMap());

      // Return user model for UI routing
      return userModel;
    } catch (e) {
      print('Signup error: $e');
      return null;
    }
  }

  // Log in existing user with email and password
  // Fetches user document from Firestore to get membership status
  Future<UserModel?> login(String email, String password) async {
    try {
      // Sign in with Firebase Auth
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Fetch user document from Firestore
      final doc = await _db.collection('users').doc(cred.user!.uid).get();

      if (doc.exists) {
        // Parse document into UserModel
        return UserModel.fromMap(doc.data()!);
      } else {
        print('User document not found for UID: ${cred.user!.uid}');
        return null;
      }
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  // Check if email is verified
  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload(); // Refresh user data
      return user.emailVerified;
    }
    return false;
  }

// Resend verification email
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Get current user if logged in (for persistent login)
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Get user data from Firestore for current user
  Future<UserModel?> getCurrentUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting current user data: $e');
      return null;
    }
  }

  // Log out current user
  Future<void> logout() async {
    await _auth.signOut();
  }
}