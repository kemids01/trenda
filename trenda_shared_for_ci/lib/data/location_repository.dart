// trenda_shared/lib/data/location_repository.dart

import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'base_repository.dart';

class PhilippineRegion {
  final String name;
  final String fullName;

  PhilippineRegion({required this.name, required this.fullName});

  factory PhilippineRegion.fromJson(Map<String, dynamic> json) {
    return PhilippineRegion(
      name: json['name'] as String,
      fullName: json['fullName'] as String,
    );
  }
}

class CityMunicipality {
  final String name;
  final String type; // 'city' or 'municipality'

  CityMunicipality({required this.name, required this.type});

  factory CityMunicipality.fromJson(Map<String, dynamic> json) {
    return CityMunicipality(
      name: json['name'] as String,
      type: json['type'] as String,
    );
  }

  String get displayName => type == 'city' ? '$name (City)' : name;
}

class LocationRepository extends BaseRepository {
  LocationRepository({super.baseUrl});

  /// Get all Philippine regions
  Future<List<PhilippineRegion>> getRegions() async {
    return retryRequest(() async {
      final uri = Uri.parse('$baseUrl/api/locations/regions');

      final response = await http.get(uri).timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final List<dynamic> data = body['data'];

      return data.map((json) => PhilippineRegion.fromJson(json)).toList();
    });
  }

  /// Get provinces by region
  Future<List<String>> getProvinces(String region) async {
    return retryRequest(() async {
      final uri = Uri.parse(
        '$baseUrl/api/locations/provinces',
      ).replace(queryParameters: {'region': region});

      final response = await http.get(uri).timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final List<dynamic> data = body['data'];

      // ✅ FIXED: Extract 'name' from province objects (backend returns {_id, psgcCode, name, ...})
      return data
          .map((e) {
            if (e is Map<String, dynamic>) {
              return e['name']?.toString() ?? '';
            }
            return e.toString();
          })
          .where((name) => name.isNotEmpty)
          .toList();
    });
  }

  /// Get cities/municipalities by province
  Future<List<CityMunicipality>> getCities(String province) async {
    return retryRequest(() async {
      final uri = Uri.parse(
        '$baseUrl/api/locations/cities',
      ).replace(queryParameters: {'province': province});

      final response = await http.get(uri).timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final List<dynamic> data = body['data'];

      return data.map((json) => CityMunicipality.fromJson(json)).toList();
    });
  }

  /// Get barangays by city/municipality
  Future<List<String>> getBarangays(String city) async {
    return retryRequest(() async {
      final uri = Uri.parse(
        '$baseUrl/api/locations/barangays',
      ).replace(queryParameters: {'city': city});

      final response = await http.get(uri).timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final List<dynamic> data = body['data'];

      // ✅ FIXED: Extract 'name' from barangay objects (backend returns {_id, psgcCode, name, ...})
      return data
          .map((e) {
            if (e is Map<String, dynamic>) {
              return e['name']?.toString() ?? '';
            }
            return e.toString();
          })
          .where((name) => name.isNotEmpty)
          .toList();
    });
  }

  /// Search locations
  Future<Map<String, dynamic>> searchLocations(String query) async {
    return retryRequest(() async {
      if (query.length < 2) {
        return {
          'regions': <PhilippineRegion>[],
          'provinces': <String>[],
          'cities': <CityMunicipality>[],
          'barangays': <String>[],
        };
      }

      final uri = Uri.parse(
        '$baseUrl/api/locations/search',
      ).replace(queryParameters: {'q': query});

      final response = await http.get(uri).timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return body['data'] as Map<String, dynamic>;
    });
  }
}
