import 'package:cloud_firestore/cloud_firestore.dart';

class ArticleComment {
  final String id;
  final String articleId;
  final String authorUid;
  final String authorName;
  final String text;
  final String visibleTo; // 'public' | 'private'
  final DateTime createdAt;

  ArticleComment({
    required this.id,
    required this.articleId,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.visibleTo,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'articleId': articleId,
    'authorUid': authorUid,
    'authorName': authorName,
    'text': text,
    'visibleTo': visibleTo,
    'createdAt': Timestamp.fromDate(createdAt.toUtc()),
    'createdAtClient': Timestamp.fromDate(createdAt.toUtc()),
  };

  static ArticleComment fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts =
        (data['createdAt'] as Timestamp?) ??
        (data['createdAtClient'] as Timestamp?);
    return ArticleComment(
      id: doc.id,
      articleId: (data['articleId'] ?? '') as String,
      authorUid: (data['authorUid'] ?? '') as String,
      authorName: (data['authorName'] ?? '') as String,
      text: (data['text'] ?? '') as String,
      visibleTo: (data['visibleTo'] ?? 'public') as String,
      createdAt: ts?.toDate().toLocal() ?? DateTime.now(),
    );
  }
}
