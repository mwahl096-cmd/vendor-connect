import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../utils/role_utils.dart';
import '../services/vendor_admin_service.dart';

enum _VendorListMode { pending, active, disabled }

class AdminVendorsScreen extends StatefulWidget {
  const AdminVendorsScreen({super.key});

  @override
  State<AdminVendorsScreen> createState() => _AdminVendorsScreenState();
}

class _AdminVendorsScreenState extends State<AdminVendorsScreen> {
  @override
  Widget build(BuildContext context) {
    final CollectionReference<Map<String, dynamic>> users = FirebaseFirestore
        .instance
        .collection(AppConfig.usersCollection);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin - Vendors'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(width: 4, color: Colors.white),
              insets: EdgeInsets.symmetric(horizontal: 32),
            ),
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Active'),
              Tab(text: 'Disabled'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _VendorList(source: users, mode: _VendorListMode.pending),
            _VendorList(source: users, mode: _VendorListMode.active),
            _VendorList(source: users, mode: _VendorListMode.disabled),
          ],
        ),
      ),
    );
  }
}

class _VendorList extends StatefulWidget {
  final CollectionReference<Map<String, dynamic>> source;
  final _VendorListMode mode;
  const _VendorList({required this.source, required this.mode});

  @override
  State<_VendorList> createState() => _VendorListState();
}

