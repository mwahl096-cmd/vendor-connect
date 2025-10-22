import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../utils/time_utils.dart';

import 'manage_articles_screen.dart';
import 'admin_vendors_screen.dart';
import 'new_comments_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Stream<int> _countArticles() => FirebaseFirestore.instance
      .collection(AppConfig.articlesCollection)
      .snapshots()
      .map((s) => s.size);

  Stream<int> _countVendors() => FirebaseFirestore.instance
      .collection(AppConfig.usersCollection)
      .where('role', isEqualTo: 'vendor')
      .snapshots()
      .map((s) => s.size);

  Stream<int> _countComments24h() {
    final window = const Duration(hours: 24);
    final since = Timestamp.fromDate(DateTime.now().subtract(window));
    return FirebaseFirestore.instance
        .collectionGroup(AppConfig.commentsSubcollection)
        .where('createdAt', isGreaterThan: since)
        .snapshots()
        .map((snapshot) {
      final reference = DateTime.now();
      return snapshot.docs
          .where((doc) => isWithinWindow(doc.data()['createdAt'], window, reference: reference))
          .length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard(
        title: 'Total Articles',
        color: const Color(0xFF2BBFD4),
        icon: Icons.description_outlined,
        stream: _countArticles(),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ManageArticlesScreen()),
        ),
      ),
      _StatCard(
        title: 'Registered Vendors',
        color: const Color(0xFF6EA7E5),
        icon: Icons.group_outlined,
        stream: _countVendors(),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminVendorsScreen()),
        ),
      ),
      _StatCard(
        title: 'New Comments (24h)',
        color: const Color(0xFFFFA64D),
        icon: Icons.chat_bubble_outline,
        stream: _countComments24h(),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NewCommentsScreen()),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive grid of cards
            LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 900 ? 3 : width > 600 ? 2 : 1;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 3.6,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: cards,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final Stream<int> stream;
  final VoidCallback? onTap;
  const _StatCard({required this.title, required this.color, required this.icon, required this.stream, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [color.withOpacity(0.15), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
                const SizedBox(height: 6),
                StreamBuilder<int>(
                  stream: stream,
                  builder: (context, snap) {
                    final value = snap.data?.toString() ?? '—';
                    return Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700));
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: card);
  }
}

// Panels removed per request; navigation happens via stat cards
