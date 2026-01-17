import 'package:cloud_firestore/cloud_firestore.dart';

class ArticleComment {
  final String id;
  final String articleId;
  final String authorUid;
  final String authorName;
  final String text;
  final String visibleTo; // 'public' | 'private'
  final DateTime createdAt;
  final String? replyText;
  final String? replyByUid;
  final String? replyByName;
  final DateTime? replyCreatedAt;

  ArticleComment({
    required this.id,
    required this.articleId,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.visibleTo,
    required this.createdAt,
    this.replyText,
    this.replyByUid,
    this.replyByName,
    this.replyCreatedAt,
  });

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'articleId': articleId,
      'authorUid': authorUid,
      'authorName': authorName,
      'text': text,
      'visibleTo': visibleTo,
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),
      'createdAtClient': Timestamp.fromDate(createdAt.toUtc()),
    };
    if (replyText != null) {
      data['replyText'] = replyText;
    }
    if (replyByUid != null) {
      data['replyByUid'] = replyByUid;
    }
    if (replyByName != null) {
      data['replyByName'] = replyByName;
    }
    if (replyCreatedAt != null) {
      data['replyCreatedAt'] = Timestamp.fromDate(replyCreatedAt!.toUtc());
      data['replyCreatedAtClient'] = Timestamp.fromDate(
        replyCreatedAt!.toUtc(),
      );
    }
    return data;
  }

  static ArticleComment fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts =
        (data['createdAt'] as Timestamp?) ??
        (data['createdAtClient'] as Timestamp?);
    final replyTs =
        (data['replyCreatedAt'] as Timestamp?) ??
        (data['replyCreatedAtClient'] as Timestamp?);
    return ArticleComment(
      id: doc.id,
      articleId: (data['articleId'] ?? '') as String,
      authorUid: (data['authorUid'] ?? '') as String,
      authorName: (data['authorName'] ?? '') as String,
      text: (data['text'] ?? '') as String,
      visibleTo: (data['visibleTo'] ?? 'public') as String,
      createdAt: ts?.toDate().toLocal() ?? DateTime.now(),
      replyText: (data['replyText'] ?? '').toString().trim().isNotEmpty
          ? (data['replyText'] ?? '').toString()
          : null,
      replyByUid: (data['replyByUid'] ?? '').toString().trim().isNotEmpty
          ? (data['replyByUid'] ?? '').toString()
          : null,
      replyByName: (data['replyByName'] ?? '').toString().trim().isNotEmpty
          ? (data['replyByName'] ?? '').toString()
          : null,
      replyCreatedAt: replyTs?.toDate().toLocal(),
    );
  }
}
