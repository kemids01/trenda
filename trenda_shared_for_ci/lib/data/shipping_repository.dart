// trenda_shared/lib/data/shipping_repository.dart
// Shipping repository for vendor shipping management

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'base_repository.dart';
import '../models/shipment_model.dart';

class ShippingRepository extends BaseRepository {
  ShippingRepository({super.baseUrl});

  /// Get vendor's shipments
  Future<ShipmentsFetchResult> getVendorShipments({
    int page = 1,
    int limit = 20,
    String? status,
    String? courier,
    String? sortBy,
    String? sortOrder,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
        if (courier != null) 'courier': courier,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

      final uri = Uri.parse('$baseUrl/api/vendor/shipping/shipments')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      final shipments = (body['data'] as List)
          .map((e) => ShipmentModel.fromJson(e))
          .toList();

      return ShipmentsFetchResult(
        shipments: shipments,
        total: body['pagination']?['total'] ?? shipments.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  /// Mark order as ready to ship
  Future<ShipmentModel> markReadyToShip({
    required String orderId,
    double? packageWeight,
    PackageDimensions? packageDimensions,
    String? notes,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/shipping/$orderId/ready');

      final data = <String, dynamic>{};
      if (packageWeight != null) data['packageWeight'] = packageWeight;
      if (packageDimensions != null) {
        data['packageDimensions'] = packageDimensions.toJson();
      }
      if (notes != null) data['notes'] = notes;

      final response = await http
          .put(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ShipmentModel.fromJson(body['data']);
    });
  }

  /// Update tracking information
  Future<ShipmentModel> updateTracking({
    required String orderId,
    required String courier,
    required String trackingNumber,
    String? trackingUrl,
    DateTime? shippingDate,
    DateTime? estimatedDelivery,
    String? status,
    String? notes,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/shipping/$orderId/tracking');

      final data = <String, dynamic>{
        'courier': courier,
        'trackingNumber': trackingNumber,
        if (trackingUrl != null) 'trackingUrl': trackingUrl,
        if (shippingDate != null) 'shippingDate': shippingDate.toIso8601String(),
        if (estimatedDelivery != null)
          'estimatedDelivery': estimatedDelivery.toIso8601String(),
        if (status != null) 'status': status,
        if (notes != null) 'notes': notes,
      };

      final response = await http
          .put(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ShipmentModel.fromJson(body['data']);
    });
  }

  /// Generate shipping label
  Future<String> generateShippingLabel({
    required String orderId,
    String? courier,
    String labelSize = '4x6',
    String format = 'pdf',
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/shipping/$orderId/label');

      final data = <String, dynamic>{
        'labelSize': labelSize,
        'format': format,
        if (courier != null) 'courier': courier,
      };

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return body['data']['url'] ?? body['data']['labelUrl'] ?? '';
    });
  }

  /// Bulk ship orders
  Future<List<ShipmentModel>> bulkShipOrders({
    required List<String> orderIds,
    required String courier,
    List<String>? trackingNumbers,
    DateTime? shippingDate,
    DateTime? estimatedDelivery,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/shipping/bulk-ship');

      final data = <String, dynamic>{
        'orderIds': orderIds,
        'courier': courier,
        if (trackingNumbers != null) 'trackingNumbers': trackingNumbers,
        if (shippingDate != null) 'shippingDate': shippingDate.toIso8601String(),
        if (estimatedDelivery != null)
          'estimatedDelivery': estimatedDelivery.toIso8601String(),
      };

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return (body['data'] as List)
          .map((e) => ShipmentModel.fromJson(e))
          .toList();
    });
  }

  /// Get shipping analytics
  Future<ShippingAnalytics> getShippingAnalytics({
    String? period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (period != null) queryParams['period'] = period;
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

      final uri = Uri.parse('$baseUrl/api/vendor/shipping/analytics')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      
      // Safely handle data being a Map or List
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        return ShippingAnalytics.fromJson(data);
      }
      // If data is a list or null, return empty analytics
      return ShippingAnalytics();
    });
  }

  /// Get available couriers
  Future<List<CourierModel>> getAvailableCouriers() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/shipping/couriers');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return (body['data'] as List)
          .map((e) => CourierModel.fromJson(e))
          .toList();
    });
  }
}
