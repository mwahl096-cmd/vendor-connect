import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import 'auth_screen.dart';
import 'package:flutter/material.dart';

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
                await context.read<NotificationService>().subscribeAdmins(false);
                await context
                    .read<NotificationService>()
                    .ensureArticleTopic(subscribe: false);
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(AuthScreen.route, (route) => false);
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            )
          ],
        ),
      ),
    );
  }
}



