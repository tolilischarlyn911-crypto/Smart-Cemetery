# Smart Cemetery (capstone_project)

Flutter app using Firebase Authentication (email/password).

## Firebase setup (required before sign-up / login work)

`lib/firebase_options.dart` is committed with **placeholder** values
(`apiKey: 'dummy-api-key'`, `projectId: 'smart-cemetery-dummy'`). With those
values every auth call is rejected by Firebase with `API_KEY_INVALID`, and the
app shows "Firebase is not configured…" instead of letting you sign up or log in.

To point the app at a real project:

```sh
dart pub global activate flutterfire_cli
flutterfire configure            # pick / create your Firebase project, select platforms
```

This regenerates `lib/firebase_options.dart` and drops
`android/app/google-services.json` / `ios/Runner/GoogleService-Info.plist`.
Then, in the Firebase console, enable **Authentication → Sign-in method →
Email/Password**.

## Run

```sh
flutter pub get
flutter run -d chrome        # or an Android/iOS device
flutter test                 # unit tests for auth error mapping
```

## Where errors go

Every auth failure (sign-up, login, logout) shows a red toast with a
human-readable reason **and the Firebase error code** in parentheses, and is
logged under the `AuthService` tag (visible in the `flutter run` console, the
browser devtools console on web, or Flutter DevTools). Search that tag when
reporting a bug.
