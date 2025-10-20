// Using a no-op stub for now to avoid build issues with
// launcher badge plugins on latest AGP. Can switch to the
// real implementation later when compatible.
import 'badge_api_stub.dart' as impl;

Future<void> setBadgeCount(int count) => impl.setBadgeCount(count);
