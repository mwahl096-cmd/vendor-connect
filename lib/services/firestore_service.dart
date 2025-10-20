import 'package:cloud_firestore/cloud_firestore.dart';

import '../config.dart';
import '../models/article.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Article>> watchArticles() {
    return _db
        .collection(AppConfig.articlesCollection)
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map(
          (s) =>
              s.docs
                  .map(Article.fromDoc)
                  .where((article) => article.shouldDisplay)
                  .toList(),
        );
  }

  Future<Article?> getArticle(String id) async {
    final snap =
        await _db.collection(AppConfig.articlesCollection).doc(id).get();
    if (!snap.exists) return null;
    return Article.fromDoc(snap);
  }

  Future<void> markArticleRead({
    required String uid,
    required String articleId,
  }) async {
    final doc = _db
        .collection(AppConfig.readsCollection)
        .doc('$uid-$articleId');
    await doc.set({
      'uid': uid,
      'articleId': articleId,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<int> watchUnreadCount(String uid) {
    final articles = _db.collection(AppConfig.articlesCollection);
    final reads = _db
        .collection(AppConfig.readsCollection)
        .where('uid', isEqualTo: uid);
    // Naive client-side combine: stream counts; for scale consider Cloud Function aggregation
    return articles.snapshots().asyncMap((aSnap) async {
      final publishedArticles =
          aSnap.docs
              .map(Article.fromDoc)
              .where((article) => article.shouldDisplay)
              .toList();
      final rSnap = await reads.get();
      final readIds =
          rSnap.docs.map((d) => (d.data()['articleId'] as String)).toSet();
      final unread =
          publishedArticles
              .where((article) => !readIds.contains(article.id))
              .length;
      return unread;
    });
  }
}
