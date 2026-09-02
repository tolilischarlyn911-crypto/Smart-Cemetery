import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'dummy-api-key',
      appId: '1:123456789:android:dummy',
      messagingSenderId: '123456789',
      projectId: 'smart-cemetery-dummy',
    );
  }
}
