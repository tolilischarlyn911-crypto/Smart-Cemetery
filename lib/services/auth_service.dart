import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import 'auth_error.dart';
import 'firebase_setup.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Login user using Firebase Authentication.
  Future<UserModel> login({required String email, required String password}) {
    return _guard('login', () async {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('User not found');
      }

      await user.reload();

      final updatedUser = _auth.currentUser ?? user;

      String displayName = updatedUser.displayName ?? '';

      if (displayName.trim().isEmpty) {
        displayName = updatedUser.email?.split('@').first ?? 'User';
      }

      return UserModel(
        uid: updatedUser.uid,
        email: updatedUser.email ?? '',
        name: displayName,
      );
    });
  }

  /// Create a new Firebase Authentication account.
  Future<void> signup({
    required String name,
    required String email,
    required String password,
  }) {
    return _guard('signup', () async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user != null) {
        await user.updateDisplayName(name.trim());
        await user.reload();
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': name.trim(),
          'email': email.trim(),
          'role': 'visitor',
        });
        await _auth.signOut();
      }
    });
  }

  /// Logout the current Firebase user.
  Future<void> logout() {
    return _guard('logout', () => _auth.signOut());
  }

  Future<void> sendPasswordReset(String email) {
    return _guard('password reset', () async {
      try {
        await _auth.sendPasswordResetEmail(email: email.trim());
      } on FirebaseAuthException catch (error) {
        // Older projects may still return this before email enumeration
        // protection is enabled. Keep the response the same either way.
        if (error.code != 'user-not-found') rethrow;
      }
    });
  }

  /// Get the currently signed-in Firebase user.
  User? get currentUser => _auth.currentUser;

  /// Check whether a user is currently logged in.
  bool get isLoggedIn => _auth.currentUser != null;

  /// Handles Firebase errors and converts them into readable messages.
  Future<T> _guard<T>(String operation, Future<T> Function() action) async {
    if (!FirebaseSetup.initialized) {
      developer.log(
        '$operation blocked: $firebaseNotConfiguredMessage',
        name: 'AuthService',
        level: 1000,
      );

      throw Exception(firebaseNotConfiguredMessage);
    }

    try {
      return await action();
    } on FirebaseAuthException catch (e, stackTrace) {
      final message = describeAuthError(e.code, e.message);

      developer.log(
        '$operation failed: [${e.code}] ${e.message} -> $message',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
        level: 1000,
      );

      throw Exception(message);
    } catch (e, stackTrace) {
      developer.log(
        '$operation failed unexpectedly: $e',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
        level: 1000,
      );

      throw Exception('Unexpected error during $operation: $e');
    }
  }
}
