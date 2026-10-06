// trenda_shared/lib/services/geo_service.dart
// ============================================================================
// GEO SERVICE - Geocoding, reverse geocoding, and distance calculations
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// Represents a geographic location with coordinates
class GeoLocation {
  final double latitude;
  final double longitude;
  final String? address;
  final String? displayName;
  final GeoAddressComponents? components;

  const GeoLocation({
    required this.latitude,
    required this.longitude,
    this.address,
    this.displayName,
    this.components,
  });

  factory GeoLocation.fromJson(Map<String, dynamic> json) {
    return GeoLocation(
      latitude: double.parse(json['lat'].toString()),
      longitude: double.parse(json['lon'].toString()),
      displayName: json['display_name'] as String?,
      address: json['display_name'] as String?,
      components: json['address'] != null
          ? GeoAddressComponents.fromJson(json['address'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lon': longitude,
    'display_name': displayName,
    'address': components?.toJson(),
  };

  @override
  String toString() =>
      'GeoLocation($latitude, $longitude${displayName != null ? ': $displayName' : ''})';
}

/// Parsed address components from reverse geocoding
class GeoAddressComponents {
  final String? houseNumber;
  final String? road;
  final String? suburb;
  final String? village;
  final String? town;
  final String? city;
  final String? municipality;
  final String? county;
  final String? state;
  final String? region;
  final String? postcode;
  final String? country;
  final String? countryCode;

  const GeoAddressComponents({
    this.houseNumber,
    this.road,
    this.suburb,
    this.village,
    this.town,
    this.city,
    this.municipality,
    this.county,
    this.state,
    this.region,
    this.postcode,
    this.country,
    this.countryCode,
  });

  factory GeoAddressComponents.fromJson(Map<String, dynamic> json) {
    return GeoAddressComponents(
      houseNumber: json['house_number'] as String?,
      road: json['road'] as String?,
      suburb: json['suburb'] as String?,
      village: json['village'] as String?,
      town: json['town'] as String?,
      city: json['city'] as String?,
      municipality: json['municipality'] as String?,
      county: json['county'] as String?,
      state: json['state'] as String?,
      region: json['region'] as String?,
      postcode: json['postcode'] as String?,
      country: json['country'] as String?,
      countryCode: json['country_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'house_number': houseNumber,
    'road': road,
    'suburb': suburb,
    'village': village,
    'town': town,
    'city': city,
    'municipality': municipality,
    'county': county,
    'state': state,
    'region': region,
    'postcode': postcode,
    'country': country,
    'country_code': countryCode,
  };

  /// Get the best available city name
  String? get cityName => city ?? town ?? municipality ?? village;

  /// Format a full address
  String get formattedAddress {
    final parts = <String>[];
    if (houseNumber != null) parts.add(houseNumber!);
    if (road != null) parts.add(road!);
    if (suburb != null) parts.add(suburb!);
    if (cityName != null) parts.add(cityName!);
    if (state != null) parts.add(state!);
    if (postcode != null) parts.add(postcode!);
    return parts.join(', ');
  }
}

/// Route information with distance and duration
class RouteInfo {
  final double distanceMeters;
  final Duration? estimatedDuration;
  final List<GeoLocation>? waypoints;

  const RouteInfo({
    required this.distanceMeters,
    this.estimatedDuration,
    this.waypoints,
  });

  /// Distance in kilometers
  double get distanceKm => distanceMeters / 1000;

  /// Distance in miles
  double get distanceMiles => distanceMeters / 1609.34;

  /// Human readable distance
  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}

/// Geo service with caching for geocoding operations
class GeoService {
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'com.trenda.app/1.0';

  // Cache for geocoding results
  static final Map<String, GeoLocation> _geocodeCache = {};
  static final Map<String, GeoLocation> _reverseGeocodeCache = {};
  static const int _maxCacheSize = 100;

  // Rate limiting for Nominatim (1 request per second)
  static DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(seconds: 1);

  /// Wait to respect rate limits
  static Future<void> _respectRateLimit() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minRequestInterval) {
        await Future.delayed(_minRequestInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  /// Clean cache if too large
  static void _cleanCache(Map<String, GeoLocation> cache) {
    if (cache.length > _maxCacheSize) {
      final keysToRemove = cache.keys
          .take(cache.length - _maxCacheSize ~/ 2)
          .toList();
      for (final key in keysToRemove) {
        cache.remove(key);
      }
    }
  }

  /// Forward geocode an address to coordinates
  static Future<GeoLocation?> geocode(
    String address, {
    String? countryCode,
    int limit = 1,
  }) async {
    final cacheKey = '${address.toLowerCase()}_${countryCode ?? ''}';

    // Check cache
    if (_geocodeCache.containsKey(cacheKey)) {
      return _geocodeCache[cacheKey];
    }

    await _respectRateLimit();

    try {
      final queryParams = {
        'q': address,
        'format': 'json',
        'limit': limit.toString(),
        'addressdetails': '1',
        if (countryCode != null) 'countrycodes': countryCode,
      };

      final uri = Uri.parse(
        '$_nominatimBaseUrl/search',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final location = GeoLocation.fromJson(data.first);
          _geocodeCache[cacheKey] = location;
          _cleanCache(_geocodeCache);
          return location;
        }
      }
    } catch (e) {
      // Log error but don't throw
    }
    return null;
  }

  /// Reverse geocode coordinates to an address
  static Future<GeoLocation?> reverseGeocode(
    double latitude,
    double longitude, {
    int zoom = 18,
  }) async {
    final cacheKey =
        '${latitude.toStringAsFixed(5)}_${longitude.toStringAsFixed(5)}';

    // Check cache
    if (_reverseGeocodeCache.containsKey(cacheKey)) {
      return _reverseGeocodeCache[cacheKey];
    }

    await _respectRateLimit();

    try {
      final queryParams = {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'format': 'json',
        'addressdetails': '1',
        'zoom': zoom.toString(),
      };

      final uri = Uri.parse(
        '$_nominatimBaseUrl/reverse',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('lat')) {
          final location = GeoLocation.fromJson(data);
          _reverseGeocodeCache[cacheKey] = location;
          _cleanCache(_reverseGeocodeCache);
          return location;
        }
      }
    } catch (e) {
      // Log error but don't throw
    }
    return null;
  }

  /// Search for places matching a query
  static Future<List<GeoLocation>> search(
    String query, {
    String? countryCode,
    int limit = 5,
  }) async {
    if (query.length < 3) return [];

    await _respectRateLimit();

    try {
      final queryParams = {
        'q': query,
        'format': 'json',
        'limit': limit.toString(),
        'addressdetails': '1',
        if (countryCode != null) 'countrycodes': countryCode,
      };

      final uri = Uri.parse(
        '$_nominatimBaseUrl/search',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => GeoLocation.fromJson(item)).toList();
      }
    } catch (e) {
      // Log error but don't throw
    }
    return [];
  }

  /// Calculate distance between two points using Haversine formula
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c * 1000; // Return in meters
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Estimate travel time based on distance and average speed
  static Duration estimateTravelTime(
    double distanceMeters, {
    double averageSpeedKmh = 30.0, // Default for city driving
  }) {
    final distanceKm = distanceMeters / 1000;
    final hours = distanceKm / averageSpeedKmh;
    return Duration(minutes: (hours * 60).round());
  }

  /// Get route info between two points (simplified - uses straight line distance)
  static RouteInfo getRouteInfo(
    double startLat,
    double startLon,
    double endLat,
    double endLon, {
    double averageSpeedKmh = 30.0,
  }) {
    final distance = calculateDistance(startLat, startLon, endLat, endLon);
    final duration = estimateTravelTime(
      distance,
      averageSpeedKmh: averageSpeedKmh,
    );

    return RouteInfo(distanceMeters: distance, estimatedDuration: duration);
  }

  /// Check if a location is within a radius of another location
  static bool isWithinRadius(
    double centerLat,
    double centerLon,
    double pointLat,
    double pointLon,
    double radiusMeters,
  ) {
    final distance = calculateDistance(
      centerLat,
      centerLon,
      pointLat,
      pointLon,
    );
    return distance <= radiusMeters;
  }

  /// Clear all caches
  static void clearCache() {
    _geocodeCache.clear();
    _reverseGeocodeCache.clear();
  }

  /// Get cache statistics
  static Map<String, int> getCacheStats() {
    return {
      'geocode': _geocodeCache.length,
      'reverseGeocode': _reverseGeocodeCache.length,
    };
  }
}

/// Extension for easy distance calculations on GeoLocation
extension GeoLocationDistance on GeoLocation {
  double distanceTo(GeoLocation other) {
    return GeoService.calculateDistance(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  RouteInfo routeTo(GeoLocation other, {double averageSpeedKmh = 30.0}) {
    return GeoService.getRouteInfo(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
      averageSpeedKmh: averageSpeedKmh,
    );
  }

  bool isWithin(GeoLocation center, double radiusMeters) {
    return GeoService.isWithinRadius(
      center.latitude,
      center.longitude,
      latitude,
      longitude,
      radiusMeters,
    );
  }
}
