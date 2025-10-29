class UserProfile {
  final String uid;
  final String name;
  final String username;
  final String businessName;
  final String phone;
  final String email;
  final String role; // 'vendor' | 'admin'
  final bool approved; // must be true to access app content
  final bool disabled; // if true, block sign-in usage
  final DateTime? lastLoginAt;

  UserProfile({
    required this.uid,
    required this.name,
    required this.username,
    required this.businessName,
    required this.phone,
    required this.email,
    required this.role,
    required this.approved,
    required this.disabled,
    this.lastLoginAt,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'username': username,
    'businessName': businessName,
    'phone': phone,
    'email': email,
    'role': role,
    'approved': approved,
    'disabled': disabled,
    if (lastLoginAt != null)
      'lastLoginAt': lastLoginAt!.toUtc().toIso8601String(),
  };

  static UserProfile fromMap(String uid, Map<String, dynamic> data) =>
      UserProfile(
        uid: uid,
        name: (data['name'] ?? '') as String,
        username: (data['username'] ?? '') as String,
        businessName: (data['businessName'] ?? '') as String,
        phone: (data['phone'] ?? '') as String,
        email: (data['email'] ?? '') as String,
        role: (data['role'] ?? 'vendor') as String,
        approved: (data['approved'] ?? false) as bool,
        disabled: (data['disabled'] ?? false) as bool,
        lastLoginAt:
            data['lastLoginAt'] is String
                ? DateTime.tryParse(data['lastLoginAt'] as String)
                : null,
      );
}
