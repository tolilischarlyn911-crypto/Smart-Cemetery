import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/cemetery_store.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firebase_setup.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/custom_button.dart';
import 'login_screen.dart';
import 'main_navigation_wrapper.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _checkingSession = FirebaseSetup.configured;

  @override
  void initState() {
    super.initState();
    if (_checkingSession) _resumeSession();
  }

  Future<void> _resumeSession() async {
    try {
      final signedIn = await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (signedIn == null) {
        setState(() => _checkingSession = false);
        return;
      }
      await CemeteryStore.instance.initialize(
        firestore: FirebaseFirestore.instance,
        visitorId: signedIn.uid,
      );
      if (!mounted) return;
      final user = UserModel(
        uid: signedIn.uid,
        email: signedIn.email ?? '',
        name: signedIn.displayName?.trim().isNotEmpty == true
            ? signedIn.displayName!.trim()
            : (signedIn.email?.split('@').first ?? 'Visitor'),
        photoUrl: signedIn.photoURL,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (navContext) => MainNavigationWrapper(
            user: user,
            onLogout: () => _logout(navContext),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _checkingSession = false);
      showAppSnackBar(
        context,
        'Could not restore your session: $error',
        isError: true,
      );
    }
  }

  Future<void> _logout(BuildContext navContext) async {
    try {
      await AuthService().logout();
      await CemeteryStore.instance.disconnect();
      if (!navContext.mounted) return;
      Navigator.pushAndRemoveUntil(
        navContext,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!navContext.mounted) return;
      showAppSnackBar(navContext, '$error', isError: true);
    }
  }

  void _openPreview() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (navContext) => MainNavigationWrapper(
          user: UserModel(
            uid: 'preview-visitor',
            name: 'Preview Visitor',
            email: 'Local preview',
          ),
          onLogout: () => Navigator.pushAndRemoveUntil(
            navContext,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/cemetery_welcome.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: SizedBox.expand(),
            ),
            Container(color: Colors.black.withValues(alpha: 0.55)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B4D2E),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.church_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Smart Cemetery',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Honoring Memories,\nConnecting Generations',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade300,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    if (_checkingSession)
                      const CircularProgressIndicator(color: Colors.white),
                    if (!FirebaseSetup.configured)
                      CustomButton(
                        text: 'EXPLORE LOCAL PREVIEW',
                        color: const Color(0xFF1B4D2E),
                        onPressed: _openPreview,
                      ),
                    if (FirebaseSetup.configured && !_checkingSession) ...[
                      CustomButton(
                        text: 'LOGIN',
                        color: const Color(0xFF1B4D2E),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      CustomButton(
                        text: 'SIGN UP',
                        isOutlined: true,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignUpScreen(),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
