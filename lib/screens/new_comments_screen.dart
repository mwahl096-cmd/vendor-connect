import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  static const int _maxResults = 300;

  late final Query<Map<String, dynamic>> _baseQuery;
  late final Future<bool> _isAdminFuture;
  Timer? _refreshTicker;

  @override
  void initState() {
    super.initState();
    _baseQuery = FirebaseFirestore.instance
        .collectionGroup(AppConfig.commentsSubcollection)
        .limit(_maxResults);
    _isAdminFuture = _checkIsAdmin(FirebaseAuth.instance.currentUser);
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

    return Scaffold(
      appBar: AppBar(title: const Text('New Comments (24h)')),
      body: FutureBuilder<bool>(
        future: _isAdminFuture,
        builder: (context, adminSnap) {
          if (adminSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (adminSnap.data != true) {
            return const Center(
              child: Text(
                'You do not have permission to view this screen.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _baseQuery.snapshots(includeMetadataChanges: true),
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
                          data['createdAtClient'] ?? data['createdAt'];
                      if ((raw == null || raw is FieldValue) &&
                          doc.metadata.hasPendingWrites) {
                        return true;
                      }
                      return isWithinWindow(raw, _window, reference: reference);
                    }).toList()
                    ..sort((a, b) {
                      final dynamic aRaw =
                          a.data()['createdAtClient'] ?? a.data()['createdAt'];
                      final dynamic bRaw =
                          b.data()['createdAtClient'] ?? b.data()['createdAt'];
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
          );
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
        final dynamic raw = data['createdAtClient'] ?? data['createdAt'];
        final timestamp = _toComparableDateTime(raw);
        final dateLabel =
            timestamp != null
                ? '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
                    '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
                : (doc.metadata.hasPendingWrites ? 'just now' : 'Unknown time');
        final articleId = (data['articleId'] ?? '').toString();
        return ListTile(
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

Future<bool> _checkIsAdmin(User? user) async {
  if (user == null) return false;
  try {
    final doc =
        await FirebaseFirestore.instance
            .collection(AppConfig.usersCollection)
            .doc(user.uid)
            .get();
    final role = (doc.data()?['role'] ?? '').toString().toLowerCase();
    return role == 'admin';
  } catch (_) {
    return false;
  }
}

String _shortName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 'Vendor';
  final at = trimmed.indexOf('@');
  return at > 0 ? trimmed.substring(0, at) : trimmed;
}
