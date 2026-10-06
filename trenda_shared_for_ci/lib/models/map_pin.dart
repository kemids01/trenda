// A labelled point on a map — an ad's pin, or a vendor store's.
//
// Two endpoints send it in two shapes and both are accepted here, in the one place
// that knows the difference:
//   • GET /api/ads-section  → the stored GeoJSON  { label, type, coordinates: [lng, lat] }
//   • GET /api/ads/official → the flattened DTO   { label, lat, lng }
//
// ⚠️ GeoJSON is [lng, lat]. Reversing it is a silent bug — the button still works, it
// just opens the wrong hemisphere — so this is the only file that indexes that array.

class MapPin {
  /// What the admin typed, e.g. "Centro Plaza, Tuguegarao City". May be empty.
  final String label;
  final double lat;
  final double lng;

  const MapPin({required this.label, required this.lat, required this.lng});

  /// Returns null for anything that is not a usable pin — a missing coordinate, a
  /// label with no point, an unparseable value. Mirrors `hasAdLocation` on the
  /// backend, so both ends agree on what "has a location" means.
  static MapPin? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    double? asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim());
      return null;
    }

    double? lat;
    double? lng;

    final coords = json['coordinates'];
    if (coords is List && coords.length >= 2) {
      lng = asDouble(coords[0]);
      lat = asDouble(coords[1]);
    } else {
      lat = asDouble(json['lat'] ?? json['latitude']);
      lng = asDouble(json['lng'] ?? json['lon'] ?? json['longitude']);
    }

    if (lat == null || lng == null) return null;

    return MapPin(
      label: json['label']?.toString().trim() ?? '',
      lat: lat,
      lng: lng,
    );
  }

  /// Opens Google Maps at the pin, in the app when it is installed and the browser
  /// otherwise. ⚠️ Google's `query` is `lat,lng` — the opposite of GeoJSON.
  String get mapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  /// What the button says. A bare coordinate tells a shopper nothing, so an unlabelled
  /// pin falls back to the generic wording rather than printing numbers.
  String get buttonLabel => label.isEmpty ? 'See location' : label;

  Map<String, dynamic> toJson() => {'label': label, 'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapPin && other.label == label && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(label, lat, lng);
}
