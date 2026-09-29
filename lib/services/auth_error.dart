const placeholderApiKey = 'dummy-api-key';

const firebaseNotConfiguredMessage =
    'Firebase is not configured: lib/firebase_options.dart still contains '
    'placeholder values. Run `flutterfire configure` for your Firebase project.';

/// True when [apiKey] / [projectId] are placeholders.
bool isPlaceholderFirebaseConfig(String apiKey, String projectId) =>
    apiKey == placeholderApiKey ||
    apiKey.isEmpty ||
    apiKey.contains('dummy') ||
    projectId.contains('dummy');

/// Converts Firebase Auth error codes into user-friendly messages.
String describeAuthError(String code, String? message) {
  final raw = (message ?? '').trim();
  final lc = code.toLowerCase();

  if (lc.contains('api-key') ||
      lc == 'invalid-api-key' ||
      raw.toLowerCase().contains('api key not valid')) {
    return firebaseNotConfiguredMessage;
  }

  final String human;

  switch (lc) {
    case 'email-already-in-use':
      human =
          'An account already exists for this email. Try logging in instead.';

    case 'invalid-email':
      human = 'The email address is not valid.';

    case 'weak-password':
      human = 'Password is too weak. Use at least 6 characters.';

    case 'operation-not-allowed':
      human = 'Email/password sign-in is disabled for this Firebase project. '
          'Enable it in Firebase console > Authentication > Sign-in method.';

    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      human = 'Incorrect email or password.';

    case 'user-disabled':
      human = 'This account has been disabled.';

    case 'too-many-requests':
      human = 'Too many attempts. Please wait a moment and try again.';

    case 'network-request-failed':
      human = 'Network error. Check your internet connection and try again.';

    case 'configuration-not-found':
      human = 'Firebase Authentication is not set up for this project. '
          'Enable it in the Firebase console.';

    default:
      human = raw.isEmpty || raw.toLowerCase() == 'error'
          ? 'Authentication failed.'
          : raw;
  }

  return '$human ($code)';
}
