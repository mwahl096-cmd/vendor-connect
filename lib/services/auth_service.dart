import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/user_profile.dart';

class AuthService extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get user => _auth.currentUser;
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  Future<void> ensureProfile(User u, {
    required String name,
    required String businessName,
    required String phone,
  }) async {
    final doc = _db.collection(AppConfig.usersCollection).doc(u.uid);
    final snap = await doc.get();
    if (!snap.exists) {
      final profile = UserProfile(
        uid: u.uid,
        name: name,
        businessName: businessName,
        phone: phone,
        email: u.email ?? '',
        role: 'vendor',
        approved: false,
        disabled: false,
      );
      await doc.set(profile.toMap());
    }
  }

  Future<void> updateLastLogin() async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _db.collection(AppConfig.usersCollection).doc(u.uid).set({
      'lastLoginAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }
}
