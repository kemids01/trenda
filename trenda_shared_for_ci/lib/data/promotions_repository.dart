// trenda_shared/lib/data/promotions_repository.dart
// Promotions repository for vendor promotions management

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'base_repository.dart';
import '../models/promotion_model.dart';

class PromotionsRepository extends BaseRepository {
  PromotionsRepository({super.baseUrl});

  /// Get vendor's promotions
  Future<PromotionsFetchResult> getVendorPromotions({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
      };

      final uri = Uri.parse(
        '$baseUrl/api/vendor/promotions',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      final promotions = (body['data'] as List)
          .map((e) => PromotionModel.fromJson(e))
          .toList();

      return PromotionsFetchResult(
        promotions: promotions,
        total: body['pagination']?['total'] ?? promotions.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  /// Create new promotion
  Future<PromotionModel> createPromotion(Map<String, dynamic> data) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/promotions');

      // ✅ DEBUG: Log the exact data being sent
      print('📤 [Promotions] Creating promotion - Request data: $data');

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      // ✅ DEBUG: Log the response
      print(
        '📥 [Promotions] Response: ${response.statusCode} - ${response.body}',
      );

      final body = parseResponse(response);
      return PromotionModel.fromJson(body['data']);
    });
  }

  /// Update promotion
  Future<PromotionModel> updatePromotion(
    String promotionId,
    Map<String, dynamic> data,
  ) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/promotions/$promotionId');

      final response = await http
          .put(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return PromotionModel.fromJson(body['data']);
    });
  }

  /// Delete promotion
  Future<bool> deletePromotion(String promotionId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/promotions/$promotionId');

      final response = await http
          .delete(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
      return true;
    });
  }

  /// Toggle promotion status
  Future<PromotionModel> togglePromotionStatus(
    String promotionId,
    String status,
  ) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse(
        '$baseUrl/api/vendor/promotions/$promotionId/status',
      );

      final response = await http
          .patch(
            uri,
            headers: headers(token),
            body: jsonEncode({'status': status}),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return PromotionModel.fromJson(body['data']);
    });
  }

  /// Get promotion analytics
  Future<PromotionAnalytics> getPromotionAnalytics(
    String promotionId, {
    String? period,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (period != null) queryParams['period'] = period;

      final uri = Uri.parse(
        '$baseUrl/api/vendor/promotions/$promotionId/analytics',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return PromotionAnalytics.fromJson(body['data']);
    });
  }

  /// Duplicate promotion
  Future<PromotionModel> duplicatePromotion(String promotionId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse(
        '$baseUrl/api/vendor/promotions/$promotionId/duplicate',
      );

      final response = await http
          .post(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return PromotionModel.fromJson(body['data']);
    });
  }

  /// Get promotion statistics
  Future<PromotionStatistics> getPromotionStatistics({String? period}) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (period != null) queryParams['period'] = period;

      final uri = Uri.parse(
        '$baseUrl/api/vendor/promotions/statistics',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return PromotionStatistics.fromJson(body['data']);
    });
  }
}

class PromotionsFetchResult {
  final List<PromotionModel> promotions;
  final int total;
  final int page;
  final int totalPages;

  PromotionsFetchResult({
    required this.promotions,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}
