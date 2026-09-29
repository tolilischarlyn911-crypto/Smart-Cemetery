import '../models/user_model.dart';

class AuthService {
  // Mock login method without Firebase dependencies
  Future<UserModel> login(
      {required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final String displayName =
        email.contains('@') ? email.split('@').first : 'User';

    return UserModel(
      uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: displayName,
    );
  }

  Future<void> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
