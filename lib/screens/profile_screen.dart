import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'auth_screen.dart';
import 'admin_dashboard.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _editProfile(Map<String, dynamic> data) async {
    final messenger = ScaffoldMessenger.of(context);
    final storedUsername = (data['username'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final fallbackUsername =
        storedUsername.isNotEmpty
            ? storedUsername
            : (email.contains('@') ? email.split('@').first : email);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _EditProfileSheet(
            initialName: (data['name'] ?? '').toString(),
            initialUsername: fallbackUsername,
            initialBusinessName: (data['businessName'] ?? '').toString(),
            initialPhone: (data['phone'] ?? '').toString(),
          ),
    );
    if (!mounted) return;
    if (result == true) {
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  Future<String?> _showDeleteAccountDialog({
    required bool requirePassword,
    required String email,
  }) async {
    final controller = TextEditingController();
    String? errorText;
    bool obscure = true;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Delete account'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This will permanently remove your profile, account data, '
                      'and access for $email. This action cannot be undone.',
                    ),
                    if (requirePassword) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        obscureText: obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Confirm password',
                          errorText: errorText,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(() => obscure = !obscure),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final password = controller.text.trim();
                    if (requirePassword && password.isEmpty) {
                      setState(() => errorText = 'Password required');
                      return;
                    }
                    Navigator.of(dialogContext).pop(password);
                  },
                  child: const Text('Delete account'),
                ),
              ],
            );
          },
        );
      },
    );

    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    return result;
  }

  Future<void> _confirmDeleteAccount(String email) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final requirePassword = user.providerData.any(
      (info) => info.providerId == 'password',
    );
    final password = await _showDeleteAccountDialog(
      requirePassword: requirePassword,
      email: email,
    );
    if (password == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notificationService = context.read<NotificationService>();
    final accountService = AccountService();
    final uid = user.uid;

    var progressVisible = true;
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ).then((_) => progressVisible = false);

    var deletionSucceeded = false;
    String? errorMessage;
    try {
      await accountService.deleteAccount(password: password);
      deletionSucceeded = true;
      unawaited(notificationService.cleanupAfterSignOut(uidOverride: uid));
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'missing-password':
          errorMessage = 'Enter your password to confirm account deletion.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
        case 'user-mismatch':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'requires-recent-login':
          errorMessage =
              'For security reasons, please sign in again and retry deleting '
              'your account.';
          break;
        default:
          errorMessage =
              e.message ?? 'Unable to delete account. Please try again.';
      }
    } on FirebaseFunctionsException catch (e) {
      errorMessage =
          e.message ??
          'Unable to delete account right now. Please try again later.';
    } on FirebaseException catch (e) {
      errorMessage =
          e.message ?? 'Unable to delete account. Please try again later.';
    } catch (_) {
      errorMessage = 'Unable to delete account. Please try again later.';
    } finally {
      if (progressVisible && mounted) {
        rootNavigator.pop();
      }
    }

    if (!mounted) return;
    if (deletionSucceeded) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Account deleted'),
              content: const Text(
                'Your account and associated data have been deleted.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      if (!mounted) return;
      navigator.pushNamedAndRemoveUntil(AuthScreen.route, (route) => false);
    } else if (errorMessage != null) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  String _initialFor(String name, String email, String username) {
    for (final value in [name, email, username]) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed[0].toUpperCase();
      }
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    final userDoc = FirebaseFirestore.instance
        .collection(AppConfig.usersCollection)
        .doc(uid);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDoc.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data();
          if (data == null) {
            return const Center(child: Text('No profile'));
          }
          final role = (data['role'] ?? 'vendor').toString();
          final isAdmin = role == 'admin';
          final name = (data['name'] ?? '').toString();
          final email = (data['email'] ?? '').toString();
          final usernameRaw = (data['username'] ?? '').toString();
          final username =
              usernameRaw.isNotEmpty
                  ? usernameRaw.trim()
                  : (email.contains('@')
                      ? email.split('@').first.trim()
                      : email.trim());
          final businessName = (data['businessName'] ?? '').toString();
          final phone = (data['phone'] ?? '').toString();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        child: Text(_initialFor(name, email, username)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isNotEmpty ? name : 'Name not set',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            if (username.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                username.startsWith('@')
                                    ? username
                                    : '@$username',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _editProfile(data),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Profile'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _infoTile('Business', businessName)),
                  const SizedBox(width: 12),
                  Expanded(child: _infoTile('Phone', phone)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _infoTile(
                  'Username',
                  username.isNotEmpty ? username : '-',
                ),
              ),
              const SizedBox(height: 20),
              if (isAdmin) ...[
                Text(
                  'Admin Tools',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminDashboardScreen(),
                        ),
                      ),
                  icon: const Icon(Icons.dashboard_customize),
                  label: const Text('Open Admin Dashboard'),
                ),
                const SizedBox(height: 20),
              ],
              Text('Account', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  final notificationService =
                      context.read<NotificationService>();
                  final authService = context.read<AuthService>();
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final previousUid = FirebaseAuth.instance.currentUser?.uid;
                  try {
                    await authService.signOut();
                  } on FirebaseAuthException catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          e.message ?? 'Unable to sign out. Please retry.',
                        ),
                      ),
                    );
                    return;
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Unable to sign out. Please retry.'),
                      ),
                    );
                    return;
                  }
                  unawaited(
                    notificationService.cleanupAfterSignOut(
                      uidOverride: previousUid,
                    ),
                  );
                  if (!mounted) return;
                  navigator.pushNamedAndRemoveUntil(
                    AuthScreen.route,
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: () => _confirmDeleteAccount(email),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Delete account'),
              ),
              const SizedBox(height: 8),
              Text(
                'Deleting your account removes your profile, comments, and '
                'access permanently.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.initialName,
    required this.initialUsername,
    required this.initialBusinessName,
    required this.initialPhone,
  });

  final String initialName;
  final String initialUsername;
  final String initialBusinessName;
  final String initialPhone;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _usernameController = TextEditingController(
    text: widget.initialUsername,
  );
  late final TextEditingController _businessController = TextEditingController(
    text: widget.initialBusinessName,
  );
  late final TextEditingController _phoneController = TextEditingController(
    text: widget.initialPhone,
  );
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _businessController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await auth.updateProfile(
        name: _nameController.text,
        username: _usernameController.text,
        businessName: _businessController.text,
        phone: _phoneController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to update profile.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to update profile. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomPadding + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Edit Profile',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.alternate_email_outlined),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Required';
                  if (trimmed.contains(' ')) return 'No spaces allowed';
                  return null;
                },
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
                    return 'Required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return null;
                  final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
                  if (digitsOnly.length < 7) {
                    return 'Enter a valid phone or leave blank';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child:
                    _saving
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Small helper to render info tiles in the profile header
Widget _infoTile(String title, String value) {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.grey.shade300),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}
