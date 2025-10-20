import 'package:cloud_firestore/cloud_firestore.dart';

import '../config.dart';

/// Administrative utilities for managing vendor accounts.
class VendorAdminService {
  VendorAdminService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Deletes the vendor profile. Attempts to clean related read-tracking
  /// documents, but ignores permission errors coming from stricter security
  /// rules so the primary delete still succeeds.
  Future<void> deleteVendor(String vendorId) async {
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
