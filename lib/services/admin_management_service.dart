import 'package:cloud_functions/cloud_functions.dart';

class AdminAccount {
  final String uid;
  final String email;
  final String name;
  final String role;
  final bool disabled;

  const AdminAccount({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.disabled,
  });

  factory AdminAccount.fromMap(Map<String, dynamic> data) {
    return AdminAccount(
      uid: (data['uid'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      role: (data['role'] ?? 'admin').toString(),
      disabled: data['disabled'] == true,
    );
  }
}

class AdminManagementService {
  AdminManagementService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<List<AdminAccount>> listAdmins() async {
    final result = await _functions.httpsCallable('adminListAdmins').call();
    final rawItems = result.data is Map ? result.data['admins'] : null;
    if (rawItems is! List) return const <AdminAccount>[];
    return rawItems
        .whereType<Map>()
        .map((item) => AdminAccount.fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<AdminAddResult> addAdmin(String email) async {
    final result = await _functions.httpsCallable('adminAddAdmin').call({
      'email': email.trim(),
    });
    final data = result.data is Map
        ? Map<String, dynamic>.from(result.data as Map)
        : const <String, dynamic>{};
    return AdminAddResult(
      uid: (data['uid'] ?? '').toString(),
      createdUser: data['createdUser'] == true,
      setupLink: (data['setupLink'] ?? '').toString(),
    );
  }

  Future<void> removeAdmin(String uid) async {
    await _functions.httpsCallable('adminRemoveAdmin').call({'uid': uid});
  }
}

class AdminAddResult {
  final String uid;
  final bool createdUser;
  final String setupLink;

  const AdminAddResult({
    required this.uid,
    required this.createdUser,
    required this.setupLink,
  });
}
