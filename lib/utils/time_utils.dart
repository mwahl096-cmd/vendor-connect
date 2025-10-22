import 'package:cloud_firestore/cloud_firestore.dart';

/// Returns `true` when [createdAt] is within [window] of the provided [reference]
/// time (defaults to `DateTime.now()`).
bool isWithinWindow(dynamic createdAt, Duration window, {DateTime? reference}) {
  final now = (reference ?? DateTime.now()).toLocal();
  final cutoff = now.subtract(window);
  final eventTime = _normalizeToDateTime(createdAt);
  if (eventTime == null) return false;
  return !eventTime.isBefore(cutoff);
}

DateTime? _normalizeToDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate().toLocal();
  if (value is DateTime) return value.toLocal();
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  if (value is num) {
    final millis = value > 10000000000 ? value.toDouble() : value.toDouble() * 1000;
    return DateTime.fromMillisecondsSinceEpoch(millis.round(), isUtc: true).toLocal();
  }
  return null;
}
