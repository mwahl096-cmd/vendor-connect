import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config.dart';
import '../utils/time_utils.dart';

class NewCommentsScreen extends StatefulWidget {
  const NewCommentsScreen({super.key});

  @override
  State<NewCommentsScreen> createState() => _NewCommentsScreenState();
}

class _NewCommentsScreenState extends State<NewCommentsScreen> {
  static const Duration _window = Duration(hours: 24);
  late final Query<Map<String, dynamic>> _query;

  @override
  void initState() {
    super.initState();
    _query = FirebaseFirestore.instance
        .collectionGroup(AppConfig.commentsSubcollection)
        .orderBy('createdAt', descending: true)
        .limit(100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Comments (24h)')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'Could not load comments.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final reference = DateTime.now();

          bool isRecent(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final createdAt = doc.data()['createdAt'];
            if (createdAt == null) {
              // Pending server timestamp, keep it visible.
              return true;
            }
            return isWithinWindow(createdAt, _window, reference: reference);
          }

          final recentDocs = docs.where(isRecent).toList();

          if (recentDocs.isNotEmpty) {
            return _buildCommentsList(recentDocs);
          }

          if (docs.isNotEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
                  child: Text(
                    'No comments in the last 24 hours. Showing latest comments instead.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                Expanded(child: _buildCommentsList(docs)),
              ],
            );
          }

          return const Center(child: Text('No new comments yet'));
        },
      ),
    );
  }

  Widget _buildCommentsList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> comments,
  ) {
    return ListView.separated(
      itemCount: comments.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final d = comments[i];
        final data = d.data();
        final text = (data['text'] ?? '').toString();
        final author = (data['authorName'] ?? '').toString();
        final date = (data['createdAt'] is Timestamp)
            ? (data['createdAt'] as Timestamp)
                .toDate()
                .toLocal()
                .toString()
                .split(' ')
                .first
            : '';
        final articleId = (data['articleId'] ?? '').toString();
        return ListTile(
          title: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('$author • $date'),
          trailing: Text('#$articleId',
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
        );
      },
    );
  }
}

