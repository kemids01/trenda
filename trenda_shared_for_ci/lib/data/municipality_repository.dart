import 'package:http/http.dart' as http;
import 'package:trenda_shared/core/config.dart';
import 'base_repository.dart';

class MunicipalityModel {
  final String id;
  final String name;
  final double surcharge;
  final bool isActive;
  final int order;
  // ✅ GAP-F6: Extended fields for cross-app usage
  final String? status;
  final String? timezone;
  final double? centerLat;
  final double? centerLng;
  final double? radiusKm;
  final bool? operatingHoursEnabled;
  final String? operatingHoursStart;
  final String? operatingHoursEnd;

  MunicipalityModel({
    required this.id,
    required this.name,
    this.surcharge = 0,
    this.isActive = true,
    this.order = 99,
    this.status,
    this.timezone,
    this.centerLat,
    this.centerLng,
    this.radiusKm,
    this.operatingHoursEnabled,
    this.operatingHoursStart,
    this.operatingHoursEnd,
  });

  factory MunicipalityModel.fromJson(Map<String, dynamic> json) {
    return MunicipalityModel(
      id: json['_id'] as String,
      name: json['name'] as String,
      surcharge: (json['surcharge'] as num?)?.toDouble() ?? 0.0,
      isActive: json['isActive'] as bool? ?? true,
      order: json['order'] as int? ?? 99,
      status: json['status'] as String?,
      timezone: json['timezone'] as String?,
      centerLat: (json['center']?['lat'] as num?)?.toDouble(),
      centerLng: (json['center']?['lng'] as num?)?.toDouble(),
      radiusKm: (json['radiusKm'] as num?)?.toDouble(),
      operatingHoursEnabled: json['operatingHours']?['enabled'] as bool?,
      operatingHoursStart: json['operatingHours']?['start'] as String?,
      operatingHoursEnd: json['operatingHours']?['end'] as String?,
    );
  }

  /// Check if this municipality has custom operating hours
  bool get hasCustomHours => operatingHoursEnabled == true;
}

class MunicipalityRepository extends BaseRepository {
  MunicipalityRepository({super.baseUrl});

  Future<List<MunicipalityModel>> getMunicipalities({
    bool includeInactive = false,
  }) async {
    return retryRequest(() async {
      final uri = Uri.parse('$baseUrl/api/municipalities').replace(
        queryParameters: {'includeInactive': includeInactive.toString()},
      );

      final response = await http.get(uri).timeout(AppConfig.connectTimeout);
      final body = parseResponse(response);
      final List<dynamic> data = body['data'];

      return data.map((json) => MunicipalityModel.fromJson(json)).toList();
    });
  }
}
