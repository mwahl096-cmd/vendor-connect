import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../models/article.dart';
import '../models/comment.dart';
import '../services/firestore_service.dart';

class ArticleDetailScreen extends StatelessWidget {
  final String articleId;
  const ArticleDetailScreen({super.key, required this.articleId});

  Future<void> _confirmDeleteComment(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> articleRef,
    ArticleComment comment,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete comment?'),
        content: Text('This will remove "${comment.text}" permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await articleRef
          .collection(AppConfig.commentsSubcollection)
          .doc(comment.id)
          .delete();
      messenger.showSnackBar(
        const SnackBar(content: Text('Comment deleted')),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to delete comment, try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final articleRef = FirebaseFirestore.instance
        .collection(AppConfig.articlesCollection)
        .doc(articleId);
    final Stream<DocumentSnapshot<Map<String, dynamic>>> userStream =
        uid != null
            ? FirebaseFirestore.instance
                .collection(AppConfig.usersCollection)
                .doc(uid)
                .snapshots()
            : const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,
      builder: (context, userSnap) {
        if (uid != null &&
            userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final roleRaw = userSnap.data?.data()?['role']?.toString() ?? 'vendor';
        final isAdmin = roleRaw.toLowerCase().trim() == 'admin';

        Query<Map<String, dynamic>> commentsQuery = articleRef.collection(
          AppConfig.commentsSubcollection,
        );
        final bool filterForPublic = !isAdmin;
        if (isAdmin) {
          commentsQuery = commentsQuery.orderBy('createdAt', descending: true);
        } else {
          commentsQuery = commentsQuery.where('visibleTo', isEqualTo: 'public');
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(title: const Text('Article')),
          body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: articleRef.snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(child: Text('Error loading article'));
              }
              if (!snap.hasData ||
                  snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snap.data!.exists) {
                return const Center(child: Text('Not found'));
              }

              Article article;
              try {
                article = Article.fromDoc(snap.data!);
              } catch (_) {
                return const Center(child: Text('Invalid article data'));
              }

              if (!isAdmin && !article.shouldDisplay) {
                return const Center(child: Text('Article not available'));
              }

              if (uid != null) {
                FirestoreService().markArticleRead(
                  uid: uid,
                  articleId: article.id,
                );
              }

              String plain(String html) =>
                  html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
              final bodyText =
                  article.contentHtml.trim().isNotEmpty
                      ? plain(article.contentHtml)
                      : article.excerpt;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child:
                          (article.featuredImageUrl != null &&
                                  article.featuredImageUrl!.isNotEmpty)
                              ? Image.network(
                                article.featuredImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) =>
                                        Container(color: Colors.grey.shade200),
                              )
                              : Container(color: Colors.grey.shade200),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    article.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${article.publishedAt.toLocal()}')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (article.categories.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: -6,
                      children: [
                        ...article.categories.map(
                          (c) => Chip(
                            label: Text(c),
                            backgroundColor: Colors.grey.shade100,
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(bodyText, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  if (article.tags.isNotEmpty) ...[
                    Text(
                      'Tags',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: -6,
                      children: [
                        ...article.tags.map(
                          (t) => Chip(
                            label: Text('#$t'),
                            backgroundColor: Colors.grey.shade100,
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      'No tags',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (article.allowComments) ...[
                    Row(
                      children: const [
                        Icon(Icons.chat_bubble_outline),
                        SizedBox(width: 8),
                        Text('Comments'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _NewCommentBox(
                      articleId: article.id,
                      visibility: article.commentsVisibility,
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: commentsQuery.snapshots(),
                      builder: (context, cSnap) {
                        if (!cSnap.hasData || cSnap.data == null) {
                          if (cSnap.hasError) {
                            final err = cSnap.error;
                            if (err is FirebaseException &&
                                err.code == 'permission-denied') {
                              return const Text(
                                'Comments are not available for your role yet.',
                              );
                            }
                            return const Text('Unable to load comments');
                          }
                          if (cSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }

                        if (cSnap.hasError) {
                          debugPrint('Comment stream error: ${cSnap.error}');
                        }

                        final snapshot = cSnap.data!;
                        final items =
                            snapshot.docs
                                .map((d) => ArticleComment.fromDoc(d))
                                .toList();
                        if (filterForPublic) {
                          items.removeWhere((c) => c.visibleTo != 'public');
                        }
                        items.sort(
                          (a, b) => b.createdAt.compareTo(a.createdAt),
                        );
                        if (items.isEmpty) {
                          if (snapshot.metadata.isFromCache) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          return const Text('No comments yet');
                        }

                        String displayName(String s) {
                          final at = s.indexOf('@');
                          return at > 0 ? s.substring(0, at) : s;
                        }

                        String onlyDate(DateTime d) =>
                            d.toLocal().toString().split(' ').first;

                        return Column(
                          children: [
                            for (final c in items)
                              Card(
                                elevation: 0,
                                color: Colors.grey.shade100,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(
                                        0xFF2BBFD4,
                                      ).withOpacity(0.15),
                                      foregroundColor: const Color(0xFF2BBFD4),
                                      child: Text(
                                        displayName(c.authorName).isNotEmpty
                                            ? displayName(
                                              c.authorName,
                                            )[0].toUpperCase()
                                            : '?',
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displayName(c.authorName),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          onlyDate(c.createdAt),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(c.text),
                                    ),
                                    trailing: isAdmin
                                        ? IconButton(
                                            tooltip: 'Delete comment',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.redAccent,
                                            ),
                                            onPressed: () => _confirmDeleteComment(
                                              context,
                                              articleRef,
                                              c,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _NewCommentBox extends StatefulWidget {
  final String articleId;
  final String visibility; // 'public' | 'private'
  const _NewCommentBox({required this.articleId, required this.visibility});

  @override
  State<_NewCommentBox> createState() => _NewCommentBoxState();
}

class _NewCommentBoxState extends State<_NewCommentBox> {
  final _controller = TextEditingController();
  bool _privateToAdmin = false;
  bool _sending = false;

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to comment.')),
        );
        setState(() => _sending = false);
      }
      return;
    }
    final doc =
        FirebaseFirestore.instance
            .collection(AppConfig.articlesCollection)
            .doc(widget.articleId)
            .collection(AppConfig.commentsSubcollection)
            .doc();
    await doc.set({
      'articleId': widget.articleId,
      'authorUid': user.uid,
      'authorName': user.email ?? 'Vendor',
      'text': _controller.text.trim(),
      'visibleTo': _privateToAdmin ? 'private' : 'public',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      _controller.clear();
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Write a comment...',
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send),
                label: const Text('Send'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(110, 48),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: _privateToAdmin,
              onChanged: (v) => setState(() => _privateToAdmin = v ?? false),
            ),
            const Expanded(child: Text('Just me (private to admin)')),
          ],
        ),
      ],
    );
  }
}
