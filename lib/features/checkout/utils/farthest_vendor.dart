// lib/features/checkout/utils/farthest_vendor.dart
import 'dart:math' as math;

class VendorDistance {
  final double lat;
  final double lng;
  final double distanceKm;
  const VendorDistance({required this.lat, required this.lng, required this.distanceKm});
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const R = 6371.0;
  double toRad(double d) => d * math.pi / 180.0;
  final dLat = toRad(lat2 - lat1);
  final dLng = toRad(lng2 - lng1);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return R * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

/// The PRODUCT ids of cart lines that carry NO coordinates, de-duplicated, sorted and comma-joined so
/// the result is a stable provider-family key ('' when every line has coordinates).
///
/// Why: no product in the catalogue has coordinates, so [farthestVendor] found nothing and checkout
/// quoted the flat base fee while createOrder charged distance (₱580 vs ₱629.59,
/// ORD-1790066150633-1A61IV). The estimate endpoint resolves each product to the origin createOrder
/// uses — its vendor's store pin, or for an Official product its WAREHOUSE. Product ids, not vendor
/// ids: every Official product shares the vendor `official-trenda-store`, which has no store at all.
String pinlessLineIdsKey(Iterable<({String id, List<double>? coordinates})> lines) {
  final ids = <String>{};
  for (final l in lines) {
    if (!isRealPin(l.coordinates) && l.id.isNotEmpty) ids.add(l.id);
  }
  return (ids.toList()..sort()).join(',');
}

/// A usable [lng, lat] pin. `[0, 0]` is NOT one: trenda_shared's `ProductLocation.fromJson` fills a
/// location that has no coordinates with `[0.0, 0.0]` (the Gulf of Guinea), which would price the
/// delivery at ~13,000 km. Same rule as the backend's `hasStorePin`.
bool isRealPin(List<double>? c) =>
    c != null && c.length >= 2 && !(c[0] == 0 && c[1] == 0);

/// vendorCoords: list of [lng, lat] arrays. Returns the farthest vendor from the customer, or null
/// when no vendor has valid coordinates. Mirrors the backend farthest-leg pricing.
VendorDistance? farthestVendor(
    List<List<double>> vendorCoords, double customerLat, double customerLng) {
  VendorDistance? best;
  for (final c in vendorCoords) {
    if (!isRealPin(c)) continue;
    final lng = c[0], lat = c[1];
    final d = _haversineKm(lat, lng, customerLat, customerLng);
    if (best == null || d > best.distanceKm) {
      best = VendorDistance(lat: lat, lng: lng, distanceKm: d);
    }
  }
  return best;
}
