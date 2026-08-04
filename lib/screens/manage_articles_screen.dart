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
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final data = d.data();
                  final title = data['title'] ?? 'Untitled';
                  final publishedAt = data['publishedAt'];
                  final date = (publishedAt is Timestamp)
                      ? publishedAt.toDate().toLocal().toString().split(' ').first
                      : '';
                  final reads = counts[d.id] ?? 0;
                  return _ArticleReadCard(
                    title: title.toString(),
                    date: date,
                    reads: reads,
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

class _ArticleReadCard extends StatelessWidget {
  const _ArticleReadCard({
    required this.title,
    required this.date,
    required this.reads,
  });

  final String title;
  final String date;
  final int reads;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1EEF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE5F7F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.article_outlined,
              color: Color(0xFF007983),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  date.isEmpty ? 'Published date unavailable' : 'Published $date',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 86,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF007983),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reads.toString(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reads == 1 ? 'View' : 'Views',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
