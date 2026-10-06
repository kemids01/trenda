// trenda_shared/lib/data/performance_repository.dart
// Repository for vendor performance metrics

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'base_repository.dart';
import '../models/performance_model.dart';

class PerformanceRepository extends BaseRepository {
  PerformanceRepository({super.baseUrl});

  /// Get vendor's performance overview
  Future<VendorPerformance> getMyPerformance({String? period}) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (period != null) queryParams['period'] = period;

      final uri = Uri.parse(
        '$baseUrl/api/vendor/performance',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : <String, dynamic>{};
      return VendorPerformance.fromJson(data);
    });
  }

  /// Get performance score breakdown
  Future<PerformanceScore> getPerformanceScore() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/performance/score');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : <String, dynamic>{};
      return PerformanceScore.fromJson(data);
    });
  }

  /// Get active warnings
  Future<List<PerformanceWarning>> getWarnings({bool? activeOnly}) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (activeOnly != null) queryParams['active'] = activeOnly.toString();

      final uri = Uri.parse(
        '$baseUrl/api/vendor/performance/warnings',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : <String, dynamic>{};
      final warnings = data['warnings'] is List ? data['warnings'] as List : [];
      return warnings
          .map(
            (w) => PerformanceWarning.fromJson(
              w is Map ? Map<String, dynamic>.from(w) : <String, dynamic>{},
            ),
          )
          .toList();
    });
  }

  /// Acknowledge a warning
  Future<PerformanceWarning> acknowledgeWarning(String warningId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse(
        '$baseUrl/api/vendor/performance/warnings/$warningId/acknowledge',
      );

      final response = await http
          .put(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : <String, dynamic>{};
      return PerformanceWarning.fromJson(data);
    });
  }

  /// Get penalties
  Future<List<PerformancePenalty>> getPenalties({String? status}) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse(
        '$baseUrl/api/vendor/performance/penalties',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : <String, dynamic>{};
      final penalties = data['penalties'] is List
          ? data['penalties'] as List
          : [];
      return penalties
          .map(
            (p) => PerformancePenalty.fromJson(
              p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{},
            ),
          )
          .toList();
    });
  }

  /// Appeal a penalty
  Future<PerformancePenalty> appealPenalty(
    String penaltyId,
    String reason,
  ) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse(
        '$baseUrl/api/vendor/performance/penalties/$penaltyId/appeal',
      );

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({'reason': reason}),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : <String, dynamic>{};
      return PerformancePenalty.fromJson(data);
    });
  }

  /// Get rewards
  Future<List<PerformanceReward>> getRewards({bool? claimed}) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (claimed != null) queryParams['claimed'] = claimed.toString();

      final uri = Uri.parse(
        '$baseUrl/api/vendor/performance/rewards',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : <String, dynamic>{};
      final rewards = data['rewards'] is List ? data['rewards'] as List : [];
      return rewards
          .map(
            (r) => PerformanceReward.fromJson(
              r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{},
            ),
          )
          .toList();
    });
  }

  /// Get performance history
  Future<List<PerformanceHistoryEntry>> getPerformanceHistory({
    int limit = 12,
    String period = 'month',
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {'limit': limit.toString(), 'period': period};

      final uri = Uri.parse(
        '$baseUrl/api/vendor/performance/history',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : <String, dynamic>{};
      final history = data['history'] is List ? data['history'] as List : [];
      return history
          .map(
            (h) => PerformanceHistoryEntry.fromJson(
              h is Map ? Map<String, dynamic>.from(h) : <String, dynamic>{},
            ),
          )
          .toList();
    });
  }

  /// Refresh performance metrics
  Future<VendorPerformance> refreshMetrics() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/performance/refresh');

      final response = await http
          .post(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : <String, dynamic>{};
      return VendorPerformance.fromJson(data);
    });
  }
}
