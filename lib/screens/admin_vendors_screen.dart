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
            if (_cachedDocs != null) {
              _cachedDocs =
                  _cachedDocs!.where((d) => d.id != vendorId).toList();
            }
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

        if (snap.hasData && snap.data != null) {
          final snapshot = snap.data!;
          final filtered =
              snapshot.docs.where((d) {
                final data = d.data();
                final approved = data['approved'] == true;
                final disabled = data['disabled'] == true;
                if (widget.pending) {
                  return !approved || disabled;
                } else {
                  return approved && !disabled;
                }
              }).toList();

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
        } else {
          return const Center(child: CircularProgressIndicator());
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
            .where((doc) => !_deletingIds.contains(doc.id))
            .toList(growable: false);

        if (visibleDocs.isEmpty) {
          return Center(
            child: Text(
              widget.pending ? 'No pending vendors' : 'No active vendors',
            ),
          );
        }

        return ListView.separated(
          itemCount: visibleDocs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = visibleDocs[i];
            final m = d.data();
            final deleting = _deletingIds.contains(d.id);
            return ListTile(
              enabled: !deleting,
              onTap:
                  deleting
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
              title: Text(m['name'] ?? ''),
              subtitle: Text(
                '${m['businessName'] ?? ''}\n${m['email'] ?? ''} - ${m['phone'] ?? ''}',
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 8,
                children: [
                  if (widget.pending)
                    ElevatedButton(
                      onPressed:
                          () => d.reference.update({
                            'approved': true,
                            'disabled': false,
                          }),
                      child: const Text('Approve'),
                    ),
                  TextButton(
                    onPressed:
                        deleting
                            ? null
                            : () => d.reference.update({
                              'disabled': true,
                              'approved': false,
                            }),
                    child: const Text('Disable'),
                  ),
                  TextButton(
                    onPressed: deleting ? null : () => _handleDelete(d),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
        );
      },
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
