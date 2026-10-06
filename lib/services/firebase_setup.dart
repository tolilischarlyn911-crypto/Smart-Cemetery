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

  static bool get configured => hasOptions && configurationError == null;

  static bool get hasOptions =>
      apiKey.isNotEmpty ||
      appId.isNotEmpty ||
      senderId.isNotEmpty ||
      projectId.isNotEmpty;

  static String? get configurationError => firebaseConfigurationError(
    apiKey: apiKey,
    appId: appId,
    senderId: senderId,
    projectId: projectId,
  );

  static bool initialized = false;

  static Future<void> initialize() async {
    if (configurationError case final error?) {
      throw StateError(error);
    }
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
    initialized = true;
  }
}

String? firebaseConfigurationError({
  required String apiKey,
  required String appId,
  required String senderId,
  required String projectId,
}) {
  final values = {
    'FIREBASE_API_KEY': apiKey,
    'FIREBASE_APP_ID': appId,
    'FIREBASE_MESSAGING_SENDER_ID': senderId,
    'FIREBASE_PROJECT_ID': projectId,
  };
  if (values.values.every((value) => value.isEmpty)) return null;
  final missing = values.entries
      .where((entry) => entry.value.isEmpty)
      .map((entry) => entry.key)
      .toList();
  final examples = values.entries
      .where((entry) {
        final value = entry.value.toLowerCase();
        return value.contains('dummy') ||
            value.contains('placeholder') ||
            value.startsWith('your_');
      })
      .map((entry) => entry.key)
      .toList();
  if (missing.isEmpty && examples.isEmpty) return null;
  final problems = [
    if (missing.isNotEmpty) 'Missing: ${missing.join(', ')}.',
    if (examples.isNotEmpty) 'Replace example values: ${examples.join(', ')}.',
  ];
  return 'Firebase setup required. ${problems.join(' ')} '
      'Use the Firebase Web app values for Chrome, or the matching Android/iOS '
      'app values for mobile. Pass them with --dart-define-from-file and restart. '
      'To use local preview, remove the FIREBASE_* values.';
}
