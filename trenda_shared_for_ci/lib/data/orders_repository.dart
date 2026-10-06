// ============================================================================
// FILE: trenda_shared/lib/data/orders_repository.dart - ENHANCED
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/data/base_repository.dart';
import '../core/config.dart';
import '../models/order_model.dart';

class OrdersRepository extends BaseRepository {
  OrdersRepository({super.baseUrl});

  /// Fetch orders (general)
  Future<OrdersFetchResult> fetchOrders({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final uri = Uri.parse('$baseUrl/api/orders').replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
          if (status != null) 'status': status,
        },
      );

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      final orders = (body['data'] as List)
          .map((e) => OrderModel.fromJson(e))
          .toList();

      return OrdersFetchResult(
        orders: orders,
        total: body['pagination']?['total'] ?? orders.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  /// Get order by ID (customer/vendor/admin - role-based access)
  Future<OrderModel> getOrderById(String orderId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/orders/$orderId');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return OrderModel.fromJson(body['data']);
    });
  }

  /// Cancel order (customer cancellation)
  Future<OrderModel> cancelOrder({
    required String orderId,
    required String reason,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/orders/$orderId/cancel');

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({'reason': reason}),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return OrderModel.fromJson(body['data']);
    });
  }

  // ============================================================================
  // VENDOR ORDER METHODS
  // ============================================================================

  /// Fetch vendor's orders with filters
  Future<OrdersFetchResult> fetchVendorOrders({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
    String? sortBy,
    String? sortOrder,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
        if (search != null) 'search': search,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

      final uri = Uri.parse(
        '$baseUrl/api/vendor/orders',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      final orders = (body['data'] as List)
          .map((e) => OrderModel.fromJson(e))
          .toList();

      return OrdersFetchResult(
        orders: orders,
        total: body['pagination']?['total'] ?? orders.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  /// Get vendor order by ID
  Future<OrderModel> getVendorOrderById(String orderId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/orders/$orderId');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return OrderModel.fromJson(body['data']);
    });
  }

  /// Update vendor order status
  Future<OrderModel> updateVendorOrderStatus({
    required String orderId,
    required String status,
    String? note,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/orders/$orderId/status');

      final data = <String, dynamic>{
        'status': status,
        if (note != null) 'note': note,
      };

      final response = await http
          .put(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return OrderModel.fromJson(body['data']);
    });
  }

  /// Get vendor order statistics
  Future<OrderStats> getVendorOrderStats({String? period}) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (period != null) queryParams['period'] = period;

      final uri = Uri.parse(
        '$baseUrl/api/vendor/orders/stats',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return OrderStats.fromJson(body['data']);
    });
  }

  /// Advanced order search
  Future<OrdersFetchResult> advancedOrderSearch({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    String? paymentStatus,
    String? paymentMethod,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    String? customerName,
    String? sortBy,
    String? sortOrder,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null) 'search': search,
        if (status != null) 'status': status,
        if (paymentStatus != null) 'paymentStatus': paymentStatus,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
        if (minAmount != null) 'minAmount': minAmount.toString(),
        if (maxAmount != null) 'maxAmount': maxAmount.toString(),
        if (customerName != null) 'customerName': customerName,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

      final uri = Uri.parse(
        '$baseUrl/api/vendor/orders/advanced/search',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      final orders = (body['data'] as List)
          .map((e) => OrderModel.fromJson(e))
          .toList();

      return OrdersFetchResult(
        orders: orders,
        total: body['pagination']?['total'] ?? orders.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  /// Bulk update order status
  Future<List<OrderModel>> bulkUpdateOrderStatus({
    required List<String> orderIds,
    required String status,
    String? note,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/orders/bulk/status');

      final data = <String, dynamic>{
        'orderIds': orderIds,
        'status': status,
        if (note != null) 'note': note,
      };

      final response = await http
          .patch(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return (body['data'] as List).map((e) => OrderModel.fromJson(e)).toList();
    });
  }

  /// Export orders to Excel/CSV
  Future<String> exportOrders({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String format = 'xlsx',
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{
        'format': format,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
        if (status != null) 'status': status,
      };

      final uri = Uri.parse(
        '$baseUrl/api/vendor/orders/export',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return body['data']['url'] ?? body['data']['downloadUrl'] ?? '';
    });
  }

  /// Add note to order
  Future<OrderModel> addOrderNote({
    required String orderId,
    required String note,
    String noteType = 'general',
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/orders/$orderId/notes');

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({'note': note, 'noteType': noteType}),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return OrderModel.fromJson(body['data']);
    });
  }

  /// Send notification to customer
  Future<bool> sendOrderNotification({
    required String orderId,
    required String message,
    String notificationType = 'push',
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/orders/$orderId/notify');

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({
              'message': message,
              'notificationType': notificationType,
            }),
          )
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
      return true;
    });
  }

  // ============================================================================
  // CUSTOMER ORDER ACTIONS
  // ============================================================================

  /// Request return for an order
  Future<bool> requestReturn({
    required String orderId,
    required String reason,
    List<String>? itemIds,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/returns');

      final data = <String, dynamic>{
        'orderId': orderId,
        'reason': reason,
        if (itemIds != null) 'itemIds': itemIds,
      };

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
      return true;
    });
  }

  /// Submit review for a product from an order
  Future<bool> submitReview({
    required String orderId,
    required String productId,
    required int rating,
    required String comment,
    List<String>? photoUrls,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/review');

      final data = <String, dynamic>{
        'orderId': orderId,
        'product': productId,
        'rating': rating,
        'comment': comment,
        if (photoUrls != null && photoUrls.isNotEmpty) 'images': photoUrls,
      };

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
      return true;
    });
  }

  /// Request refund for an order
  Future<Map<String, dynamic>> requestRefund({
    required String orderId,
    required String reason,
    required String description,
    required String refundType,
    List<String>? itemIds,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/orders/$orderId/refund-request');

      final data = <String, dynamic>{
        'reason': reason,
        'description': description,
        'refundType': refundType,
        if (itemIds != null) 'itemIds': itemIds,
      };

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return body['data'] ?? {};
    });
  }
}

// ============================================================================
// RESULT TYPES
// ============================================================================

class OrdersFetchResult {
  final List<OrderModel> orders;
  final int total;
  final int page;
  final int totalPages;

  OrdersFetchResult({
    required this.orders,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}

class OrderStats {
  final int totalOrders;
  final double totalRevenue;
  final int pendingOrders;
  final int completedOrders;
  final int cancelledOrders;
  final double averageOrderValue;

  OrderStats({
    required this.totalOrders,
    required this.totalRevenue,
    required this.pendingOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.averageOrderValue,
  });

  factory OrderStats.fromJson(Map<String, dynamic> json) {
    return OrderStats(
      totalOrders: json['totalOrders'] ?? 0,
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      pendingOrders: json['pendingOrders'] ?? 0,
      completedOrders: json['completedOrders'] ?? 0,
      cancelledOrders: json['cancelledOrders'] ?? 0,
      averageOrderValue: (json['averageOrderValue'] ?? 0).toDouble(),
    );
  }
}
