import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../models/loyalty_partner.dart';
import '../services/loyalty_service.dart';
import '../utils/role_utils.dart';

class ManageLoyaltyBenefitsScreen extends StatefulWidget {
  const ManageLoyaltyBenefitsScreen({super.key});

  @override
  State<ManageLoyaltyBenefitsScreen> createState() =>
      _ManageLoyaltyBenefitsScreenState();
}

class _ManageLoyaltyBenefitsScreenState
    extends State<ManageLoyaltyBenefitsScreen> {
  final LoyaltyService _loyaltyService = LoyaltyService();

  Future<void> _openEditor({LoyaltyPartner? partner}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return _LoyaltyBenefitEditor(
          partner: partner,
          onSave: (draft) async {
            await _loyaltyService.savePartner(
              id: partner?.id,
              businessName: draft.businessName,
              address: draft.address,
              city: draft.city,
              state: draft.state,
              zipCode: draft.zipCode,
              phone: draft.phone,
              email: draft.email,
              website: draft.website,
              offerDescription: draft.offerDescription,
              offerAmount: draft.offerAmount,
              offerUnit: draft.offerUnit,
              isActive: draft.isActive,
              sortOrder: draft.sortOrder,
              eligibleVendorIds: draft.eligibleVendorIds,
              eligibleVendorNames: draft.eligibleVendorNames,
            );
          },
        );
      },
    );
    if (saved != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          partner == null
              ? 'Benefit listing added.'
              : 'Benefit listing updated.',
        ),
      ),
    );
  }

  Future<void> _deletePartner(LoyaltyPartner partner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete listing'),
            content: Text('Delete ${partner.businessName}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await _loyaltyService.deletePartner(partner.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Benefit listing deleted.')));
  }

  Future<void> _toggleActive(LoyaltyPartner partner) async {
    await FirebaseFirestore.instance
        .collection(AppConfig.loyaltyPartnersCollection)
        .doc(partner.id)
        .update({
          'isActive': !partner.isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !partner.isActive
              ? 'Listing activated.'
              : 'Listing hidden from vendors.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Loyalty Benefits')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add benefit'),
      ),
      body: StreamBuilder<List<LoyaltyPartner>>(
        stream: _loyaltyService.watchAllPartners(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final partners = snap.data ?? const <LoyaltyPartner>[];
          if (partners.isEmpty) {
            return const Center(
              child: Text(
                'No benefit listings yet. Tap "Add benefit" to create one.',
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: partners.length,
            itemBuilder: (context, index) {
              final partner = partners[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                partner.businessName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    partner.isActive
                                        ? const Color(
                                          0xFF2BBFD4,
                                        ).withOpacity(0.1)
                                        : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                partner.isActive ? 'Active' : 'Hidden',
                                style: TextStyle(
                                  color:
                                      partner.isActive
                                          ? const Color(0xFF18889A)
                                          : Colors.black54,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (partner.offerHeadline.isNotEmpty)
                          Text(
                            partner.offerHeadline,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        if (partner.offerDescription.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            partner.offerDescription,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          partner.eligibleVendorIds.isEmpty
                              ? 'Eligible Vendors: All registered vendors'
                              : 'Eligible Vendors: ${partner.eligibleVendorNames.isEmpty ? '${partner.eligibleVendorIds.length} selected' : partner.eligibleVendorNames.join(', ')}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        if (partner.fullAddress.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            partner.fullAddress,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _openEditor(partner: partner),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _toggleActive(partner),
                              icon: Icon(
                                partner.isActive
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              label: Text(
                                partner.isActive ? 'Hide' : 'Activate',
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                              ),
                              onPressed: () => _deletePartner(partner),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LoyaltyBenefitEditor extends StatefulWidget {
  final LoyaltyPartner? partner;
  final Future<void> Function(_LoyaltyDraft draft) onSave;

  const _LoyaltyBenefitEditor({required this.partner, required this.onSave});

  @override
  State<_LoyaltyBenefitEditor> createState() => _LoyaltyBenefitEditorState();
}

class _LoyaltyBenefitEditorState extends State<_LoyaltyBenefitEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _businessController = TextEditingController(
    text: widget.partner?.businessName ?? '',
  );
  late final TextEditingController _offerDescriptionController =
      TextEditingController(text: widget.partner?.offerDescription ?? '');
  late final TextEditingController _offerAmountController =
      TextEditingController(text: _initialOfferAmountText());
  late String _offerUnit = _initialOfferUnit();
  late final TextEditingController _addressController = TextEditingController(
    text: widget.partner?.address ?? '',
  );
  late final TextEditingController _cityController = TextEditingController(
    text: widget.partner?.city ?? '',
  );
  late final TextEditingController _stateController = TextEditingController(
    text: widget.partner?.state ?? '',
  );
  late final TextEditingController _zipController = TextEditingController(
    text: widget.partner?.zipCode ?? '',
  );
  late final TextEditingController _phoneController = TextEditingController(
    text: widget.partner?.phone ?? '',
  );
  late final TextEditingController _emailController = TextEditingController(
    text: widget.partner?.email ?? '',
  );
  late final TextEditingController _websiteController = TextEditingController(
    text: widget.partner?.website ?? '',
  );
  late final TextEditingController _sortOrderController = TextEditingController(
    text: (widget.partner?.sortOrder ?? 0).toString(),
  );
  late final TextEditingController _vendorSearchController =
      TextEditingController();
  final Map<String, String> _selectedVendors = <String, String>{};

  late bool _isActive;
  bool _saving = false;

  String _initialOfferAmountText() {
    final amount = widget.partner?.offerAmount;
    if (amount != null && amount > 0) {
      return amount == amount.roundToDouble()
          ? amount.toStringAsFixed(0)
          : amount.toStringAsFixed(2);
    }
    final legacy = widget.partner?.offer ?? '';
    final match = RegExp(r'(\$)?\s*(\d+(?:\.\d+)?)\s*(%)?').firstMatch(legacy);
    if (match == null) return '';
    return match.group(2)?.trim() ?? '';
  }

  String _initialOfferUnit() {
    if ((widget.partner?.offerUnit ?? '').trim() == '%') return '%';
    final legacy = widget.partner?.offer ?? '';
    if (legacy.contains('%')) return '%';
    return '\$';
  }

  @override
  void initState() {
    super.initState();
    _isActive = widget.partner?.isActive ?? true;
    final ids = widget.partner?.eligibleVendorIds ?? const <String>[];
    final names = widget.partner?.eligibleVendorNames ?? const <String>[];
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i].trim();
      if (id.isEmpty) continue;
      final fallback = 'Vendor ${i + 1}';
      final name =
          i < names.length && names[i].trim().isNotEmpty
              ? names[i].trim()
              : fallback;
      _selectedVendors[id] = name;
    }
  }

  @override
  void dispose() {
    _businessController.dispose();
    _offerDescriptionController.dispose();
    _offerAmountController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _sortOrderController.dispose();
    _vendorSearchController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final offerAmount = double.tryParse(_offerAmountController.text.trim());
    if (offerAmount == null || offerAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid offer amount (for example: 10 or 10.5).',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;
      final sortedEntries =
          _selectedVendors.entries.toList()..sort(
            (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
          );
      final draft = _LoyaltyDraft(
        businessName: _businessController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        zipCode: _zipController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        website: _websiteController.text.trim(),
        offerDescription: _offerDescriptionController.text.trim(),
        offerAmount: offerAmount,
        offerUnit: _offerUnit,
        isActive: _isActive,
        sortOrder: sortOrder,
        eligibleVendorIds: sortedEntries
            .map((entry) => entry.key)
            .toList(growable: false),
        eligibleVendorNames: sortedEntries
            .map((entry) => entry.value)
            .toList(growable: false),
      );
      await widget.onSave(draft);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save listing. Please retry.')),
      );
    }
  }

  List<_VendorOption> _extractVendorOptions(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final vendors = <_VendorOption>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (normalizedRole(data) != 'vendor') continue;
      if (!truthy(data['approved']) || truthy(data['disabled'])) continue;
      final name = (data['name'] ?? '').toString().trim();
      final businessName = (data['businessName'] ?? '').toString().trim();
      final email = (data['email'] ?? '').toString().trim();
      final label =
          name.isNotEmpty
              ? name
              : businessName.isNotEmpty
              ? businessName
              : email;
      if (label.isEmpty) continue;
      vendors.add(
        _VendorOption(
          uid: doc.id,
          label: label,
          email: email,
          businessName: businessName,
        ),
      );
    }
    vendors.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return vendors;
  }

  List<_VendorOption> _filteredSuggestions(List<_VendorOption> allVendors) {
    final query = _vendorSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return const <_VendorOption>[];
    final filtered = allVendors
        .where((vendor) {
          if (_selectedVendors.containsKey(vendor.uid)) return false;
          final composite =
              '${vendor.label} ${vendor.businessName} ${vendor.email}'
                  .toLowerCase();
          return composite.contains(query);
        })
        .toList(growable: false);
    return filtered.take(8).toList(growable: false);
  }

  void _addVendor(_VendorOption vendor) {
    setState(() {
      _selectedVendors[vendor.uid] = vendor.label;
      _vendorSearchController.clear();
    });
  }

  void _removeVendor(String uid) {
    setState(() {
      _selectedVendors.remove(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, insets + 16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.partner == null
                            ? 'Add Loyalty Benefit'
                            : 'Edit Loyalty Benefit',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _saving
                              ? null
                              : () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _businessController,
                  decoration: const InputDecoration(
                    labelText: 'Business Name',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Business name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _offerAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixIcon: Icon(Icons.confirmation_number_outlined),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final parsed = double.tryParse((value ?? '').trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: DropdownButtonFormField<String>(
                        value: _offerUnit,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          prefixIcon: Icon(Icons.tune),
                        ),
                        items: const [
                          DropdownMenuItem(value: '\$', child: Text('\$')),
                          DropdownMenuItem(value: '%', child: Text('%')),
                        ],
                        onChanged:
                            _saving
                                ? null
                                : (value) {
                                  setState(() {
                                    _offerUnit = (value == '%') ? '%' : '\$';
                                  });
                                },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _offerDescriptionController,
                  decoration: const InputDecoration(
                    labelText: 'MSC Offer (required)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'MSC offer is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vendorSearchController,
                  decoration: const InputDecoration(
                    labelText: 'Offer For MSC Vendors (optional)',
                    hintText: 'Start typing vendor name to search',
                    prefixIcon: Icon(Icons.person_search_outlined),
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream:
                      FirebaseFirestore.instance
                          .collection(AppConfig.usersCollection)
                          .snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data;
                    if (docs == null) {
                      return const SizedBox.shrink();
                    }
                    final vendors = _extractVendorOptions(docs);
                    final suggestions = _filteredSuggestions(vendors);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedVendors.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedVendors.entries
                                .map((entry) {
                                  return Chip(
                                    label: Text(entry.value),
                                    onDeleted:
                                        _saving
                                            ? null
                                            : () => _removeVendor(entry.key),
                                  );
                                })
                                .toList(growable: false),
                          ),
                        ],
                        if (_vendorSearchController.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child:
                                suggestions.isEmpty
                                    ? const ListTile(
                                      title: Text(
                                        'No matching registered vendors',
                                      ),
                                    )
                                    : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: suggestions.length,
                                      itemBuilder: (context, index) {
                                        final vendor = suggestions[index];
                                        final subtitleParts = <String>[
                                          if (vendor.businessName.isNotEmpty)
                                            vendor.businessName,
                                          if (vendor.email.isNotEmpty)
                                            vendor.email,
                                        ];
                                        return ListTile(
                                          dense: true,
                                          title: Text(vendor.label),
                                          subtitle:
                                              subtitleParts.isEmpty
                                                  ? null
                                                  : Text(
                                                    subtitleParts.join(' - '),
                                                  ),
                                          onTap:
                                              _saving
                                                  ? null
                                                  : () => _addVendor(vendor),
                                        );
                                      },
                                    ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(
                          labelText: 'State',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _zipController,
                  decoration: const InputDecoration(
                    labelText: 'ZIP Code',
                    prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _websiteController,
                  decoration: const InputDecoration(
                    labelText: 'Website',
                    prefixIcon: Icon(Icons.public),
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sortOrderController,
                  decoration: const InputDecoration(
                    labelText: 'Sort Order (lower shows first)',
                    prefixIcon: Icon(Icons.sort),
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible to vendors'),
                  value: _isActive,
                  onChanged:
                      _saving
                          ? null
                          : (value) => setState(() => _isActive = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child:
                        _saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoyaltyDraft {
  final String businessName;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String phone;
  final String email;
  final String website;
  final String offerDescription;
  final double offerAmount;
  final String offerUnit;
  final bool isActive;
  final int sortOrder;
  final List<String> eligibleVendorIds;
  final List<String> eligibleVendorNames;

  const _LoyaltyDraft({
    required this.businessName,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.phone,
    required this.email,
    required this.website,
    required this.offerDescription,
    required this.offerAmount,
    required this.offerUnit,
    required this.isActive,
    required this.sortOrder,
    required this.eligibleVendorIds,
    required this.eligibleVendorNames,
  });
}

class _VendorOption {
  final String uid;
  final String label;
  final String email;
  final String businessName;

  const _VendorOption({
    required this.uid,
    required this.label,
    required this.email,
    required this.businessName,
  });
}
