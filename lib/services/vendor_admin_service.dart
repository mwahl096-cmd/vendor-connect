import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';

/// Administrative utilities for managing vendor accounts.
class VendorAdminService {
  VendorAdminService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<void> setVendorFlags({
    required String uid,
    bool? approved,
    bool? disabled,
  }) async {
    final payload = <String, dynamic>{'uid': uid};
    if (approved != null) payload['approved'] = approved;
    if (disabled != null) payload['disabled'] = disabled;
    try {
      final callable = _functions.httpsCallable(
        'adminSetVendorFlags',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      await callable.call(payload);
      return;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('adminSetVendorFlags callable error: ${e.code} ${e.message}');
      if (!_canFallbackToFirestore(e.code)) {
        rethrow;
      }
    } catch (err) {
      debugPrint('adminSetVendorFlags callable failed: $err');
    }

    await _firestore
        .collection(AppConfig.usersCollection)
        .doc(uid)
        .update(payload..remove('uid'));
  }

  bool _canFallbackToFirestore(String code) {
    return code == 'unimplemented' ||
        code == 'unavailable' ||
        code == 'internal' ||
        code == 'permission-denied';
  }

  Future<void> createPendingVendorProfile({
    required String email,
    String? firstName,
    String? lastName,
    String? name,
    String? businessName,
    String? phone,
  }) async {
    final callable = _functions.httpsCallable(
      'adminCreatePendingVendorProfile',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    await callable.call(<String, dynamic>{
      'email': email,
      'firstName': firstName ?? '',
      'lastName': lastName ?? '',
      'name': name ?? '',
      'businessName': businessName ?? '',
      'phone': phone ?? '',
    });
  }

  /// Deletes a vendor by delegating to the backend callable. If the callable
  /// is unavailable (e.g., not yet deployed), fall back to the legacy
  /// client-side cleanup to avoid blocking admin workflows.
  Future<void> deleteVendor(String vendorId) async {
    try {
      final callable = _functions.httpsCallable(
        'adminDeleteVendor',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      await callable.call(<String, dynamic>{'uid': vendorId});
      return;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('adminDeleteVendor callable error: ${e.code} ${e.message}');
      if (e.code != 'unimplemented' && e.code != 'unavailable') {
        rethrow;
      }
    } catch (err) {
      debugPrint('adminDeleteVendor callable failed: $err');
    }

    await _deleteVendorLegacy(vendorId);
  }

  Future<void> _deleteVendorLegacy(String vendorId) async {
    final vendorRef = _firestore
        .collection(AppConfig.usersCollection)
        .doc(vendorId);
    await vendorRef.delete();

    try {
      final readsSnap =
          await _firestore
              .collection(AppConfig.readsCollection)
              .where('uid', isEqualTo: vendorId)
              .get();
      if (readsSnap.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in readsSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return;
      }
      rethrow;
    }
  }
}