class _VendorListState extends State<_VendorList> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _cachedDocs;
  final Set<String> _deletingIds = <String>{};
  final VendorAdminService _adminService = VendorAdminService();
  final Set<String> _inFlightIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isBusy(String vendorId) =>
      _deletingIds.contains(vendorId) || _inFlightIds.contains(vendorId);

  void _removeFromCache(String vendorId) {
    if (_cachedDocs == null) return;
    _cachedDocs = _cachedDocs!
        .where((doc) => doc.id != vendorId)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final next = _searchController.text.trim().toLowerCase();
      if (next == _searchQuery) return;
      setState(() {
        _searchQuery = next;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _field(Map<String, dynamic> data, String key) =>
      (data[key] ?? '').toString().trim();

  String _displayName(Map<String, dynamic> data) {
    final firstName = _field(data, 'firstName');
    final lastName = _field(data, 'lastName');
    final fullName =
        [firstName, lastName].where((part) => part.isNotEmpty).join(' ').trim();
    if (fullName.isNotEmpty) return fullName;

    final name = _field(data, 'name');
    if (name.isNotEmpty) return name;

    final username = _field(data, 'username');
    if (username.isNotEmpty) return username;

    final email = _field(data, 'email');
    if (email.contains('@')) return email.split('@').first;
    return email.isNotEmpty ? email : 'Unnamed vendor';
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applySearch(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (_searchQuery.isEmpty) return docs;
    return docs
        .where((doc) {
          final data = doc.data();
          final searchable =
              [
                _field(data, 'firstName'),
                _field(data, 'lastName'),
                _field(data, 'name'),
                _field(data, 'username'),
                _field(data, 'businessName'),
                _field(data, 'email'),
              ].join(' ').toLowerCase();
          return searchable.contains(_searchQuery);
        })
        .toList(growable: false);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search vendors by name',
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _searchQuery.isEmpty
                  ? null
                  : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _searchController.clear(),
                  ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2BBFD4), width: 2),
          ),
        ),
      ),
    );
  }

  Future<void> _updateVendorFields({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required Map<String, dynamic> updates,
    bool removeFromCurrentList = false,
    String? successMessage,
  }) async {
    final vendorId = doc.id;
    if (_inFlightIds.contains(vendorId)) return;

    setState(() {
      _inFlightIds.add(vendorId);
    });

    try {
      await doc.reference.update(updates);
      if (!mounted) return;
      setState(() {
        if (removeFromCurrentList) {
          _removeFromCache(vendorId);
        }
        _inFlightIds.remove(vendorId);
      });
      if (successMessage != null && successMessage.isNotEmpty && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _inFlightIds.remove(vendorId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update vendor: ${e.message ?? e.code}'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inFlightIds.remove(vendorId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update vendor')));
    }
  }

  Future<void> _handleDelete(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Vendor'),
            content: const Text(
              'Delete this vendor profile? They will lose access.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await _deleteVendor(doc);
    }
  }

  Future<void> _deleteVendor(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final vendorId = doc.id;
    if (_deletingIds.contains(vendorId)) return;

    setState(() {
      _deletingIds.add(vendorId);
    });

    var deleted = false;
    try {
      await _adminService.deleteVendor(vendorId);
      deleted = true;
      debugPrint('Vendor $vendorId deleted via callable');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Vendor deleted')));
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete vendor: ${e.message ?? e.code}'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete vendor')),
        );
      }
    } finally {
      if (!mounted) {
        if (!deleted) {
          _deletingIds.remove(vendorId);
        }
      } else {
        setState(() {
          if (deleted) {
            _removeFromCache(vendorId);
            _deletingIds.remove(vendorId);
            _inFlightIds.remove(vendorId);
          } else {
            _deletingIds.remove(vendorId);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.source.snapshots(),
      builder: (context, snap) {
        List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

        final waiting = snap.connectionState == ConnectionState.waiting;
        final snapshot = snap.data;

        if (snapshot != null) {
          final filtered =
              snapshot.docs.where((d) {
                  final data = d.data();
                  final role = normalizedRole(data);
                  if (role != 'vendor') return false;
                  final approved = truthy(data['approved']);
                  final disabled = truthy(data['disabled']);
                  switch (widget.mode) {
                    case _VendorListMode.pending:
                      return !approved && !disabled;
                    case _VendorListMode.active:
                      return approved && !disabled;
                    case _VendorListMode.disabled:
                      return disabled;
                  }
                }).toList()
                ..sort(
                  (a, b) => (a.data()['name'] ?? '').toString().compareTo(
                    (b.data()['name'] ?? '').toString(),
                  ),
                );

          if (filtered.isEmpty &&
              snapshot.metadata.isFromCache &&
              _cachedDocs != null) {
            docs = _cachedDocs!;
          } else {
            docs = filtered;
            _cachedDocs =
                List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                  filtered,
                );
          }
        } else if (_cachedDocs != null) {
          docs = _cachedDocs!;
        } else if (waiting) {
          return const Center(child: CircularProgressIndicator());
        } else {
          docs = const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        }

        if (_deletingIds.isNotEmpty) {
          final staleIds = _deletingIds
              .where((id) => docs.every((doc) => doc.id != id))
              .toList(growable: false);
          if (staleIds.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _deletingIds.removeAll(staleIds);
              });
            });
          }
        }

        final visibleDocs = docs
            .where(
              (doc) =>
                  !_deletingIds.contains(doc.id) &&
                  !_inFlightIds.contains(doc.id),
            )
            .toList(growable: false);

        final showsSearch = widget.mode != _VendorListMode.pending;
        final searchedDocs =
            showsSearch ? _applySearch(visibleDocs) : visibleDocs;

        if (searchedDocs.isEmpty) {
          final message =
              showsSearch && _searchQuery.isNotEmpty
                  ? 'No vendors match "${_searchController.text.trim()}"'
                  : switch (widget.mode) {
                    _VendorListMode.pending => 'No pending vendors',
                    _VendorListMode.active => 'No active vendors',
                    _VendorListMode.disabled => 'No disabled vendors',
                  };
          final empty = Center(child: Text(message));
          if (!showsSearch) return empty;
          return Column(children: [_buildSearchBar(), Expanded(child: empty)]);
        }

        final list = ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: searchedDocs.length,
          itemBuilder: (context, i) {
            final d = searchedDocs[i];
            final m = d.data();
            final displayName = _displayName(m);
            final businessName = _field(m, 'businessName');
            final email = _field(m, 'email');
            final phone = _field(m, 'phone');
            final approved = truthy(m['approved']);
            final disabled = truthy(m['disabled']);
            final busy = _isBusy(d.id);
            final deleting = _deletingIds.contains(d.id);
            final primaryColor = const Color(0xFF2BBFD4);
            final borderRadius = BorderRadius.circular(16);
            final cardShape = RoundedRectangleBorder(
              borderRadius: borderRadius,
              side: BorderSide(color: Colors.grey.shade200),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Material(
                color: Colors.white,
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.05),
                shape: cardShape,
                child: InkWell(
                  borderRadius: borderRadius,
                  onTap:
                      deleting || busy
                          ? null
                          : () async {
                            final result = await Navigator.of(
                              context,
                            ).push<bool>(
                              MaterialPageRoute(
                                builder:
                                    (_) => VendorDetailScreen(vendorId: d.id),
                              ),
                            );
                            if (!mounted) return;
                            if (result == true) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('Vendor deleted')),
                              );
                            }
                          },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8FAFC),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                disabled
                                    ? Icons.person_off_outlined
                                    : approved
                                    ? Icons.storefront_outlined
                                    : Icons.pending_actions_outlined,
                                color: const Color(0xFF007887),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _VendorInfoLine(
                                    icon: Icons.business_outlined,
                                    label: 'Business',
                                    value:
                                        businessName.isEmpty
                                            ? 'Not provided'
                                            : businessName,
                                    highlightMissing: businessName.isEmpty,
                                  ),
                                  if (email.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    _VendorInfoLine(
                                      icon: Icons.email_outlined,
                                      label: 'Email',
                                      value: email,
                                    ),
                                  ],
                                  if (phone.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    _VendorInfoLine(
                                      icon: Icons.phone_outlined,
                                      label: 'Phone',
                                      value: phone,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (!approved && !disabled)
                              _FilledActionButton(
                                label: 'Approve',
                                icon: Icons.check_circle_outline,
                                color: primaryColor,
                                busy: busy,
                                onPressed:
                                    busy
                                        ? null
                                        : () => _updateVendorFields(
                                          doc: d,
                                          updates: {
                                            'approved': true,
                                            'disabled': false,
                                          },
                                          removeFromCurrentList: true,
                                          successMessage: 'Vendor approved',
                                        ),
                              ),
                            if (!approved && !disabled)
                              _FilledActionButton(
                                label: 'Reject',
                                icon: Icons.block_outlined,
                                color: primaryColor,
                                busy: busy,
                                onPressed:
                                    busy
                                        ? null
                                        : () => _updateVendorFields(
                                          doc: d,
                                          updates: {
                                            'disabled': true,
                                            'approved': false,
                                          },
                                          removeFromCurrentList: true,
                                          successMessage: 'Vendor rejected',
                                        ),
                              ),
                            if (approved && !disabled)
                              _FilledActionButton(
                                label: 'Disable',
                                icon: Icons.block_outlined,
                                color: primaryColor,
                                busy: busy,
                                onPressed:
                                    busy
                                        ? null
                                        : () => _updateVendorFields(
                                          doc: d,
                                          updates: {
                                            'disabled': true,
                                            'approved': false,
                                          },
                                          removeFromCurrentList: true,
                                          successMessage: 'Vendor disabled',
                                        ),
                              ),
                            if (disabled)
                              _FilledActionButton(
                                label: 'Activate',
                                icon: Icons.check_circle_outline,
                                color: primaryColor,
                                busy: busy,
                                onPressed:
                                    busy
                                        ? null
                                        : () => _updateVendorFields(
                                          doc: d,
                                          updates: {
                                            'approved': true,
                                            'disabled': false,
                                          },
                                          removeFromCurrentList: true,
                                          successMessage: 'Vendor activated',
                                        ),
                              ),
                            _FilledActionButton(
                              label: 'Delete',
                              icon: Icons.delete_outline,
                              color: Colors.redAccent,
                              busy: busy,
                              onPressed: busy ? null : () => _handleDelete(d),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
        if (!showsSearch) return list;
        return Column(children: [_buildSearchBar(), Expanded(child: list)]);
      },
    );
  }
}

