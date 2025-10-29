import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'auth_screen.dart';

class PendingApprovalScreen extends StatelessWidget {
  static const route = '/pending';
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Awaiting Approval')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Thanks for registering! Your account is pending admin approval.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text('You will receive access once approved.'),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () async {
                final notificationService = context.read<NotificationService>();
                final authService = context.read<AuthService>();
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                final previousUid = FirebaseAuth.instance.currentUser?.uid;
                try {
                  await authService.signOut();
                } on FirebaseAuthException catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        e.message ?? 'Unable to sign out. Please retry.',
                      ),
                    ),
                  );
                  return;
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Unable to sign out. Please retry.'),
                    ),
                  );
                  return;
                }
                unawaited(
                  notificationService.cleanupAfterSignOut(
                    uidOverride: previousUid,
                  ),
                );
                if (!context.mounted) return;
                navigator.pushNamedAndRemoveUntil(
                  AuthScreen.route,
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
