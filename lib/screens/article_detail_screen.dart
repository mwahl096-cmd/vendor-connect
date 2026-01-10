import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html/src/extension/helpers/image_extension.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/article.dart';
import '../models/comment.dart';
import '../services/firestore_service.dart';
import '../utils/role_utils.dart';

class ArticleDetailScreen extends StatelessWidget {
  final String articleId;
  const ArticleDetailScreen({super.key, required this.articleId});

  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s<]+|www\.[^\s<]+)',
    caseSensitive: false,
  );
  static const HtmlEscape _htmlEscape = HtmlEscape();

  String _decodeHtmlEntities(String input) {
    return input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#160;', ' ')
        .replaceAll('&#xA0;', ' ')
        .replaceAll('&#xa0;', ' ')
        .replaceAll('&#38;', '&')
        .replaceAll('&#038;', '&')
        .replaceAll('&#x26;', '&')
        .replaceAll('&amp;', '&');
  }

  String _normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  String _linkifyPlainText(String text) {
    final decoded = _decodeHtmlEntities(text);
    final buffer = StringBuffer();
    var lastIndex = 0;
    for (final match in _urlRegex.allMatches(decoded)) {
      if (match.start > lastIndex) {
        buffer.write(
          _htmlEscape.convert(decoded.substring(lastIndex, match.start)),
        );
      }
      final linkText = match.group(0)!;
      final href = _normalizeUrl(linkText);
      if (href.isEmpty) {
        buffer.write(_htmlEscape.convert(linkText));
      } else {
        buffer.write(
          '<a href="${_htmlEscape.convert(href)}">'
          '${_htmlEscape.convert(linkText)}'
          '</a>',
        );
      }
      lastIndex = match.end;
    }
    if (lastIndex < decoded.length) {
      buffer.write(_htmlEscape.convert(decoded.substring(lastIndex)));
    }
    return buffer.toString().replaceAll('\n', '<br />');
  }

  Future<void> _openUrl(BuildContext context, String? rawUrl) async {
    final messenger = ScaffoldMessenger.of(context);
    final normalized = _normalizeUrl(rawUrl ?? '');
    if (normalized.isEmpty) return;
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Invalid link.')),
      );
      return;
    }
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to open link.')),
      );
    }
  }

  Future<void> _submitReport(
    BuildContext context, {
    required String articleId,
    ArticleComment? comment,
    Article? article,
    required String description,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final messenger = ScaffoldMessenger.of(context);
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please sign in to report content.')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection(AppConfig.reportsCollection)
          .add({
            'articleId': articleId,
            'commentId': comment?.id,
            'targetType': comment != null ? 'comment' : 'article',
            'targetPreview': (comment?.text ?? article?.title ?? '').trim(),
            'reporterUid': user.uid,
            'reporterEmail': user.email,
            'message': description.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Thanks for the report - our team will review it.'),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Unable to submit report. Please try again later.'),
        ),
      );
    }
  }

  Future<void> _promptReport(
    BuildContext context, {
    required String articleId,
    ArticleComment? comment,
    Article? article,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(comment != null ? 'Report comment' : 'Report article'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Describe what is wrong with this ${comment != null ? 'comment' : 'article'}.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Provide details (required)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    if (result == null || result.trim().isEmpty) return;
    await _submitReport(
      context,
      articleId: articleId,
      comment: comment,
      article: article,
      description: result,
    );
  }

  Future<void> _confirmDeleteComment(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> articleRef,
    ArticleComment comment,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
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
      messenger.showSnackBar(const SnackBar(content: Text('Comment deleted')));
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to delete comment, try again.')),
      );
    }
  }

  Set<String> _blockedUserIds(Map<String, dynamic>? data) {
    if (data == null) return <String>{};
    final raw = data['blockedUserIds'];
    if (raw is Iterable) {
      return raw
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    }
    return <String>{};
  }

  Future<void> _setBlockStatus(
    BuildContext context, {
    required String targetUid,
    required bool block,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || targetUid.isEmpty || user.uid == targetUid) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection(AppConfig.usersCollection)
          .doc(user.uid)
          .set({
            'blockedUserIds':
                block
                    ? FieldValue.arrayUnion([targetUid])
                    : FieldValue.arrayRemove([targetUid]),
          }, SetOptions(merge: true));
      messenger.showSnackBar(
        SnackBar(content: Text(block ? 'User blocked' : 'User unblocked')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Unable to update blocked users. Please try again.'),
        ),
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
        final userData = userSnap.data?.data();
        final roleRaw = normalizedRole(userData);
        final isAdmin = roleRaw == 'admin';
        final blockedUsers = _blockedUserIds(userData);

        Query<Map<String, dynamic>> commentsQuery = articleRef
            .collection(AppConfig.commentsSubcollection)
            .orderBy('createdAt', descending: true);
        final bool filterForPublic = !isAdmin;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Article'),
            actions: [
              IconButton(
                tooltip: 'Report article',
                icon: const Icon(Icons.flag_outlined),
                onPressed: () => _promptReport(context, articleId: articleId),
              ),
            ],
          ),
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

              final bool hideCommentsForViewer =
                  !isAdmin && article.commentsVisibility == 'private';

              if (uid != null) {
                FirestoreService().markArticleRead(
                  uid: uid,
                  articleId: article.id,
                );
              }

              final hasHtml = article.contentHtml.trim().isNotEmpty;
              String cleanedHtml(String html) {
                return html
                    .replaceAll(
                      RegExp(
                        r'<p>(?:&nbsp;|\s|<br\s*/?>)*</p>',
                        caseSensitive: false,
                      ),
                      '',
                    )
                    .trim();
              }
              final htmlBody =
                  hasHtml ? cleanedHtml(article.contentHtml) : article.excerpt;
              final useHtml = hasHtml && htmlBody.isNotEmpty;
              final plainTextHtml = _linkifyPlainText(htmlBody);
              final bodyFontSize =
                  Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14;
              final htmlStyles = {
                'body': Style(
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                  fontSize: FontSize(bodyFontSize),
                  lineHeight: LineHeight.number(1.4),
                  color: Colors.black87,
                ),
                'p': Style(
                  margin: Margins.only(bottom: 12),
                ),
                'a': Style(
                  color: Colors.blue.shade700,
                  textDecoration: TextDecoration.underline,
                ),
                'img': Style(
                  margin: Margins.zero,
                  display: Display.block,
                ),
                'figure': Style(
                  margin: Margins.only(bottom: 12),
                ),
                'figcaption': Style(
                  color: Colors.black54,
                  fontSize: FontSize(12),
                ),
              };

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
                  if (useHtml)
                    LayoutBuilder(
                      builder: (layoutContext, constraints) {
                        final maxWidth =
                            constraints.maxWidth.isFinite &&
                                    constraints.maxWidth > 0
                                ? constraints.maxWidth
                                : null;
                        return Html(
                          data: htmlBody,
                          onLinkTap:
                              (url, attributes, element) =>
                                  _openUrl(context, url),
                          extensions: [
                            ImageExtension(
                              builder: (context) {
                                final src =
                                    context.attributes['src']?.trim() ?? '';
                                if (src.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 12,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      height: 220,
                                      width: maxWidth,
                                      child: Image.network(
                                        src,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) => Container(
                                              color: Colors.grey.shade200,
                                            ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                          style: htmlStyles,
                        );
                      },
                    )
                  else
                    Html(
                      data: plainTextHtml,
                      onLinkTap:
                          (url, attributes, element) =>
                              _openUrl(context, url),
                      style: htmlStyles,
                    ),
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
                    if (hideCommentsForViewer) ...[
                      const Text(
                        'Comments are visible to administrators only.',
                      ),
                      const SizedBox(height: 8),
                      _NewCommentBox(articleId: article.id, isPrivate: true),
                    ] else ...[
                      _NewCommentBox(
                        articleId: article.id,
                        isPrivate: article.commentsVisibility == 'private',
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
                            items.removeWhere((c) {
                              if (uid != null && c.authorUid == uid) {
                                return false;
                              }
                              return c.visibleTo != 'public';
                            });
                          }
                          if (blockedUsers.isNotEmpty) {
                            items.removeWhere(
                              (c) => blockedUsers.contains(c.authorUid),
                            );
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

                          String displayName(String raw) {
                            final name = raw.trim();
                            if (name.contains(' ')) return name;
                            if (name.contains('@'))
                              return name.split('@').first;
                            return name.isEmpty ? 'Vendor' : name;
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
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(
                                          0xFF2BBFD4,
                                        ).withOpacity(0.15),
                                        foregroundColor: const Color(
                                          0xFF2BBFD4,
                                        ),
                                        child: Text(
                                          displayName(c.authorName).isNotEmpty
                                              ? displayName(
                                                c.authorName,
                                              )[0].toUpperCase()
                                              : '?',
                                        ),
                                      ),
                                      title: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName(c.authorName),
                                            softWrap: true,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
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
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Report comment',
                                            icon: const Icon(
                                              Icons.flag_outlined,
                                            ),
                                            onPressed:
                                                () => _promptReport(
                                                  context,
                                                  articleId: article.id,
                                                  comment: c,
                                                ),
                                          ),
                                          if (isAdmin)
                                            IconButton(
                                              tooltip: 'Delete comment',
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.redAccent,
                                              ),
                                              onPressed:
                                                  () => _confirmDeleteComment(
                                                    context,
                                                    articleRef,
                                                    c,
                                                  ),
                                            ),
                                          if (uid != null && uid != c.authorUid)
                                            PopupMenuButton<String>(
                                              tooltip:
                                                  blockedUsers.contains(
                                                        c.authorUid,
                                                      )
                                                      ? 'Unblock user'
                                                      : 'Block user',
                                              onSelected: (value) {
                                                if (value == 'block') {
                                                  _setBlockStatus(
                                                    context,
                                                    targetUid: c.authorUid,
                                                    block: true,
                                                  );
                                                } else if (value == 'unblock') {
                                                  _setBlockStatus(
                                                    context,
                                                    targetUid: c.authorUid,
                                                    block: false,
                                                  );
                                                }
                                              },
                                              itemBuilder:
                                                  (_) => [
                                                    if (!blockedUsers.contains(
                                                      c.authorUid,
                                                    ))
                                                      const PopupMenuItem(
                                                        value: 'block',
                                                        child: Text(
                                                          'Block user',
                                                        ),
                                                      )
                                                    else
                                                      const PopupMenuItem(
                                                        value: 'unblock',
                                                        child: Text(
                                                          'Unblock user',
                                                        ),
                                                      ),
                                                  ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
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
  final bool isPrivate;
  const _NewCommentBox({required this.articleId, required this.isPrivate});

  @override
  State<_NewCommentBox> createState() => _NewCommentBoxState();
}

class _NewCommentBoxState extends State<_NewCommentBox> {
  final _controller = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (AppConfig.containsProhibitedLanguage(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please remove offensive or inappropriate language before posting.',
          ),
        ),
      );
      return;
    }
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

    String authorName = (user.displayName ?? user.email ?? 'Vendor').trim();
    try {
      final profileSnap =
          await FirebaseFirestore.instance
              .collection(AppConfig.usersCollection)
              .doc(user.uid)
              .get();
      final profileName = (profileSnap.data()?['name'] ?? '').toString().trim();
      if (profileName.isNotEmpty) {
        authorName = profileName;
      }
    } catch (_) {}

    await doc.set({
      'articleId': widget.articleId,
      'authorUid': user.uid,
      'authorName': authorName,
      'text': text,
      'visibleTo': widget.isPrivate ? 'private' : 'public',
      'createdAtClient': Timestamp.fromDate(DateTime.now().toUtc()),
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
      ],
    );
  }
}
