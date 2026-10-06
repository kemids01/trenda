// trenda_shared/lib/data/inventory_repository.dart
// Repository for advanced inventory management

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'base_repository.dart';
import '../models/inventory_model.dart';

class InventoryRepository extends BaseRepository {
  InventoryRepository({super.baseUrl});

  /// Get inventory logs for a product
  Future<List<InventoryLog>> getInventoryLogs(
    String productId, {
    int page = 1,
    int limit = 50,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (type != null) 'type': type,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      };

      final uri = Uri.parse(
        '$baseUrl/api/vendor-inventory/logs/$productId',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return (body['data'] as List)
          .map((l) => InventoryLog.fromJson(l))
          .toList();
    });
  }

  /// Adjust inventory for a product/variant
  Future<InventoryLog> adjustInventory({
    required String productId,
    String? variantId,
    required int adjustment,
    required String reason,
    String? reference,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor-inventory/adjust');

      // Backend expects 'quantity' (positive) and 'type' ('add' or 'subtract')
      final quantity = adjustment.abs();
      final type = adjustment >= 0 ? 'add' : 'subtract';

      final data = <String, dynamic>{
        'productId': productId,
        'quantity': quantity,
        'type': type,
        'reason': reason,
        if (variantId != null) 'variant': variantId,
        if (reference != null) 'notes': reference,
      };

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return InventoryLog.fromJson(body['data']['log'] ?? body['data']);
    });
  }

  /// Bulk adjust inventory
  Future<List<InventoryLog>> bulkAdjustInventory(
    List<BulkAdjustmentItem> adjustments,
  ) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor-inventory/bulk-adjust');

      final data = {'adjustments': adjustments.map((a) => a.toJson()).toList()};

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return (body['data']['logs'] as List? ?? body['data'] as List? ?? [])
          .map((l) => InventoryLog.fromJson(l))
          .toList();
    });
  }

  /// Get inventory alerts
  Future<InventoryAlertsData> getInventoryAlerts({
    bool includeForecasting = false,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (includeForecasting) queryParams['forecasting'] = 'true';

      final uri = Uri.parse(
        '$baseUrl/api/vendor-inventory/alerts',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return InventoryAlertsData.fromJson(body['data']);
    });
  }

  /// Get inventory statistics
  Future<InventoryStats> getInventoryStats({String? category}) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (category != null) queryParams['category'] = category;

      final uri = Uri.parse(
        '$baseUrl/api/vendor-inventory/stats',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return InventoryStats.fromJson(body['data']);
    });
  }

  /// Get inventory forecast for a product
  Future<InventoryForecast> getInventoryForecast(
    String productId, {
    int days = 30,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {'productId': productId, 'days': days.toString()};

      final uri = Uri.parse(
        '$baseUrl/api/vendor-inventory/forecast',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return InventoryForecast.fromJson(body['data']);
    });
  }

  /// Set auto-reorder rules
  Future<AutoReorderRule> setAutoReorderRules(AutoReorderRule rule) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor-inventory/auto-reorder-rules');

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(rule.toJson()))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return AutoReorderRule.fromJson(body['data']);
    });
  }

  /// Get expiring products
  Future<List<InventoryAlertItem>> getExpiringProducts({
    int daysThreshold = 30,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {'days': daysThreshold.toString()};

      final uri = Uri.parse(
        '$baseUrl/api/vendor-inventory/expiring',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      // Backend returns categorized structure: {summary, products: {expiring7days, expiring30days, etc}}
      // We need to flatten this into a single list
      final productsData = body['data']['products'];
      if (productsData is Map) {
        final List<InventoryAlertItem> allItems = [];

        // Combine all categories
        for (final category in productsData.values) {
          if (category is List) {
            allItems.addAll(
              category.map((e) => InventoryAlertItem.fromJson(e)),
            );
          }
        }
        return allItems;
      }

      // Fallback: if it's already a list
      return (body['data'] as List)
          .map((e) => InventoryAlertItem.fromJson(e))
          .toList();
    });
  }

  /// Get inventory value report
  Future<InventoryValueReport> getInventoryValueReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (startDate != null)
        queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final uri = Uri.parse(
        '$baseUrl/api/vendor-inventory/value-report',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return InventoryValueReport.fromJson(body['data']);
    });
  }
}

/// Bulk adjustment item
class BulkAdjustmentItem {
  final String productId;
  final String? variantId;
  final int adjustment;
  final String reason;

  BulkAdjustmentItem({
    required this.productId,
    this.variantId,
    required this.adjustment,
    required this.reason,
  });

  Map<String, dynamic> toJson() {
    final quantity = adjustment.abs();
    final type = adjustment >= 0 ? 'add' : 'subtract';

    return {
      'productId': productId,
      if (variantId != null) 'variant': variantId,
      'quantity': quantity,
      'type': type,
      'reason': reason,
    };
  }
}
