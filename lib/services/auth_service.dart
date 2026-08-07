import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/user_profile.dart';

class AuthService extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

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

  Future<bool> recoverExistingVendorRegistration({
    required String email,
    required String name,
    String? firstName,
    String? lastName,
    required String businessName,
    String? phone,
  }) async {
    final callable = _functions.httpsCallable(
      'recoverExistingVendorRegistration',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final result = await callable.call(<String, dynamic>{
      'email': email.trim(),
      'name': name.trim(),
      'firstName': (firstName ?? '').trim(),
      'lastName': (lastName ?? '').trim(),
      'businessName': businessName.trim(),
      'phone': (phone ?? '').trim(),
    });
    final data = result.data;
    if (data is Map) {
      return data['recovered'] == true || data['profileExists'] == true;
    }
    return false;
  }

  Future<void> ensureProfile(
    User u, {
    required String name,
    String? firstName,
    String? lastName,
    required String businessName,
    String? phone,
    String? username,
  }) async {
    final doc = _db.collection(AppConfig.usersCollection).doc(u.uid);
    final snap = await doc.get();
    final trimmedFirstName = (firstName ?? '').trim();
    final trimmedLastName = (lastName ?? '').trim();
    final combinedName = [
      trimmedFirstName,
      trimmedLastName,
    ].where((part) => part.isNotEmpty).join(' ');
    final resolvedName =
        name.trim().isNotEmpty ? name.trim() : combinedName.trim();
    final resolvedUsername = _deriveInitialUsername(
      user: u,
      name: resolvedName,
      provided: username,
    );
    if (!snap.exists) {
      await _createPendingVendorProfile(
        user: u,
        name: resolvedName,
        firstName: trimmedFirstName,
        lastName: trimmedLastName,
        username: resolvedUsername,
        businessName: businessName,
        phone: phone,
      );
    } else {
      final data = snap.data();
      final updates = <String, dynamic>{};
      final existingUsername =
          data != null ? (data['username'] as String? ?? '') : '';
      if (existingUsername.trim().isEmpty && resolvedUsername.isNotEmpty) {
        updates['username'] = resolvedUsername;
      }
      if ((data?['firstName'] ?? '').toString().trim().isEmpty &&
          trimmedFirstName.isNotEmpty) {
        updates['firstName'] = trimmedFirstName;
      }
      if ((data?['lastName'] ?? '').toString().trim().isEmpty &&
          trimmedLastName.isNotEmpty) {
        updates['lastName'] = trimmedLastName;
      }
      if ((data?['name'] ?? '').toString().trim().isEmpty &&
          resolvedName.isNotEmpty) {
        updates['name'] = resolvedName;
      }
      if ((data?['businessName'] ?? '').toString().trim().isEmpty &&
          businessName.trim().isNotEmpty) {
        updates['businessName'] = businessName.trim();
      }
      final trimmedPhone = (phone ?? '').trim();
      if ((data?['phone'] ?? '').toString().trim().isEmpty &&
          trimmedPhone.isNotEmpty) {
        updates['phone'] = trimmedPhone;
      }
      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        await doc.set(updates, SetOptions(merge: true));
      }
    }
  }

  Future<void> _createPendingVendorProfile({
    required User user,
    required String name,
    required String firstName,
    required String lastName,
    required String username,
    required String businessName,
    String? phone,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'username': username.trim(),
      'businessName': businessName.trim(),
      'phone': (phone ?? '').trim(),
    };

    try {
      final callable = _functions.httpsCallable(
        'createVendorProfile',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      await callable.call(payload);
      return;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('createVendorProfile callable failed: ${e.code} ${e.message}');
    } catch (err) {
      debugPrint('createVendorProfile callable unavailable: $err');
    }

    final profile =
        UserProfile(
            uid: user.uid,
            firstName: firstName.trim(),
            lastName: lastName.trim(),
            name: name.trim(),
            username: username.trim(),
            businessName: businessName.trim(),
            phone: (phone ?? '').trim(),
            email: user.email ?? '',
            role: 'vendor',
            approved: false,
            disabled: false,
          ).toMap()
          ..addAll({
            'uid': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

    await _db.collection(AppConfig.usersCollection).doc(user.uid).set(profile);
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
