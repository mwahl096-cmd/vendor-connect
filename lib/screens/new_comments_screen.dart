import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config.dart';

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
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime.now().subtract(_window),
          ),
        )
        .orderBy('createdAt', descending: true)
        .limit(100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Comments (24h)')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query.snapshots(includeMetadataChanges: true),
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

          if (docs.isEmpty) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(child: Text('No comments in the last 24 hours.'));
          }

          return _buildCommentsList(docs);
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
        final author = _shortName((data['authorName'] ?? '').toString());
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
          subtitle: Text('$author - $date'),
          trailing: Text('#$articleId',
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
        );
      },
    );
  }
}


String _shortName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 'Vendor';
  final at = trimmed.indexOf('@');
  return at > 0 ? trimmed.substring(0, at) : trimmed;
}
