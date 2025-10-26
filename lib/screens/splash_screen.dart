import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'home_shell.dart';
import 'pending_approval_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config.dart';

class SplashScreen extends StatefulWidget {
  static const route = '/';
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _didNavigate = false;
  void _go(String route) {
    if (_didNavigate || !mounted) return;
    _didNavigate = true;
    Navigator.of(context).pushReplacementNamed(route);
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Absolute fallback: never stay here forever
      Future.delayed(const Duration(seconds: 6), () async {
        if (_didNavigate || !mounted) return;
        final u = FirebaseAuth.instance.currentUser;
        if (u == null) {
          _go(AuthScreen.route);
          return;
        }
        // Try a quick profile fetch; if it fails, prefer Home rather than Auth
        try {
          final snap = await FirebaseFirestore.instance
              .collection(AppConfig.usersCollection)
              .doc(u.uid)
              .get()
              .timeout(const Duration(seconds: 2));
          if (!snap.exists) {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account not found. Please contact support.')),
            );
            _go(AuthScreen.route);
            return;
          }
          final data = (snap.data() as Map<String, dynamic>?) ?? {};
          final roleLower = (data['role'] ?? 'vendor').toString().toLowerCase().trim();
          final approvedRaw = data['approved'];
          final disabledRaw = data['disabled'];
          final approved = approvedRaw == true || approvedRaw == 'true';
          final disabled = disabledRaw == true || disabledRaw == 'true';
          if (roleLower == 'admin') {
            _go(HomeShell.route);
            return;
          }
          if (disabled) {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            _go(AuthScreen.route);
          } else if (!approved) {
            _go(PendingApprovalScreen.route);
          } else {
            _go(HomeShell.route);
          }
        } catch (_) {
          _go(HomeShell.route);
        }
      });
      // Initialize notifications, but never block navigation
      try { await context.read<NotificationService>().init(); } catch (_) {}

      // Get auth state with a hard timeout and fallback
      User? u;
      try {
        u = await FirebaseAuth.instance
            .authStateChanges()
            .first
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        u = FirebaseAuth.instance.currentUser;
      }

      // Keep splash visible for ~3 seconds total
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;
      if (u == null) {
        _go(AuthScreen.route);
        return;
      }

      // Fetch profile, but guard with timeout and defaults
      Map<String, dynamic> data = const {};
      try {
        final snap = await FirebaseFirestore.instance
            .collection(AppConfig.usersCollection)
            .doc(u.uid)
            .get()
            .timeout(const Duration(seconds: 3));
        if (!snap.exists) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account not found. Please contact support.')),
          );
          _go(AuthScreen.route);
          return;
        }
        data = (snap.data() as Map<String, dynamic>?) ?? {};
      } catch (_) {}

      final roleStr = (data['role'] ?? 'vendor').toString();
      final roleLower = roleStr.toLowerCase().trim();
      try {
        await context
            .read<NotificationService>()
            .subscribeAdmins(roleLower == 'admin');
      } catch (_) {}

      final disabledRaw = data['disabled'];
      final approvedRaw = data['approved'];
      final disabled = disabledRaw == true || disabledRaw == 'true';
      final approved = approvedRaw == true || approvedRaw == 'true';

      // Admins always bypass approval screen
      if (roleLower == 'admin') {
        try { await context.read<AuthService>().updateLastLogin(); } catch (_) {}
        _go(HomeShell.route);
        return;
      }

      if (disabled) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your account has been disabled.')),
        );
        _go(AuthScreen.route);
        return;
      }

      if (!approved) {
        _go(PendingApprovalScreen.route);
      } else {
        try { await context.read<AuthService>().updateLastLogin(); } catch (_) {}
        _go(HomeShell.route);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2BBFD4), Color(0xFF6EA7E5)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/vendor_connect_logo.png',
                  height: 118,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              Text('Vendor Connect', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Your Market Communication Hub', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
