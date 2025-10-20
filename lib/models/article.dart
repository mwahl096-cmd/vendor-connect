import 'package:cloud_firestore/cloud_firestore.dart';

class Article {
  final String id; // Firestore doc id (often WP id as string)
  final int wpId;
  final String title;
  final String contentHtml;
  final String excerpt;
  final String status;
  final List<String> categories;
  final List<String> tags;
  final String? featuredImageUrl;
  final bool allowComments;
  final String commentsVisibility; // 'public' | 'private'
  final DateTime publishedAt;

  Article({
    required this.id,
    required this.wpId,
    required this.title,
    required this.contentHtml,
    required this.excerpt,
    required this.categories,
    required this.status,
    required this.tags,
    required this.featuredImageUrl,
    required this.allowComments,
    required this.commentsVisibility,
    required this.publishedAt,
  });

  bool get isPublished => status.toLowerCase() == 'publish';

  Map<String, dynamic> toMap() => {
    'wpId': wpId,
    'title': title,
    'contentHtml': contentHtml,
    'excerpt': excerpt,
    'status': status,
    'categories': categories,
    'tags': tags,
    'featuredImageUrl': featuredImageUrl,
    'allowComments': allowComments,
    'commentsVisibility': commentsVisibility,
    'publishedAt': Timestamp.fromDate(publishedAt),
  };

  static Article fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final wpIdRaw = data['wpId'];
    int resolveWpId() {
      if (wpIdRaw is int) return wpIdRaw;
      if (wpIdRaw is double) return wpIdRaw.round();
      if (wpIdRaw is num) return wpIdRaw.toInt();
      if (wpIdRaw is String) {
        final parsed = int.tryParse(wpIdRaw);
        if (parsed != null) return parsed;
      }
      return 0;
    }

    final allowCommentsRaw = data['allowComments'];
    bool resolveAllowComments() {
      if (allowCommentsRaw is bool) return allowCommentsRaw;
      if (allowCommentsRaw is num) return allowCommentsRaw != 0;
      if (allowCommentsRaw is String) {
        final normalized = allowCommentsRaw.toLowerCase().trim();
        if (normalized.isEmpty) return true;
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
      }
      return true;
    }

    final commentsVisibilityRaw = data['commentsVisibility'];
    final resolvedVisibility =
        (commentsVisibilityRaw is String
                ? commentsVisibilityRaw
                : commentsVisibilityRaw?.toString() ?? 'public')
            .toLowerCase()
            .trim();

    DateTime resolvePublishedAt() {
      final published = data['publishedAt'];
      if (published is Timestamp) return published.toDate();
      if (published is DateTime) return published;
      if (published is String) {
        final parsed = DateTime.tryParse(published);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    List<String> mapStrings(dynamic raw) {
      if (raw is Iterable) {
        return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

    return Article(
      id: doc.id,
      wpId: resolveWpId(),
      title: (data['title'] ?? '') as String,
      contentHtml: (data['contentHtml'] ?? '') as String,
      excerpt: (data['excerpt'] ?? '') as String,
      status:
          (() {
            final raw =
                data['status'] ??
                data['wpStatus'] ??
                data['postStatus'] ??
                data['state'] ??
                data['post_status'];
            final status = (raw ?? '').toString().trim();
            return status.isEmpty ? 'publish' : status;
          })(),
      categories: mapStrings(data['categories']),
      tags: mapStrings(data['tags']),
      featuredImageUrl: (data['featuredImageUrl'] as String?),
      allowComments: resolveAllowComments(),
      commentsVisibility:
          resolvedVisibility.isEmpty ? 'public' : resolvedVisibility,
      publishedAt: resolvePublishedAt(),
    );
  }
}

extension ArticleVisibility on Article {
  bool get shouldDisplay {
    final normalizedTitle = title
        .trim()
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll('_', ' ');
    final blockedTitle =
        normalizedTitle == 'auto draft' ||
        normalizedTitle.startsWith('auto draft') ||
        normalizedTitle == 'draft';
    return isPublished && !blockedTitle;
  }
}
