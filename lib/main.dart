import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'data/cemetery_store.dart';
import 'screens/welcome_screen.dart';
import 'screens/admin/admin_gate.dart';
import 'screens/admin/admin_preview_gate.dart';
import 'services/firebase_setup.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }
  try {
    await FirebaseSetup.initialize();
  } catch (error) {
    runApp(
      FirebaseSetupFailure(
        message:
            FirebaseSetup.configurationError ??
            'Could not initialize Firebase. Check that this build uses the '
                'Firebase Web app values for Chrome or the matching Android/iOS '
                'app values for mobile, then restart. Also check network access '
                'and Firebase emulator availability if enabled. Details: $error',
      ),
    );
    return;
  }
  if (!FirebaseSetup.configured) {
    await CemeteryStore.instance.initialize();
  }
  runApp(const MyApp());
}

class FirebaseSetupFailure extends StatelessWidget {
  const FirebaseSetupFailure({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Smart Cemetery',
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const _mobileWebPreview = bool.fromEnvironment('MOBILE_WEB_PREVIEW');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Cemetery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: kIsWeb && !_mobileWebPreview
          ? (FirebaseSetup.configured
                ? const AdminGate()
                : const AdminPreviewGate())
          : const WelcomeScreen(),
    );
  }
}
