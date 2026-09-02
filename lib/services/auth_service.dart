import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = credential.user;
      if (user == null) {
        throw Exception('User not found');
      }

      await user.reload();
      final User? updatedUser = _auth.currentUser;

      String displayName = updatedUser?.displayName ?? '';
      if (displayName.trim().isEmpty) {
        displayName = updatedUser?.email?.split('@').first ?? 'User';
      }

      return UserModel(
        uid: updatedUser!.uid,
        email: updatedUser.email ?? '',
        name: displayName,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Authentication failed');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<void> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      await credential.user?.updateDisplayName(name);
      await credential.user?.reload();
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Sign up failed');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
