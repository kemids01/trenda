// lib/features/checkout/utils/visible_delivery_types.dart
/// Intersect the app's known delivery types with the admin-enabled set, preserving `allTypes` order.
/// If `enabled` is empty/unknown, fall back to all (never show zero options).
List<String> visibleDeliveryTypes(List<String> allTypes, List<String> enabled) {
  if (enabled.isEmpty) return allTypes;
  return allTypes.where((t) => enabled.contains(t)).toList();
}
