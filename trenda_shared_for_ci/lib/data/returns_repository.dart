// trenda_shared/lib/data/returns_repository.dart
// Returns repository for vendor returns management

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'base_repository.dart';
import '../models/return_model.dart';

class ReturnsRepository extends BaseRepository {
  ReturnsRepository({super.baseUrl});

  /// Get vendor's returns
  Future<ReturnsFetchResult> getVendorReturns({
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
        '$baseUrl/api/returns/vendor/my-returns',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      final returns = (body['data'] as List)
          .map((e) => ReturnModel.fromJson(e))
          .toList();

      return ReturnsFetchResult(
        returns: returns,
        total: body['pagination']?['total'] ?? returns.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  /// Get return by ID
  Future<ReturnModel> getReturnById(String returnId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/returns/$returnId');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ReturnModel.fromJson(body['data']);
    });
  }

  /// Update vendor notes on a return
  Future<ReturnModel> updateVendorNotes(String returnId, String notes) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/returns/$returnId/vendor-notes');

      final response = await http
          .put(uri, headers: headers(token), body: jsonEncode({'notes': notes}))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ReturnModel.fromJson(body['data']);
    });
  }

  /// Approve a return request
  Future<ReturnModel> approveReturn({
    required String returnId,
    required double refundAmount,
    required String refundMethod,
    String? vendorNotes,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/returns/$returnId/approve');

      final response = await http
          .put(
            uri,
            headers: headers(token),
            body: jsonEncode({
              'refundAmount': refundAmount,
              'refundMethod': refundMethod,
              if (vendorNotes != null) 'vendorNotes': vendorNotes,
            }),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ReturnModel.fromJson(body['data']);
    });
  }

  /// Reject a return request
  Future<ReturnModel> rejectReturn({
    required String returnId,
    required String reason,
    String? vendorNotes,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/returns/$returnId/reject');

      final response = await http
          .put(
            uri,
            headers: headers(token),
            body: jsonEncode({
              'rejectionReason': reason,
              if (vendorNotes != null) 'vendorNotes': vendorNotes,
            }),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ReturnModel.fromJson(body['data']);
    });
  }
}

class ReturnsFetchResult {
  final List<ReturnModel> returns;
  final int total;
  final int page;
  final int totalPages;

  ReturnsFetchResult({
    required this.returns,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}
