import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/cemetery_store.dart';
import '../../services/auth_service.dart';
import 'admin_shell.dart';

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, auth) {
        if (auth.hasError) {
          return _message('Authentication failed: ${auth.error}');
        }
        if (!auth.hasData) {
          if (_initialization != null) {
            unawaited(CemeteryStore.instance.disconnect());
          }
          _initialization = null;
          _initializationUid = null;
          return const AdminLogin();
        }
        final user = auth.data!;
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, role) {
            if (role.hasError) {
              return _message(
                'Could not check administrator access: ${role.error}',
              );
            }
            if (!role.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final accessRole = role.data!.data()?['role'];
            if (accessRole != 'admin' && accessRole != 'staff') {
              if (_initialization != null) {
                unawaited(CemeteryStore.instance.disconnect());
              }
              _initialization = null;
              _initializationUid = null;
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Administrator or staff access is required.'),
                      TextButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return FutureBuilder<void>(
              future: _startData(user.uid, accessRole as String),
              builder: (context, data) {
                if (data.hasError) {
                  return _message(
                    'Could not load cemetery data: ${data.error}',
                  );
                }
                if (data.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return AdminShell(
                  key: ValueKey('${user.uid}:$accessRole'),
                  role: accessRole,
                  onLogout: () async {
                    _initialization = null;
                    _initializationUid = null;
                    await FirebaseAuth.instance.signOut();
                    await CemeteryStore.instance.disconnect();
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  static Future<void>? _initialization;
  static String? _initializationUid;
  Future<void> _startData(String uid, String role) {
    final accessKey = '$uid:$role';
    if (_initializationUid != accessKey) {
      _initializationUid = accessKey;
      _initialization = CemeteryStore.instance.initialize(
        firestore: FirebaseFirestore.instance,
        admin: role == 'admin',
        staffAccess: role == 'staff',
      );
    }
    return _initialization!;
  }

  Widget _message(String message) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool resetting = false;
  String? error;
  String? notice;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Enter your email and password.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
      notice = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } on FirebaseAuthException catch (exception) {
      if (mounted) setState(() => error = exception.message ?? exception.code);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final address = email.text.trim();
    if (address.isEmpty) {
      setState(() => error = 'Enter your email address first.');
      return;
    }
    setState(() {
      resetting = true;
      error = null;
      notice = null;
    });
    try {
      await AuthService().sendPasswordReset(address);
      if (mounted) {
        setState(
          () => notice = 'If an account uses this email, check your inbox for a reset link.',
        );
      }
    } catch (exception) {
      if (mounted) {
        setState(
          () => error = exception.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 32
                  ? constraints.maxHeight - 32
                  : 0,
            ),
            child: Center(
              child: SizedBox(
                width: 400,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.admin_panel_settings, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Smart Cemetery Admin',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: email,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: password,
                          obscureText: true,
                          onSubmitted: (_) => _signIn(),
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: loading || resetting
                                ? null
                                : _sendPasswordReset,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        if (notice != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              notice!,
                              style: const TextStyle(color: Color(0xFF0B4A2D)),
                            ),
                          ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: loading || resetting ? null : _signIn,
                            child: Text(loading ? 'Signing in…' : 'Sign in'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
