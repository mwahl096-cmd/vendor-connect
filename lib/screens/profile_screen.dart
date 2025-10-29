import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/notification_service.dart';
import 'auth_screen.dart';
import 'admin_vendors_screen.dart';
import 'admin_dashboard.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    final userDoc = FirebaseFirestore.instance.collection(AppConfig.usersCollection).doc(uid);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDoc.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = (snap.data!.data());
          if (data == null) return const Center(child: Text('No profile'));
          final isAdmin = (data['role'] ?? 'vendor') == 'admin';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile header card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 28, child: Text((data['name'] ?? (data['email'] ?? '?')).toString().substring(0, 1).toUpperCase())),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${data['name'] ?? ''}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('${data['email'] ?? ''}', style: const TextStyle(color: Colors.black54)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Info cards
              Row(children: [
                Expanded(child: _infoTile('Business', '${data['businessName'] ?? ''}')),
                const SizedBox(width: 12),
                Expanded(child: _infoTile('Phone', '${data['phone'] ?? ''}')),
              ]),
              const SizedBox(height: 20),
              if (isAdmin) ...[
                Text('Admin Tools', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                // Dashboard shortcut
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                  ),
                  icon: const Icon(Icons.dashboard_customize),
                  label: const Text('Open Admin Dashboard'),
                ),
                const SizedBox(height: 20),
              ],
              ElevatedButton.icon(
                onPressed: () async {
                  await context
                      .read<NotificationService>()
                      .subscribeAdmins(false);
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(AuthScreen.route, (route) => false);
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminPanel extends StatelessWidget {
  const _AdminPanel();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin - Articles')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(AppConfig.articlesCollection)
            .orderBy('publishedAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            children: snap.data!.docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final allow = (data['allowComments'] ?? true) as bool;
              final vis = (data['commentsVisibility'] ?? 'public') as String;
              return ListTile(
                title: Text('${data['title']}'),
                subtitle: Text('Comments: ${allow ? 'On' : 'Off'} • $vis'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: allow,
                      onChanged: (v) => d.reference.update({'allowComments': v}),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: vis,
                      items: const [
                        DropdownMenuItem(value: 'public', child: Text('Public')),
                        DropdownMenuItem(value: 'private', child: Text('Just Me')),
                      ],
                      onChanged: (v) => d.reference.update({'commentsVisibility': v}),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// Small helper to render info tiles in the profile header
Widget _infoTile(String title, String value) {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.grey.shade300),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value.isNotEmpty ? value : '-', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}
