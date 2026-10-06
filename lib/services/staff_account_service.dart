import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_setup.dart';

class StaffAccountService {
  static const _characters =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%';

  static String temporaryPassword() {
    final random = Random.secure();
    return List.generate(
      18,
      (_) => _characters[random.nextInt(_characters.length)],
    ).join();
  }

  static Future<String> create({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!FirebaseSetup.configured) {
      throw StateError('Connect Firebase before creating staff logins.');
    }
    final app = await Firebase.initializeApp(
      name: 'staff-provision-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    User? createdUser;
    try {
      if (FirebaseSetup.useEmulators) {
        await auth.useAuthEmulator(FirebaseSetup.emulatorHost, 9098);
      }
      if (kIsWeb) await auth.setPersistence(Persistence.NONE);
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      createdUser = credential.user;
      if (createdUser == null) {
        throw StateError('Firebase did not return the new staff account.');
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(createdUser.uid)
          .set({
            'id': createdUser.uid,
            'name': name.trim(),
            'email': email.trim(),
            'role': 'staff',
          });
      return createdUser.uid;
    } catch (_) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {
          // Auth may require a manual cleanup if the rollback fails.
        }
      }
      rethrow;
    } finally {
      await auth.signOut();
      await app.delete();
    }
  }
}
