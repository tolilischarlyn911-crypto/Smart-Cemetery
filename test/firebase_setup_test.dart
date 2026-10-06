import 'package:capstone_project/services/firebase_setup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing Firebase options select local preview', () {
    expect(
      firebaseConfigurationError(
        apiKey: '',
        appId: '',
        senderId: '',
        projectId: '',
      ),
      isNull,
    );
  });

  test('partial and example values produce a setup error', () {
    String? issue({
      required String apiKey,
      required String appId,
      required String senderId,
      required String projectId,
    }) => firebaseConfigurationError(
      apiKey: apiKey,
      appId: appId,
      senderId: senderId,
      projectId: projectId,
    );

    expect(
      issue(
        apiKey: 'AIzaReal',
        appId: '',
        senderId: '123',
        projectId: 'project',
      ),
      contains('Missing: FIREBASE_APP_ID'),
    );
    expect(
      issue(
        apiKey: 'YOUR_PLATFORM_API_KEY',
        appId: 'YOUR_PLATFORM_APP_ID',
        senderId: 'YOUR_SENDER_ID',
        projectId: 'YOUR_PROJECT_ID',
      ),
      contains('Replace example values: FIREBASE_API_KEY'),
    );
    expect(
      issue(
        apiKey: 'AIzaReal',
        appId: '1:123:web:real',
        senderId: '123',
        projectId: 'smart-cemetery',
      ),
      isNull,
    );
  });
}
