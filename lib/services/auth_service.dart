import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import 'auth_error.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserModel> login({required String email, required String password}) =>
      _guard('login', () async {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = credential.user;
        if (user == null) throw Exception('User not found');

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

  Future<void> signup({
    required String name,
    required String email,
    required String password,
  }) => _guard('signup', () async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(name);
    await credential.user?.reload();
  });

  Future<void> logout() => _guard('logout', () => _auth.signOut());

  /// Runs [action], converting any failure into an [Exception] whose message is
  /// descriptive enough to show in a toast, and logging the original error
  /// with its stack trace so it shows up in `flutter run` / DevTools / the
  /// browser console.
  Future<T> _guard<T>(String op, Future<T> Function() action) async {
    final options = _auth.app.options;
    if (isPlaceholderFirebaseConfig(options.apiKey, options.projectId)) {
      developer.log(
        '$op blocked: $firebaseNotConfiguredMessage',
        name: 'AuthService',
        level: 1000,
      );
      throw Exception(firebaseNotConfiguredMessage);
    }

    try {
      return await action();
    } on FirebaseAuthException catch (e, st) {
      final message = describeAuthError(e.code, e.message);
      developer.log(
        '$op failed: [${e.code}] ${e.message} -> $message',
        name: 'AuthService',
        error: e,
        stackTrace: st,
        level: 1000,
      );
      throw Exception(message);
    } catch (e, st) {
      developer.log(
        '$op failed unexpectedly: $e',
        name: 'AuthService',
        error: e,
        stackTrace: st,
        level: 1000,
      );
      throw Exception('Unexpected error during $op: $e');
    }
  }
}
