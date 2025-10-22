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
  late final Duration _window;
  late final Query<Map<String, dynamic>> _query;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lastRecentDocs = const [];

  @override
  void initState() {
    super.initState();
    _window = const Duration(hours: 24);
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

          final docs = snap.data?.docs ?? [];
          final reference = DateTime.now();
          final recentDocs = docs
              .where(
                (doc) =>
                    isWithinWindow(doc.data()['createdAt'], _window, reference: reference),
              )
              .toList();
          final isFromCache = snap.data?.metadata.isFromCache ?? true;

          if (recentDocs.isNotEmpty) {
            _lastRecentDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(recentDocs);
            return _buildCommentsList(_lastRecentDocs);
          }

          if (_lastRecentDocs.isNotEmpty &&
              (isFromCache || snap.connectionState == ConnectionState.waiting)) {
            return _buildCommentsList(_lastRecentDocs);
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
  }
}
