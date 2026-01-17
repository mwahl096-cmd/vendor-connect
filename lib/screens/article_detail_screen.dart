import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html/src/extension/helpers/image_extension.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/article.dart';
import '../models/comment.dart';
import '../services/firestore_service.dart';
import '../utils/role_utils.dart';

enum _CommentAction { report, reply, delete, block, unblock }

enum _ReplyDialogAction { save, remove }

class ArticleDetailScreen extends StatelessWidget {
  final String articleId;
  const ArticleDetailScreen({super.key, required this.articleId});

  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s<]+|www\.[^\s<]+|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})',
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
    if (RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(
      trimmed,
    )) {
      return trimmed;
    }
    if (trimmed.contains('@') &&
        !trimmed.contains(' ') &&
        !trimmed.contains('/')) {
      return 'mailto:$trimmed';
    }
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

  String _sanitizeFileName(String input) {
    final normalized =
        input
            .trim()
            .replaceAll(RegExp(r'\s+'), '_')
            .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
    return normalized.isEmpty ? 'comments_export' : normalized;
  }

  String _csvEscape(String value) {
    final raw = value;
    if (raw.contains('"') || raw.contains(',') || raw.contains('\n')) {
      return '"${raw.replaceAll('"', '""')}"';
    }
    return raw;
  }

  DateTime? _coerceDateTime(dynamic value) {
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

  Future<void> _exportCommentsCsv(
    BuildContext context, {
    required String articleId,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    var progressVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ).then((_) => progressVisible = false);

    try {
      final articleSnap =
          await FirebaseFirestore.instance
              .collection(AppConfig.articlesCollection)
              .doc(articleId)
              .get();
      final articleTitle =
          (articleSnap.data()?['title'] ?? '').toString().trim();

      final snap =
          await FirebaseFirestore.instance
              .collection(AppConfig.articlesCollection)
              .doc(articleId)
              .collection(AppConfig.commentsSubcollection)
              .get();

      final rows = snap.docs.map((doc) {
        final data = doc.data();
        final createdRaw = data['createdAt'] ?? data['createdAtClient'];
        final createdAt = _coerceDateTime(createdRaw);
        return {
          'commentId': doc.id,
          'articleId': data['articleId']?.toString() ?? articleId,
          'authorUid': data['authorUid']?.toString() ?? '',
          'authorName': data['authorName']?.toString() ?? '',
          'visibleTo': data['visibleTo']?.toString() ?? '',
          'createdAt': createdAt?.toIso8601String() ?? '',
          'text': data['text']?.toString() ?? '',
        };
      }).toList()
        ..sort((a, b) => (a['createdAt'] ?? '').compareTo(b['createdAt'] ?? ''));

      final header = [
        'commentId',
        'articleId',
        'authorUid',
        'authorName',
        'visibleTo',
        'createdAt',
        'text',
      ];
      final lines = <String>[header.join(',')];
      for (final row in rows) {
        lines.add(
          header.map((key) => _csvEscape(row[key] ?? '')).join(','),
        );
      }

      final label = articleTitle.isNotEmpty ? articleTitle : articleId;
      final safeTitle = _sanitizeFileName('comments_${articleId}_$label');
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$safeTitle.csv');
      await file.writeAsString(lines.join('\n'));

      if (progressVisible && context.mounted) {
        rootNavigator.pop();
      }

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv', name: '$safeTitle.csv')],
        text:
            articleTitle.isNotEmpty
                ? 'Comments export for "$articleTitle"'
                : 'Comments export for article $articleId',
      );
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Comments CSV saved to ${file.path}')),
      );
    } catch (e) {
      if (progressVisible && context.mounted) {
        rootNavigator.pop();
      }
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to export comments right now.')),
      );
    }
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
    final useNonBrowser =
        uri.scheme == 'mailto' ||
        uri.scheme == 'tel' ||
        uri.scheme == 'sms';
    var launched = await launchUrl(
      uri,
      mode:
          useNonBrowser
              ? LaunchMode.externalNonBrowserApplication
              : LaunchMode.externalApplication,
    );
    if (!launched && useNonBrowser) {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

  String _adminDisplayName(
    Map<String, dynamic>? userData,
    User? user,
  ) {
    final name = (userData?['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final displayName = (user?.displayName ?? '').toString().trim();
    if (displayName.isNotEmpty) return displayName;
    final email = (userData?['email'] ?? user?.email ?? '').toString().trim();
    if (email.contains('@')) return email.split('@').first;
    if (email.isNotEmpty) return email;
    return 'Admin';
  }

  Future<void> _promptAdminReply(
    BuildContext context, {
    required DocumentReference<Map<String, dynamic>> articleRef,
    required ArticleComment comment,
    required String adminUid,
    required String adminName,
  }) async {
    final controller = TextEditingController(text: comment.replyText ?? '');
    String? errorText;
    final action = await showDialog<_ReplyDialogAction>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                comment.replyText?.trim().isNotEmpty == true
                    ? 'Edit reply'
                    : 'Reply to comment',
              ),
              content: TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Write a reply...',
                  errorText: errorText,
                ),
              ),
              actions: [
                if (comment.replyText?.trim().isNotEmpty == true)
                  TextButton(
                    onPressed:
                        () => Navigator.of(
                          dialogContext,
                        ).pop(_ReplyDialogAction.remove),
                    child: const Text('Remove'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      setState(() => errorText = 'Reply required');
                      return;
                    }
                    Navigator.of(dialogContext).pop(_ReplyDialogAction.save);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    await Future<void>.delayed(Duration.zero);
    final replyText = controller.text.trim();
    controller.dispose();

    if (action == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final replyRef =
        articleRef.collection(AppConfig.commentsSubcollection).doc(comment.id);
    try {
      if (action == _ReplyDialogAction.save) {
        await replyRef.update({
          'replyText': replyText,
          'replyByUid': adminUid,
          'replyByName': adminName,
          'replyCreatedAt': FieldValue.serverTimestamp(),
          'replyCreatedAtClient': Timestamp.fromDate(DateTime.now().toUtc()),
        });
      } else if (action == _ReplyDialogAction.remove) {
        await replyRef.update({
          'replyText': FieldValue.delete(),
          'replyByUid': FieldValue.delete(),
          'replyByName': FieldValue.delete(),
          'replyCreatedAt': FieldValue.delete(),
          'replyCreatedAtClient': FieldValue.delete(),
        });
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to update reply.')),
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
        final currentUser = FirebaseAuth.instance.currentUser;
        final adminName = _adminDisplayName(userData, currentUser);

        Query<Map<String, dynamic>> commentsQuery = articleRef
            .collection(AppConfig.commentsSubcollection)
            .orderBy('createdAt', descending: true);
        final bool filterForPublic = !isAdmin;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Article'),
            actions: [
              if (isAdmin)
                IconButton(
                  tooltip: 'Export comments CSV',
                  icon: const Icon(Icons.download_outlined),
                  onPressed:
                      () =>
                          _exportCommentsCsv(context, articleId: articleId),
                ),
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

                          PopupMenuButton<_CommentAction> commentMenu(
                            ArticleComment comment,
                          ) {
                            final hasReply =
                                comment.replyText?.trim().isNotEmpty == true;
                            final canBlock =
                                uid != null && uid != comment.authorUid;
                            final isBlocked =
                                blockedUsers.contains(comment.authorUid);
                            return PopupMenuButton<_CommentAction>(
                              icon: const Icon(Icons.more_horiz),
                              tooltip: 'Comment actions',
                              onSelected: (action) async {
                                switch (action) {
                                  case _CommentAction.report:
                                    await _promptReport(
                                      context,
                                      articleId: article.id,
                                      comment: comment,
                                    );
                                    break;
                                  case _CommentAction.reply:
                                    if (!isAdmin || currentUser == null) {
                                      return;
                                    }
                                    await _promptAdminReply(
                                      context,
                                      articleRef: articleRef,
                                      comment: comment,
                                      adminUid: currentUser.uid,
                                      adminName: adminName,
                                    );
                                    break;
                                  case _CommentAction.delete:
                                    await _confirmDeleteComment(
                                      context,
                                      articleRef,
                                      comment,
                                    );
                                    break;
                                  case _CommentAction.block:
                                    await _setBlockStatus(
                                      context,
                                      targetUid: comment.authorUid,
                                      block: true,
                                    );
                                    break;
                                  case _CommentAction.unblock:
                                    await _setBlockStatus(
                                      context,
                                      targetUid: comment.authorUid,
                                      block: false,
                                    );
                                    break;
                                }
                              },
                              itemBuilder: (menuContext) {
                                final items =
                                    <PopupMenuEntry<_CommentAction>>[
                                      const PopupMenuItem(
                                        value: _CommentAction.report,
                                        child: Text('Report'),
                                      ),
                                    ];
                                if (isAdmin) {
                                  items.add(
                                    PopupMenuItem(
                                      value: _CommentAction.reply,
                                      child: Text(
                                        hasReply ? 'Edit reply' : 'Reply',
                                      ),
                                    ),
                                  );
                                }
                                if (canBlock) {
                                  items.add(
                                    PopupMenuItem(
                                      value:
                                          isBlocked
                                              ? _CommentAction.unblock
                                              : _CommentAction.block,
                                      child: Text(
                                        isBlocked
                                            ? 'Unblock user'
                                            : 'Block user',
                                      ),
                                    ),
                                  );
                                }
                                if (isAdmin) {
                                  items.add(
                                    const PopupMenuItem(
                                      value: _CommentAction.delete,
                                      child: Text(
                                        'Delete comment',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return items;
                              },
                            );
                          }

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
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: const Color(
                                            0xFF2BBFD4,
                                          ).withOpacity(0.15),
                                          foregroundColor: const Color(
                                            0xFF2BBFD4,
                                          ),
                                          child: Text(
                                            displayName(c.authorName)
                                                    .isNotEmpty
                                                ? displayName(
                                                  c.authorName,
                                                )[0].toUpperCase()
                                                : '?',
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          displayName(
                                                            c.authorName,
                                                          ),
                                                          softWrap: true,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          onlyDate(
                                                            c.createdAt,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .black54,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  commentMenu(c),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                c.text,
                                                softWrap: true,
                                                style: const TextStyle(
                                                  height: 1.35,
                                                ),
                                              ),
                                              if (c.replyText
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true) ...[
                                                const SizedBox(height: 10),
                                                Container(
                                                  width: double.infinity,
                                                  margin: const EdgeInsets.only(
                                                    left: 12,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.only(
                                                    left: 10,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                      left: BorderSide(
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade400,
                                                        width: 2,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              (c.replyByName ??
                                                                          'Admin')
                                                                      .trim()
                                                                      .isNotEmpty
                                                                  ? (c.replyByName ??
                                                                          'Admin')
                                                                      .trim()
                                                                  : 'Admin',
                                                              style:
                                                                  const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                            ),
                                                          ),
                                                          if (c.replyCreatedAt !=
                                                              null)
                                                            Text(
                                                              onlyDate(
                                                                c.replyCreatedAt!,
                                                              ),
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color: Colors
                                                                        .black54,
                                                                  ),
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        c.replyText ?? '',
                                                        softWrap: true,
                                                        style:
                                                            const TextStyle(
                                                          height: 1.35,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
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
