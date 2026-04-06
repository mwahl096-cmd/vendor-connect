import 'package:cloud_firestore/cloud_firestore.dart';

class LoyaltyPartner {
  final String id;
  final String businessName;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String phone;
  final String email;
  final String website;
  final String offer;
  final double? offerAmount;
  final String offerUnit;
  final String offerDescription;
  final bool isActive;
  final int sortOrder;
  final List<String> eligibleVendorIds;
  final List<String> eligibleVendorNames;
  final DateTime? updatedAt;

  const LoyaltyPartner({
    required this.id,
    required this.businessName,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.phone,
    required this.email,
    required this.website,
    required this.offer,
    required this.offerAmount,
    required this.offerUnit,
    required this.offerDescription,
    required this.isActive,
    required this.sortOrder,
    required this.eligibleVendorIds,
    required this.eligibleVendorNames,
    this.updatedAt,
  });

  factory LoyaltyPartner.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return LoyaltyPartner(
      id: doc.id,
      businessName: (data['businessName'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      city: (data['city'] ?? '').toString(),
      state: (data['state'] ?? '').toString(),
      zipCode: (data['zipCode'] ?? data['zip'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      website: (data['website'] ?? '').toString(),
      offer: (data['offer'] ?? '').toString(),
      offerAmount: _parseDouble(data['offerAmount']),
      offerUnit: _normalizeOfferUnit(data['offerUnit']),
      offerDescription: (data['offerDescription'] ?? '').toString(),
      isActive: _parseBool(data['isActive']),
      sortOrder: _parseInt(data['sortOrder']),
      eligibleVendorIds: _parseStringList(data['eligibleVendorIds']),
      eligibleVendorNames: _parseStringList(data['eligibleVendorNames']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'businessName': businessName,
    'address': address,
    'city': city,
    'state': state,
    'zipCode': zipCode,
    'phone': phone,
    'email': email,
    'website': website,
    'offer': offer,
    'offerAmount': offerAmount,
    'offerUnit': offerUnit,
    'offerDescription': offerDescription,
    'isActive': isActive,
    'sortOrder': sortOrder,
    'eligibleVendorIds': eligibleVendorIds,
    'eligibleVendorNames': eligibleVendorNames,
  };

  String get formattedAmount {
    final amount = offerAmount;
    if (amount == null) return '';
    final amountText =
        amount == amount.roundToDouble()
            ? amount.toStringAsFixed(0)
            : amount.toStringAsFixed(2);
    if (offerUnit == '%') return '$amountText%';
    return '\$$amountText';
  }

  String get offerHeadline {
    if (formattedAmount.isNotEmpty) return '$formattedAmount off';
    return offer.trim();
  }

  String get cityStateZip {
    final cityPart = city.trim();
    final statePart = state.trim();
    final zipPart = zipCode.trim();
    final left = [cityPart, statePart].where((e) => e.isNotEmpty).join(', ');
    if (left.isEmpty) return zipPart;
    if (zipPart.isEmpty) return left;
    return '$left $zipPart';
  }

  String get fullAddress {
    final line1 = address.trim();
    final line2 = cityStateZip.trim();
    if (line1.isEmpty) return line2;
    if (line2.isEmpty) return line1;
    return '$line1, $line2';
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static bool _parseBool(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return true;
  }

  static int _parseInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 0;
    return 0;
  }

  static double? _parseDouble(dynamic raw) {
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is String) {
      final parsed = double.tryParse(raw.trim());
      return parsed;
    }
    return null;
  }

  static String _normalizeOfferUnit(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    return value == '%' ? '%' : '\$';
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is Iterable) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }
}
