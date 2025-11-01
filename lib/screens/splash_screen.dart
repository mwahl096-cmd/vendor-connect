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
import '../utils/role_utils.dart';

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
          final rawData = snap.data();
          final data =
              rawData is Map<String, dynamic> ? rawData : <String, dynamic>{};
          final roleLower = normalizedRole(data);
          final approvedRaw = data['approved'];
          final disabledRaw = data['disabled'];
          final approved =
              approvedRaw == true ||
              approvedRaw == 'true' ||
              approvedRaw == 1 ||
              approvedRaw == '1';
          final disabled =
              disabledRaw == true ||
              disabledRaw == 'true' ||
              disabledRaw == 1 ||
              disabledRaw == '1';
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
        final rawData = snap.data();
        data =
            rawData is Map<String, dynamic> ? rawData : <String, dynamic>{};
      } catch (_) {}

      final roleLower = normalizedRole(data);
      try {
        await context
            .read<NotificationService>()
            .subscribeAdmins(roleLower == 'admin');
      } catch (_) {}

      final disabledRaw = data['disabled'];
      final approvedRaw = data['approved'];
      final disabled =
          disabledRaw == true ||
          disabledRaw == 'true' ||
          disabledRaw == 1 ||
          disabledRaw == '1';
      final approved =
          approvedRaw == true ||
          approvedRaw == 'true' ||
          approvedRaw == 1 ||
          approvedRaw == '1';

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
    return Scaffold(
      body: Container(
        color: const Color(0xFFE7E7E7),
        alignment: Alignment.center,
        child: const Image(
          image: AssetImage('assets/images/vendor_connect_logo.png'),
          width: 260,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
