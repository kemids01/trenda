// lib/features/orders/data/orders_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/core/config.dart';
import '../../core/utils/network_utils.dart';

/// The rows of `GET /api/returns/my-returns`.
///
/// The route answers with `ApiResponse.paginated`, which puts the ARRAY in `data`
/// (pagination is a sibling). This used to read `returns`, a key the server never
/// sends, so My Returns was empty for every customer. `returns` / `data.returns`
/// are still accepted in case the route is ever moved to `.success({returns})`.
List<dynamic> returnsFromResponse(Map<String, dynamic> body) {
  final data = body['data'];
  if (data is List) return data;
  if (data is Map && data['returns'] is List) return data['returns'] as List;
  final legacy = body['returns'];
  if (legacy is List) return legacy;
  return const [];
}

/// The server's own explanation for a refused request, or [fallback].
///
/// Without it every refusal read "Failed to cancel return", and the customer could
/// not tell "not allowed at this stage" from "no signal".
String serverMessage(http.Response? response, String fallback) {
  if (response == null) return '$fallback. Check your connection and try again.';
  try {
    final body = jsonDecode(response.body);
    if (body is Map && body['message'] is String) {
      final message = (body['message'] as String).trim();
      if (message.isNotEmpty) return message;
    }
  } catch (_) {
    // Not JSON (an HTML error page from the host) — fall through.
  }
  return fallback;
}

class OrdersRepository {
  final String baseUrl = AppConfig.backendBaseUrl;

  /// Request a refund for an order
  Future<Map<String, dynamic>> requestRefund({
    required String orderId,
    required String reason,
    required String description,
    required String refundType,
    List<String>? itemIds,
  }) async {
    final response = await NetworkUtils.postJson(
      '$baseUrl/api/orders/$orderId/refund-request',
      {
        'reason': reason,
        'description': description,
        'refundType': refundType,
        if (itemIds != null) 'itemIds': itemIds,
      },
    );

    if (response == null || response.statusCode != 200) {
      throw Exception(serverMessage(response, 'Failed to submit refund request'));
    }

    final body = jsonDecode(response.body);
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Refund request failed');
    }

    return body['data'] ?? {};
  }

  /// Create a product return/exchange request
  Future<Map<String, dynamic>> createReturn({
    required String orderId,
    required List<Map<String, dynamic>> items,
    List<String>? images,
    String? customerNotes,
    String type = 'return', // 'return' or 'exchange'
  }) async {
    final response = await NetworkUtils.postJson(
      '$baseUrl/api/returns',
      {
        'orderId': orderId,
        'items': items,
        'type': type,
        if (images != null) 'images': images,
        if (customerNotes != null) 'customerNotes': customerNotes,
      },
    );

    if (response == null ||
        response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(serverMessage(response, 'Failed to submit return request'));
    }

    final body = jsonDecode(response.body);
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Return request failed');
    }

    return body['data'] ?? {};
  }

  /// Get customer's return requests
  Future<List<dynamic>> getMyReturns({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) query['status'] = status;

    final queryString =
        query.entries.map((e) => '${e.key}=${e.value}').join('&');
    final response = await NetworkUtils.getJson(
      '$baseUrl/api/returns/my-returns?$queryString',
    );
    return returnsFromResponse(response);
  }

  /// Cancel a return request
  Future<void> cancelReturn(String returnId, {String? reason}) async {
    final response = await NetworkUtils.putJson(
      '$baseUrl/api/returns/$returnId/cancel',
      {'reason': reason ?? 'Cancelled by customer'},
    );

    if (response == null || response.statusCode != 200) {
      throw Exception(serverMessage(response, 'Failed to cancel return'));
    }
  }
}
