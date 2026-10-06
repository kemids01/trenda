// trenda_shared/lib/data/dashboard_repository.dart
// Dashboard repository for vendor dashboard

import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'base_repository.dart';
import '../models/dashboard_model.dart';

class DashboardRepository extends BaseRepository {
  DashboardRepository({super.baseUrl});

  /// Get comprehensive dashboard data
  Future<DashboardModel> getDashboardData({String period = 'week'}) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final uri = Uri.parse(
        '$baseUrl/api/vendor/dashboard',
      ).replace(queryParameters: {'period': period});

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return DashboardModel.fromJson(body['data']);
    });
  }

  /// Get real-time updates (polls)
  Future<Map<String, dynamic>> getRealtimeUpdates({DateTime? since}) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (since != null) queryParams['since'] = since.toIso8601String();

      final uri = Uri.parse(
        '$baseUrl/api/vendor/dashboard/realtime',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return body['data'] ?? {};
    });
  }
}
