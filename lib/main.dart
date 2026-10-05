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
  await FirebaseSetup.initialize();
  if (!FirebaseSetup.configured) {
    await CemeteryStore.instance.initialize();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const _mobileWebPreview = bool.fromEnvironment(
    'MOBILE_WEB_PREVIEW',
  );

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
