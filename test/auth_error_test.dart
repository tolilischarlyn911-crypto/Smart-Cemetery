import 'package:flutter_test/flutter_test.dart';
import 'package:capstone_project/services/auth_error.dart';

void main() {
  test('placeholder config is detected', () {
    expect(isPlaceholderFirebaseConfig('dummy-api-key', 'x'), isTrue);
    expect(isPlaceholderFirebaseConfig('', 'x'), isTrue);
    expect(
      isPlaceholderFirebaseConfig('AIzaReal', 'smart-cemetery-dummy'),
      isTrue,
    );
    expect(isPlaceholderFirebaseConfig('AIzaReal', 'smart-cemetery'), isFalse);
    expect(
      isPlaceholderFirebaseConfig('YOUR_PLATFORM_API_KEY', 'project'),
      isTrue,
    );
    expect(isPlaceholderFirebaseConfig('AIzaReal', 'YOUR_PROJECT_ID'), isTrue);
  });

  test('bad API key on web (generic "Error" message) is explained', () {
    final msg = describeAuthError(
      'api-key-not-valid.-please-pass-a-valid-api-key.',
      'Error',
    );
    expect(msg, firebaseNotConfiguredMessage);
  });

  test('bad API key on Android (unknown code, server text) is explained', () {
    final msg = describeAuthError(
      'unknown',
      'An internal error has occurred. [ API key not valid. Please pass a valid API key. ]',
    );
    expect(msg, firebaseNotConfiguredMessage);
  });

  test('known codes get human text plus the code', () {
    expect(
      describeAuthError('email-already-in-use', null),
      'An account already exists for this email. Try logging in instead. (email-already-in-use)',
    );
    expect(
      describeAuthError('wrong-password', 'whatever'),
      'Incorrect email or password. (wrong-password)',
    );
    expect(
      describeAuthError('network-request-failed', null),
      contains('Network error'),
    );
  });

  test('unknown code never yields a bare "Error"', () {
    expect(
      describeAuthError('some-new-code', 'Error'),
      'Authentication failed. (some-new-code)',
    );
    expect(
      describeAuthError('some-new-code', ''),
      'Authentication failed. (some-new-code)',
    );
    expect(
      describeAuthError('some-new-code', 'Quota exceeded.'),
      'Quota exceeded. (some-new-code)',
    );
  });
}
