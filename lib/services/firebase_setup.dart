import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseSetup {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const useEmulators = bool.fromEnvironment('FIREBASE_USE_EMULATORS');
  static const emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );

  static bool get configured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      senderId.isNotEmpty &&
      projectId.isNotEmpty;

  static Future<void> initialize() async {
    if (!configured) return;
    if (useEmulators && !projectId.startsWith('demo-')) {
      throw StateError('Firebase emulator mode requires a demo project ID.');
    }
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
        authDomain: authDomain.isEmpty ? null : authDomain,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
      ),
    );
    if (useEmulators) {
      await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9098);
      FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8188);
      if (storageBucket.isNotEmpty) {
        await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9198);
      }
    }
  }
}
