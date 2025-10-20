import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config.dart';

class NewCommentsScreen extends StatelessWidget {
  const NewCommentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final since = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));
    final q = FirebaseFirestore.instance
        .collectionGroup(AppConfig.commentsSubcollection)
        .where('createdAt', isGreaterThan: since)
        .orderBy('createdAt', descending: true)
        .limit(100);
    return Scaffold(
      appBar: AppBar(title: const Text('New Comments (24h)')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No new comments'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final text = (data['text'] ?? '').toString();
              final author = (data['authorName'] ?? '').toString();
              final date = (data['createdAt'] is Timestamp)
                  ? (data['createdAt'] as Timestamp).toDate().toLocal().toString().split(' ').first
                  : '';
              final articleId = (data['articleId'] ?? '').toString();
              return ListTile(
                title: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('$author • $date'),
                trailing: Text('#$articleId', style: const TextStyle(color: Colors.black54, fontSize: 12)),
              );
            },
          );
        },
      ),
    );
  }
}

