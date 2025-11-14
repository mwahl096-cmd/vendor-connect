import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../utils/time_utils.dart';
import 'article_detail_screen.dart';

class NewCommentsScreen extends StatefulWidget {
  const NewCommentsScreen({super.key});

  @override
  State<NewCommentsScreen> createState() => _NewCommentsScreenState();
}

class _NewCommentsScreenState extends State<NewCommentsScreen> {
  static const Duration _window = Duration(hours: 24);
  static const int _maxResults = 300;

  Timer? _refreshTicker;

  @override
  void initState() {
    super.initState();
    _refreshTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reference = DateTime.now();
    final cutoffTimestamp = Timestamp.fromDate(
      DateTime.now().toUtc().subtract(_window),
    );
    final query = FirebaseFirestore.instance
        .collectionGroup(AppConfig.commentsSubcollection)
        .where('createdAtClient', isGreaterThanOrEqualTo: cutoffTimestamp)
        .orderBy('createdAtClient', descending: true)
        .limit(_maxResults);

    return Scaffold(
      appBar: AppBar(title: const Text('New Comments (24h)')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(includeMetadataChanges: true),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'Could not load comments.\n${snap.error}',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            );
          }

          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs =
              snap.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          final filtered =
              docs.where((doc) {
                  final data = doc.data();
                  final dynamic raw =
                      data['createdAt'] ?? data['createdAtClient'];
                  if ((raw == null || raw is FieldValue) &&
                      doc.metadata.hasPendingWrites) {
                    return true;
                  }
                  return isWithinWindow(raw, _window, reference: reference);
                }).toList()
                ..sort((a, b) {
                  final dynamic aRaw =
                      a.data()['createdAt'] ?? a.data()['createdAtClient'];
                  final dynamic bRaw =
                      b.data()['createdAt'] ?? b.data()['createdAtClient'];
                  final aTime =
                      _toComparableDateTime(aRaw) ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime =
                      _toComparableDateTime(bRaw) ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                });

          if (filtered.isEmpty) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(
              child: Text('No comments in the last 24 hours.'),
            );
          }

          return _buildCommentsList(filtered);
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
        final doc = comments[i];
        final data = doc.data();
        final text = (data['text'] ?? '').toString();
        final author = _shortName((data['authorName'] ?? '').toString());
        final dynamic raw = data['createdAt'] ?? data['createdAtClient'];
        final timestamp = _toComparableDateTime(raw);
        final dateLabel =
            timestamp != null
                ? '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
                    '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
                : (doc.metadata.hasPendingWrites ? 'just now' : 'Unknown time');
        final articleId = (data['articleId'] ?? '').toString().trim();
        return ListTile(
          onTap:
              articleId.isEmpty ? null : () => _openArticle(context, articleId),
          title: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('$author • $dateLabel'),
          trailing: Text(
            '#$articleId',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        );
      },
    );
  }
}

DateTime? _toComparableDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate().toLocal();
  if (value is DateTime) return value.toLocal();
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  if (value is num) {
    final millis =
        value > 10000000000 ? value.toDouble() : value.toDouble() * 1000;
    return DateTime.fromMillisecondsSinceEpoch(
      millis.round(),
      isUtc: true,
    ).toLocal();
  }
  return null;
}

String _shortName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 'Vendor';
  final at = trimmed.indexOf('@');
  return at > 0 ? trimmed.substring(0, at) : trimmed;
}

void _openArticle(BuildContext context, String articleId) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ArticleDetailScreen(articleId: articleId),
    ),
  );
}
