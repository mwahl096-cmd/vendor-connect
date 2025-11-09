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

  Future<void> ensureProfile(
    User u, {
    required String name,
    required String businessName,
    String? phone,
    String? username,
  }) async {
    final doc = _db.collection(AppConfig.usersCollection).doc(u.uid);
    final snap = await doc.get();
    final resolvedUsername = _deriveInitialUsername(
      user: u,
      name: name,
      provided: username,
    );
    if (!snap.exists) {
      final profile = UserProfile(
        uid: u.uid,
        name: name,
        username: resolvedUsername,
        businessName: businessName,
        phone: (phone ?? '').trim(),
        email: u.email ?? '',
        role: 'vendor',
        approved: false,
        disabled: false,
      );
      await doc.set(profile.toMap());
    } else {
      final data = snap.data();
      final existingUsername =
          data != null ? (data['username'] as String? ?? '') : '';
      if (existingUsername.trim().isEmpty && resolvedUsername.isNotEmpty) {
        await doc.set({'username': resolvedUsername}, SetOptions(merge: true));
      }
    }
  }

  Future<void> updateProfile({
    required String name,
    required String businessName,
    required String phone,
    required String username,
  }) async {
    final u = _auth.currentUser;
    if (u == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'You must be signed in to update your profile.',
      );
    }
    final trimmedName = name.trim();
    final trimmedBusiness = businessName.trim();
    final trimmedPhone = phone.trim();
    final trimmedUsername = username.trim();
    final doc = _db.collection(AppConfig.usersCollection).doc(u.uid);
    await doc.set({
      'name': trimmedName,
      'businessName': trimmedBusiness,
      'phone': trimmedPhone,
      'username': trimmedUsername,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    try {
      await u.updateDisplayName(trimmedName);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updateLastLogin() async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _db.collection(AppConfig.usersCollection).doc(u.uid).set({
      'lastLoginAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }

  String _deriveInitialUsername({
    required User user,
    required String name,
    String? provided,
  }) {
    final candidate = provided?.trim();
    if (candidate != null && candidate.isNotEmpty) return candidate;

    final email = user.email;
    if (email != null && email.contains('@')) {
      final emailPart = email.split('@').first.trim();
      if (emailPart.isNotEmpty) return emailPart;
    }

    final namePart = name.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '',
    );
    if (namePart.isNotEmpty) return namePart;

    return user.uid.isNotEmpty ? user.uid : 'user';
  }
}
