import 'package:trenda_shared/services/geo_service.dart';
import '../../home/models/user_address.dart';

/// Municipality + barangay derived from a GPS reverse-geocode. Pure/testable.
class GpsLocality {
  final String municipality;
  final String barangay;
  const GpsLocality({required this.municipality, required this.barangay});

  bool get hasBarangay => barangay.trim().isNotEmpty;
}

/// Resolve municipality/barangay from reverse-geocoded address components.
/// Mirrors the map-picker mapping: municipality = city ?? municipality ?? town,
/// barangay = suburb ?? village. GPS is the source of truth — no manual pickers.
GpsLocality deriveGpsLocality(GeoAddressComponents? c) {
  String pick(List<String?> options) {
    for (final o in options) {
      final v = (o ?? '').trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  return GpsLocality(
    municipality: pick([c?.city, c?.municipality, c?.town]),
    barangay: pick([c?.suburb, c?.village]),
  );
}

/// Compose a UserAddress for a GPS-only delivery (current coords + admin-picked municipality/barangay).
/// Name/phone are supplied separately at checkout (contact fields), not on the address.
UserAddress buildGpsAddress({
  required double lat,
  required double lng,
  required String municipality,
  required String barangay,
}) {
  return UserAddress(
    id: 'gps',
    label: 'Current Location',
    street: 'Current GPS location',
    city: municipality,
    postalCode: '',
    country: 'Philippines',
    region: '',
    barangay: barangay,
    latitude: lat,
    longitude: lng,
    locationType: LocationType.gps,
  );
}
