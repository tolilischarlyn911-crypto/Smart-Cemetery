import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/custom_button.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;

  Future<void> _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await _authService.signup(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Please login.'),
            backgroundColor: Color(0xFF1B4D2E),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),
                AuthTextField(
                  controller: _nameController,
                  hintText: 'Full Name',
                  prefixIcon: Icons.person_outline,
                  validator: (v) => v != null && v.trim().isNotEmpty
                      ? null
                      : 'Please enter your name',
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _emailController,
                  hintText: 'Email Address',
                  prefixIcon: Icons.email_outlined,
                  validator: (v) =>
                      v != null && v.contains('@') ? null : 'Invalid Email',
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  validator: (v) =>
                      v != null && v.length >= 6 ? null : 'Min 6 characters',
                ),
                const SizedBox(height: 28),
                _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF1B4D2E))
                    : CustomButton(
                        text: 'SIGN UP',
                        onPressed: _handleSignUp,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
