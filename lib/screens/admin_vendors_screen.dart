import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../services/vendor_admin_service.dart';

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
    final Query<Map<String, dynamic>> vendorQuery = users.where(
      'role',
      isEqualTo: 'vendor',
    );

    return DefaultTabController(
      length: 2,
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
            tabs: [Tab(text: 'Pending'), Tab(text: 'Active')],
          ),
        ),
        body: TabBarView(
          children: [
            _VendorList(query: vendorQuery, pending: true),
            _VendorList(query: vendorQuery, pending: false),
          ],
        ),
      ),
    );
  }
}

class _VendorList extends StatefulWidget {
  final Query<Map<String, dynamic>> query;
  final bool pending;
  const _VendorList({required this.query, required this.pending});

  @override
  State<_VendorList> createState() => _VendorListState();
}

class _VendorListState extends State<_VendorList> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _cachedDocs;
  final Set<String> _deletingIds = <String>{};
  final VendorAdminService _adminService = VendorAdminService();
  final Set<String> _inFlightIds = <String>{};

  bool _isBusy(String vendorId) =>
      _deletingIds.contains(vendorId) || _inFlightIds.contains(vendorId);

  void _removeFromCache(String vendorId) {
    if (_cachedDocs == null) return;
    _cachedDocs =
        _cachedDocs!.where((doc) => doc.id != vendorId).toList(growable: false);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update vendor')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendor deleted')),
        );
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
      stream: widget.query.orderBy('name').snapshots(),
      builder: (context, snap) {
        List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

        final waiting = snap.connectionState == ConnectionState.waiting;
        final snapshot = snap.data;

        if (snapshot != null) {
          final filtered = snapshot.docs.where((d) {
            final data = d.data();
            final approved = data['approved'] == true;
            final disabled = data['disabled'] == true;
            if (widget.pending) {
              return !approved || disabled;
            } else {
              return approved && !disabled;
            }
          }).toList();

          if (filtered.isEmpty && snapshot.metadata.isFromCache && _cachedDocs != null) {
            docs = _cachedDocs!;
          } else {
            docs = filtered;
            _cachedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(filtered);
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
            .where((doc) => !_deletingIds.contains(doc.id) && !_inFlightIds.contains(doc.id))
            .toList(growable: false);

        if (visibleDocs.isEmpty) {
          return Center(
            child: Text(
              widget.pending ? 'No pending vendors' : 'No active vendors',
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: visibleDocs.length,
          itemBuilder: (context, i) {
            final d = visibleDocs[i];
            final m = d.data();
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
                shadowColor: Colors.black.withOpacity(0.05),
                shape: cardShape,
                child: InkWell(
                  borderRadius: borderRadius,
                  onTap: deleting || busy
                      ? null
                      : () async {
                          final result = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => VendorDetailScreen(vendorId: d.id),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m['name'] ?? '',
                                    style:
                                        Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    m['businessName'] ?? '',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Colors.black54,
                                            ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  m['email'] ?? '',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  m['phone'] ?? '',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (widget.pending)
                              _FilledActionButton(
                                label: 'Approve',
                                icon: Icons.check_circle_outline,
                                color: primaryColor,
                                busy: busy,
                                onPressed: busy
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
                            _FilledActionButton(
                              label: 'Disable',
                              icon: Icons.block_outlined,
                              color: primaryColor,
                              busy: busy,
                              onPressed: busy
                                  ? null
                                  : () => _updateVendorFields(
                                        doc: d,
                                        updates: {
                                          'disabled': true,
                                          'approved': false,
                                        },
                                        removeFromCurrentList: !widget.pending,
                                        successMessage: 'Vendor disabled',
                                      ),
                            ),
                            _FilledActionButton(
                              label: 'Delete',
                              icon: Icons.delete_outline,
                              color: Colors.redAccent,
                              busy: busy,
                              onPressed:
                                  busy ? null : () => _handleDelete(d),
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
      },
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
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
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
          final disabled = (data['disabled'] ?? false) as bool;
          final approved = (data['approved'] ?? false) as bool;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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





