// trenda_shared/lib/data/approval_repository.dart
// Repository for vendor approval requests

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'base_repository.dart';
import '../models/approval_model.dart';

class ApprovalRepository extends BaseRepository {
  ApprovalRepository({super.baseUrl});

  /// Submit store settings for approval
  Future<ApprovalRequest> submitStoreSettingsApproval({
    required String storeName,
    String? storeDescription,
    String? storeAddress,
    String? contactPhone,
    String? contactEmail,
    Map<String, dynamic>? openingHours,
    double? deliveryRadius,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/approval/store-settings');

      final data = <String, dynamic>{
        'storeName': storeName,
        if (storeDescription != null) 'storeDescription': storeDescription,
        if (storeAddress != null) 'storeAddress': storeAddress,
        if (contactPhone != null) 'contactPhone': contactPhone,
        if (contactEmail != null) 'contactEmail': contactEmail,
        if (openingHours != null) 'openingHours': openingHours,
        if (deliveryRadius != null) 'deliveryRadius': deliveryRadius,
      };

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ApprovalRequest.fromJson(body['data']);
    });
  }

  /// Submit account settings for approval
  Future<ApprovalRequest> submitAccountSettingsApproval({
    String? ownerName,
    String? phone,
    String? birthday,
    String? sex,
    String? profilePicture,
    String? region,
    String? municipality,
    String? barangay,
    String? streetHouseNo,
    String? landmark,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/approval/account-settings');

      final data = <String, dynamic>{
        if (ownerName != null) 'ownerName': ownerName,
        if (phone != null) 'phone': phone,
        if (birthday != null) 'birthday': birthday,
        if (sex != null) 'sex': sex,
        if (profilePicture != null) 'profilePicture': profilePicture,
        if (region != null) 'region': region,
        if (municipality != null) 'municipality': municipality,
        if (barangay != null) 'barangay': barangay,
        if (streetHouseNo != null) 'streetHouseNo': streetHouseNo,
        if (landmark != null) 'landmark': landmark,
      };

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ApprovalRequest.fromJson(body['data']);
    });
  }

  /// Get vendor's pending approval requests
  Future<List<ApprovalRequest>> getMyApprovalRequests({
    String status = 'pending',
    int limit = 20,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {'status': status, 'limit': limit.toString()};

      final uri = Uri.parse(
        '$baseUrl/api/vendor/approval/my-requests',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return (body['data'] as List)
          .map((e) => ApprovalRequest.fromJson(e))
          .toList();
    });
  }

  // ==========================================================================
  // ADMIN ENDPOINTS
  // ==========================================================================

  /// Get pending approval requests (Admin)
  Future<ApprovalListResult> getAdminPendingApprovals({
    String? type,
    int page = 1,
    int limit = 20,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (type != null) 'type': type,
      };

      final uri = Uri.parse(
        '$baseUrl/api/admin/approval/pending',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ApprovalListResult.fromJson(body);
    });
  }

  /// Get single approval request details (Admin)
  Future<ApprovalDetailResult> getApprovalRequestDetails(
    String requestId,
  ) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/admin/approval/$requestId');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ApprovalDetailResult.fromJson(body['data']);
    });
  }

  /// Approve a request (Admin)
  Future<ApprovalRequest> approveRequest(
    String requestId, {
    String? adminNotes,
    Map<String, dynamic>? editedData,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/admin/approval/$requestId/approve');

      final data = <String, dynamic>{
        if (adminNotes != null) 'adminNotes': adminNotes,
        if (editedData != null) 'editedData': editedData,
      };

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ApprovalRequest.fromJson(body['data']);
    });
  }

  /// Reject a request (Admin)
  Future<ApprovalRequest> rejectRequest(
    String requestId, {
    String? adminNotes,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/admin/approval/$requestId/reject');

      final data = <String, dynamic>{
        if (adminNotes != null) 'adminNotes': adminNotes,
      };

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ApprovalRequest.fromJson(body['data']);
    });
  }

  /// Get approval statistics (Admin)
  Future<ApprovalStats> getApprovalStats() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/admin/approval/stats');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ApprovalStats.fromJson(body['data']);
    });
  }
}
