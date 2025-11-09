import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/auth_service.dart';
import 'pending_approval_screen.dart';
import 'splash_screen.dart';

class AuthScreen extends StatefulWidget {
  static const route = '/auth';
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _business = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLogin = false;
  bool _loading = false;

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email to reset password')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = _friendlyError(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password is too weak (min 6 characters).';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is disabled in Firebase.';
      default:
        return e.message ?? 'Authentication error.';
    }
  }

  Future<void> _submit() async {
    if (!_isLogin && !AppConfig.enableSelfRegistration) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Self-service registration is currently disabled. '
            'Please contact ${AppConfig.supportEmail} to request an account.',
          ),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      UserCredential cred;
      if (_isLogin) {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        await auth.ensureProfile(
          cred.user!,
          name: _name.text.trim(),
          businessName: _business.text.trim(),
          phone: _phone.text.trim(),
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(PendingApprovalScreen.route);
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(SplashScreen.route);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = _friendlyError(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final registering = !_isLogin && !AppConfig.enableSelfRegistration;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              decoration: const BoxDecoration(
                color: Color(0xFF00B5D9),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _isLogin ? 'Vendor Login' : 'Register Vendor',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 30,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 26,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_isLogin) ...[
                              _LinedField(
                                controller: _name,
                                hint: 'Your Name',
                                icon: Icons.person_outline,
                                validator:
                                    (v) =>
                                        (!_isLogin &&
                                                !AppConfig
                                                    .enableSelfRegistration)
                                            ? null
                                            : (v == null || v.isEmpty)
                                            ? 'Required'
                                            : null,
                              ),
                              const SizedBox(height: 12),
                              _LinedField(
                                controller: _business,
                                hint: 'Business Name',
                                icon: Icons.storefront_outlined,
                                validator:
                                    (v) =>
                                        (!_isLogin &&
                                                !AppConfig
                                                    .enableSelfRegistration)
                                            ? null
                                            : (v == null || v.isEmpty)
                                            ? 'Required'
                                            : null,
                              ),
                              const SizedBox(height: 12),
                              _LinedField(
                                controller: _phone,
                                hint: 'Phone (optional)',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                validator: (v) {
                                  final trimmed = v?.trim() ?? '';
                                  if (trimmed.isEmpty) return null;
                                  final digitsOnly = trimmed.replaceAll(
                                    RegExp(r'\D'),
                                    '',
                                  );
                                  if (digitsOnly.length < 7) {
                                    return 'Enter a valid phone or leave blank';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            _LinedField(
                              controller: _email,
                              hint: 'Email address',
                              icon: Icons.mail_outline,
                              keyboardType: TextInputType.emailAddress,
                              validator:
                                  (v) =>
                                      (v == null || !v.contains('@'))
                                          ? 'Enter a valid email'
                                          : null,
                            ),
                            const SizedBox(height: 12),
                            _LinedField(
                              controller: _password,
                              hint: 'Password',
                              icon: Icons.lock_outline,
                              obscureText: true,
                              validator:
                                  (v) =>
                                      (v == null || v.length < 6)
                                          ? 'Min 6 characters'
                                          : null,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00B5D9),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed:
                                    _loading || registering ? null : _submit,
                                child: Text(_isLogin ? 'SIGN IN' : 'REGISTER'),
                              ),
                            ),
                            if (_isLogin) ...[
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _loading ? null : _resetPassword,
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed:
                                  _loading
                                      ? null
                                      : () =>
                                          setState(() => _isLogin = !_isLogin),
                              child: Text(
                                _isLogin
                                    ? 'Need an account? Register here'
                                    : 'Already have an account? Log in',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF00B5D9),
                                  fontWeight: FontWeight.w600,
                                ),
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
          ],
        ),
      ),
    );
  }
}

class _LinedField extends StatelessWidget {
  const _LinedField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF5E6A75)),
        filled: true,
        fillColor: const Color(0xFFF9FBFC),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFE2E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFE2E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF00B5D9), width: 1.5),
        ),
      ),
    );
  }
}
