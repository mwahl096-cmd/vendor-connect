import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config.dart';

/// Handles GDPR/CCPA-style account deletion flows for end users.
class AccountService {
  AccountService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// Deletes the currently authenticated account and associated Firestore data.
  ///
  /// [password] is required when the primary sign-in method is email/password,
  /// allowing the method to reauthenticate before invoking deletion.
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'You must be signed in to delete your account.',
      );
    }

    final requiresPassword = user.providerData.any(
      (info) => info.providerId == 'password',
    );
    final trimmedPassword = password?.trim() ?? '';
    if (requiresPassword && trimmedPassword.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-password',
        message: 'Please confirm your password to delete the account.',
      );
    }

    if (trimmedPassword.isNotEmpty && user.email?.isNotEmpty == true) {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: trimmedPassword,
      );
      await user.reauthenticateWithCredential(credential);
    }

    try {
      final callable = _functions.httpsCallable(
        'selfDeleteAccount',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      await callable.call(<String, dynamic>{});
    } on FirebaseFunctionsException catch (e) {
      if (e.code != 'unimplemented' && e.code != 'unavailable') {
        rethrow;
      }
      await _deleteAccountLocally(user);
      return;
    }

    await _safeSignOut();
  }

  Future<void> _deleteAccountLocally(User user) async {
    final uid = user.uid;

    Future<void> deleteQuery(Query<Map<String, dynamic>> query) async {
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) return;
      const batchSize = 400;
      for (var i = 0; i < snapshot.docs.length; i += batchSize) {
        final slice = snapshot.docs.skip(i).take(batchSize);
        final batch = _firestore.batch();
        for (final doc in slice) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    try {
      await _firestore.collection(AppConfig.usersCollection).doc(uid).delete();
    } catch (_) {}

    try {
      await deleteQuery(
        _firestore
            .collection(AppConfig.readsCollection)
            .where('uid', isEqualTo: uid),
      );
    } catch (_) {}

    try {
      await deleteQuery(
        _firestore.collection('fcmTokens').where('uid', isEqualTo: uid),
      );
    } catch (_) {}

    try {
      await deleteQuery(
        _firestore
            .collectionGroup(AppConfig.commentsSubcollection)
            .where('authorUid', isEqualTo: uid),
      );
    } catch (_) {}

    await user.delete();
    await _safeSignOut();
  }

  Future<void> _safeSignOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
  }
}
