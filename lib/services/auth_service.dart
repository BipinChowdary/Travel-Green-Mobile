import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/organization.dart';
import '../models/pending_employee.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password, bool rememberMe) async {
    try {
      // Sign in with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if user is approved
      final userDoc =
          await _firestore.collection('users').doc(credential.user!.uid).get();

      if (!userDoc.exists) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'User does not exist in the database.',
        );
      }

      final userData = userDoc.data()!;

      // Check if user is approved
      if (!(userData['approved'] as bool)) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'user-not-approved',
          message:
              'Your account is pending approval. Please contact your organization admin.',
        );
      }

      // Check if user has the employee role
      final String userRole = userData['role'] as String? ?? '';
      if (userRole != 'employee') {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'invalid-role',
          message:
              'This application is only for employees. Please use the appropriate portal for your role.',
        );
      }

      // Update last login timestamp
      await _firestore.collection('users').doc(credential.user!.uid).update({
        'lastLogin': Timestamp.now(),
      });

      // Save remember me preference
      if (rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rememberMe', true);
        await prefs.setString('email', email);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rememberMe', false);
        await prefs.remove('email');
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw e;
    }
  }

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailAndPassword(
      String name, String email, String password) async {
    try {
      // Extract domain from email
      final domain = email.split('@').last;

      // Check if organization exists and is approved
      final orgQuerySnapshot = await _firestore
          .collection('organizations')
          .where('domain', isEqualTo: domain)
          .where('approved', isEqualTo: true)
          .get();

      if (orgQuerySnapshot.docs.isEmpty) {
        throw FirebaseAuthException(
          code: 'organization-not-found',
          message: 'Your organization is not registered in our system.',
        );
      }

      final orgDoc = orgQuerySnapshot.docs.first;
      final orgData = orgDoc.data();

      // Create user in Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      // Create pending employee entry
      final pendingEmployee = PendingEmployee(
        id: uid,
        fullName: name,
        email: email,
        domain: domain,
        orgId: orgDoc.id,
        organizationName: orgData['name'],
        role: 'employee',
        approved: false,
        createdAt: DateTime.now().toIso8601String(),
      );

      // Add to pending_employees collection
      await _firestore
          .collection('pending_employees')
          .doc(uid)
          .set(pendingEmployee.toFirestore());

      // Also create user entry but with approved = false
      final appUser = AppUser(
        uid: uid,
        name: name,
        email: email,
        role: UserRole.employee,
        approved: false,
        orgId: orgDoc.id,
        domain: domain,
        organizationName: orgData['name'],
        createdAt: Timestamp.now(),
        lastLogin: Timestamp.now(),
      );

      await _firestore.collection('users').doc(uid).set(appUser.toFirestore());

      // Sign out immediately after signup
      await _auth.signOut();

      return credential;
    } on FirebaseAuthException catch (e) {
      throw e;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Get user data
  Future<AppUser?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> userData = doc.data()!;

        // Check if carbonCredits field exists, if not, create it
        if (!userData.containsKey('carbonCredits')) {
          await _firestore
              .collection('users')
              .doc(uid)
              .update({'carbonCredits': 0.0});
          userData['carbonCredits'] = 0.0;
        }

        return AppUser.fromFirestore(userData);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      // Log more detailed error information to help with debugging
      if (e is TypeError) {
        print('Type error details: ${e.toString()}');
      } else if (e is FormatException) {
        print('Format exception details: ${e.toString()}');
      }

      // If there's an error getting user data, sign out to avoid being stuck in a broken state
      try {
        await _auth.signOut();
        showErrorToast('Error loading user data. Please sign in again.');
      } catch (_) {
        // Ignore errors during sign out
      }

      return null;
    }
  }

  // Check if user is remembered
  Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('rememberMe') ?? false;

    if (rememberMe) {
      return prefs.getString('email');
    }

    return null;
  }

  // Update user profile
  Future<void> updateUserProfile(String uid, String name) async {
    await _firestore.collection('users').doc(uid).update({
      'name': name,
    });
  }

  // Show error toast
  void showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  // Show success toast
  void showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }
}
