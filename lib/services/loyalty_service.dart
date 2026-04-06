import 'package:cloud_firestore/cloud_firestore.dart';

import '../config.dart';
import '../models/loyalty_partner.dart';

class LoyaltyService {
  LoyaltyService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _partners =>
      _db.collection(AppConfig.loyaltyPartnersCollection);

  Stream<List<LoyaltyPartner>> watchActivePartners() {
    return _partners.snapshots().map((snapshot) {
      final all = snapshot.docs.map(LoyaltyPartner.fromDoc);
      final active = all.where((partner) => partner.isActive).toList();
      active.sort(_comparePartners);
      return active;
    });
  }

  Stream<List<LoyaltyPartner>> watchAllPartners() {
    return _partners.snapshots().map((snapshot) {
      final all = snapshot.docs.map(LoyaltyPartner.fromDoc).toList();
      all.sort(_comparePartners);
      return all;
    });
  }

  Future<void> savePartner({
    String? id,
    required String businessName,
    required String address,
    required String city,
    required String state,
    required String zipCode,
    required String phone,
    required String email,
    required String website,
    required String offerDescription,
    required double offerAmount,
    required String offerUnit,
    required bool isActive,
    required int sortOrder,
    List<String> eligibleVendorIds = const <String>[],
    List<String> eligibleVendorNames = const <String>[],
  }) async {
    final normalizedUnit = offerUnit == '%' ? '%' : '\$';
    final amountText =
        offerAmount == offerAmount.roundToDouble()
            ? offerAmount.toStringAsFixed(0)
            : offerAmount.toStringAsFixed(2);
    final headline =
        normalizedUnit == '%' ? '$amountText% off' : '\$$amountText off';
    final payload = <String, dynamic>{
      'businessName': businessName.trim(),
      'address': address.trim(),
      'city': city.trim(),
      'state': state.trim(),
      'zipCode': zipCode.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'website': website.trim(),
      'offer': headline,
      'offerDescription': offerDescription.trim(),
      'offerAmount': offerAmount,
      'offerUnit': normalizedUnit,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'eligibleVendorIds': eligibleVendorIds,
      'eligibleVendorNames': eligibleVendorNames,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docId = id?.trim() ?? '';
    if (docId.isEmpty) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      await _partners.add(payload);
      return;
    }
    await _partners.doc(docId).set(payload, SetOptions(merge: true));
  }

  Future<void> deletePartner(String id) async {
    await _partners.doc(id).delete();
  }

  int _comparePartners(LoyaltyPartner a, LoyaltyPartner b) {
    final sortOrder = a.sortOrder.compareTo(b.sortOrder);
    if (sortOrder != 0) return sortOrder;
    return a.businessName.toLowerCase().compareTo(b.businessName.toLowerCase());
  }
}
