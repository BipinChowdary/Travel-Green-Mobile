import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? _appUser;
  bool _isLoading = false;

  // Getters
  AppUser? get appUser => _appUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _appUser != null;

  // Initialize the provider
  Future<void> initialize() async {
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      await _loadUserData(currentUser.uid);
    }
  }

  // Listen to auth state changes
  void setupAuthListener() {
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        await _loadUserData(user.uid);
      } else {
        _appUser = null;
        notifyListeners();
      }
    });
  }

  // Load user data from Firestore
  Future<void> _loadUserData(String uid) async {
    _isLoading = true;
    notifyListeners();

    final userData = await _authService.getUserData(uid);
    _appUser = userData;

    _isLoading = false;
    notifyListeners();
  }

  // Sign in
  Future<bool> signIn(String email, String password, bool rememberMe) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.signInWithEmailAndPassword(
          email, password, rememberMe);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();

      String errorMessage = 'An error occurred during sign in.';

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'user-not-approved':
          errorMessage =
              'Your account is pending approval. Please contact your organization admin.';
          break;
        case 'invalid-role':
          errorMessage =
              'This application is only for employees. Please use the appropriate portal for your role.';
          break;
        case 'too-many-requests':
          errorMessage =
              'Too many failed login attempts. Please try again later.';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred during sign in.';
      }

      _authService.showErrorToast(errorMessage);
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();

      print('Unexpected error during login: $e');
      _authService.showErrorToast(
          'An unexpected error occurred. Please try again later.');
      return false;
    }
  }

  // Sign up
  Future<bool> signUp(String name, String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.signUpWithEmailAndPassword(name, email, password);

      _isLoading = false;
      notifyListeners();

      _authService.showSuccessToast(
          'Account created successfully! Please wait for approval from your organization admin.');
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();

      String errorMessage = 'An error occurred during sign up.';

      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'The email address is already in use.';
          break;
        case 'weak-password':
          errorMessage = 'The password is too weak.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is invalid.';
          break;
        case 'organization-not-found':
          errorMessage = 'Your organization is not registered in our system.';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred during sign up.';
      }

      _authService.showErrorToast(errorMessage);
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();

      _authService.showErrorToast('An unexpected error occurred.');
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _appUser = null;
      notifyListeners();
    } catch (e) {
      _authService.showErrorToast('An error occurred during sign out.');
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.sendPasswordResetEmail(email);

      _isLoading = false;
      notifyListeners();

      _authService.showSuccessToast(
          'Password reset email sent. Please check your inbox.');
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();

      _authService.showErrorToast('Failed to send password reset email.');
      return false;
    }
  }

  // Get remembered email
  Future<String?> getRememberedEmail() async {
    return await _authService.getRememberedEmail();
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    if (_appUser != null) {
      await _loadUserData(_appUser!.uid);
    }
  }

  // Update profile
  Future<bool> updateProfile(String name) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_appUser != null) {
        await _authService.updateUserProfile(_appUser!.uid, name);
        await _loadUserData(_appUser!.uid);
      }

      _isLoading = false;
      notifyListeners();

      _authService.showSuccessToast('Profile updated successfully!');
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();

      _authService.showErrorToast('Failed to update profile.');
      return false;
    }
  }
}