class _VendorInfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlightMissing;

  const _VendorInfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.highlightMissing = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlightMissing ? Colors.redAccent : Colors.black54;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color, height: 1.25),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilledActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool busy;
  const _FilledActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: busy ? 0 : (onPressed == null ? 0 : 1),
    );

    Widget buildChild() {
      if (busy) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Text(label),
          ],
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Text(label),
        ],
      );
    }

    return ElevatedButton(
      onPressed: busy ? null : onPressed,
      style: style,
      child: buildChild(),
    );
  }
}

class VendorDetailScreen extends StatelessWidget {
  final String vendorId;
  static final VendorAdminService _adminService = VendorAdminService();
  const VendorDetailScreen({super.key, required this.vendorId});

  @override
  Widget build(BuildContext context) {
    final doc = FirebaseFirestore.instance
        .collection(AppConfig.usersCollection)
        .doc(vendorId);
    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Detail')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: doc.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('Not found'));
          }
          final data = snap.data!.data()!;
          final disabled = truthy(data['disabled']);
          final approved = truthy(data['approved']);
          final firstName = (data['firstName'] ?? '').toString().trim();
          final lastName = (data['lastName'] ?? '').toString().trim();
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (firstName.isNotEmpty || lastName.isNotEmpty) ...[
                  ListTile(
                    title: const Text('First Name'),
                    subtitle: Text(
                      firstName.isEmpty ? 'Not provided' : firstName,
                    ),
                  ),
                  ListTile(
                    title: const Text('Last Name'),
                    subtitle: Text(
                      lastName.isEmpty ? 'Not provided' : lastName,
                    ),
                  ),
                ],
                ListTile(
                  title: const Text('Name'),
                  subtitle: Text(data['name'] ?? ''),
                ),
                ListTile(
                  title: const Text('Business'),
                  subtitle: Text(data['businessName'] ?? ''),
                ),
                ListTile(
                  title: const Text('Phone'),
                  subtitle: Text(data['phone'] ?? ''),
                ),
                ListTile(
                  title: const Text('Email'),
                  subtitle: Text(data['email'] ?? ''),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Approved'),
                    const SizedBox(width: 8),
                    Switch(
                      value: approved,
                      onChanged: (v) {
                        final update = <String, dynamic>{'approved': v};
                        if (v) {
                          update['disabled'] = false;
                        }
                        doc.update(update);
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Disabled'),
                    const SizedBox(width: 8),
                    Switch(
                      value: disabled,
                      onChanged: (v) {
                        final update = <String, dynamic>{'disabled': v};
                        if (v) {
                          update['approved'] = false;
                        }
                        doc.update(update);
                      },
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder:
                          (_) => AlertDialog(
                            title: const Text('Remove Vendor'),
                            content: const Text('Remove this vendor profile?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                    );
                    if (ok == true) {
                      try {
                        await _adminService.deleteVendor(vendorId);
                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      } on FirebaseException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to remove vendor: ${e.message ?? e.code}',
                              ),
                            ),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to remove vendor'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove Vendor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
