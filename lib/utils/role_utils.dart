String normalizedRole(Map<String, dynamic>? data) {
  if (data == null) return 'vendor';
  const keys = ['role', 'Role', 'userRole', 'UserRole'];
  for (final key in keys) {
    final value = data[key];
    if (value != null) {
      final normalized = value.toString().toLowerCase().trim();
      if (normalized.isNotEmpty) return normalized;
    }
  }
  return 'vendor';
}

bool truthy(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase().trim();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

bool falsy(dynamic value) => !truthy(value);
