import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config.dart';

class ManageArticlesScreen extends StatelessWidget {
  const ManageArticlesScreen({super.key});

  Map<String, int> _readCounts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final uniqueReaders = <String, Set<String>>{};
    for (final doc in docs) {
      final data = doc.data();
      final articleId = (data['articleId'] ?? '').toString().trim();
      if (articleId.isEmpty) continue;
      final uid = (data['uid'] ?? '').toString().trim();
      uniqueReaders.putIfAbsent(articleId, () => <String>{}).add(
            uid.isEmpty ? doc.id : uid,
          );
    }
    return uniqueReaders.map(
      (articleId, readers) => MapEntry(articleId, readers.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection(AppConfig.articlesCollection)
        .orderBy('publishedAt', descending: true);
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Articles')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No articles yet'));
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(AppConfig.readsCollection)
                .snapshots(),
            builder: (context, readsSnap) {
              final counts = _readCounts(readsSnap.data?.docs ?? const []);
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final data = d.data();
                  final title = data['title'] ?? 'Untitled';
                  final allow = (data['allowComments'] ?? true) as bool;
                  final vis = (data['commentsVisibility'] ?? 'public') as String;
                  final publishedAt = data['publishedAt'];
                  final date = (publishedAt is Timestamp)
                      ? publishedAt.toDate().toLocal().toString().split(' ').first
                      : '';
                  final reads = counts[d.id] ?? 0;
                  return ListTile(
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('Published $date - $reads Reads / Views'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: allow,
                          onChanged: (v) =>
                              d.reference.update({'allowComments': v}),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: vis,
                          items: const [
                            DropdownMenuItem(
                              value: 'public',
                              child: Text('Public'),
                            ),
                            DropdownMenuItem(
                              value: 'private',
                              child: Text('Just Me'),
                            ),
                          ],
                          onChanged: (v) =>
                              d.reference.update({'commentsVisibility': v}),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
