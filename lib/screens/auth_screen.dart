import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';
import 'pending_approval_screen.dart';

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
        // Go straight to pending approval screen for new users
        Navigator.of(context).pushReplacementNamed(PendingApprovalScreen.route);
        return;
      }
      if (!mounted) return;
      // For existing users, route through Splash
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
    final registering =
        !_isLogin && !AppConfig.enableSelfRegistration;
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Vendor Login' : 'Register Vendor')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6)),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_isLogin) ...[
                        if (registering)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F6F7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF2BBFD4).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              'Vendor accounts are created by Market Street Creatives. '
                              'Please email ${AppConfig.supportEmail} to request access.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: 'Your Name', prefixIcon: Icon(Icons.person_outline)),
                          validator:
                              (v) =>
                                  (!_isLogin && !AppConfig.enableSelfRegistration)
                                      ? null
                                      : (v == null || v.isEmpty)
                                          ? 'Required'
                                          : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _business,
                          decoration: const InputDecoration(labelText: 'Business Name', prefixIcon: Icon(Icons.storefront_outlined)),
                          validator:
                              (v) =>
                                  (!_isLogin && !AppConfig.enableSelfRegistration)
                                      ? null
                                      : (v == null || v.isEmpty)
                                          ? 'Required'
                                          : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone (optional)',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            final trimmed = v?.trim() ?? '';
                            if (trimmed.isEmpty) return null;
                            final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
                            if (digitsOnly.length < 7) {
                              return 'Enter a valid phone or leave blank';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline)),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                        obscureText: true,
                        validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed:
                            _loading || registering ? null : _submit,
                        child: Text(_isLogin ? 'SIGN IN' : 'REGISTER'),
                      ),
                      if (_isLogin) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : _resetPassword,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading ? null : () => setState(() => _isLogin = !_isLogin),
                        child: Text(
                          _isLogin ? 'Need an account? Register here' : 'Already have an account? Log in',
                          style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF2BBFD4)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
