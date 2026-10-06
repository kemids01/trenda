// trenda_shared/lib/data/verification_repository.dart
// Repository for vendor verification/onboarding

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../core/config.dart';
import '../core/images/picked_image.dart';
import 'base_repository.dart';
import '../models/verification_model.dart';

class VerificationRepository extends BaseRepository {
  VerificationRepository({super.baseUrl});

  /// Start verification process
  Future<VendorVerification> startVerification() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/verification/start');

      final response = await http
          .post(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return VendorVerification.fromJson(body['data']);
    });
  }

  /// Get verification status
  Future<VendorVerification> getVerificationStatus() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/verification/status');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return VendorVerification.fromJson(body['data']);
    });
  }

  /// Update business information
  Future<VendorVerification> updateBusinessInfo(BusinessInfo info) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/verification/business-info');

      final response = await http
          .put(uri, headers: headers(token), body: jsonEncode(info.toJson()))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return VendorVerification.fromJson(body['data']);
    });
  }

  /// Upload verification document (web-safe, bytes-based)
  Future<VerificationDocument> uploadDocument({
    required String type,
    required PickedImage file,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/verification/upload-document');

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['type'] = type;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes,
          filename: file.filename,
          contentType: MediaType.parse(file.mimeType),
        ),
      );

      final streamedResponse = await request.send().timeout(
        AppConfig.connectTimeout,
      );
      final response = await http.Response.fromStream(streamedResponse);

      final body = parseResponse(response);
      return VerificationDocument.fromJson(body['data']);
    });
  }

  /// Delete a document
  Future<void> deleteDocument(String documentId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse(
        '$baseUrl/api/vendor/verification/documents/$documentId',
      );

      final response = await http
          .delete(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
    });
  }

  /// Update bank details
  Future<VendorVerification> updateBankDetails(BankDetails details) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/verification/bank-details');

      final response = await http
          .put(uri, headers: headers(token), body: jsonEncode(details.toJson()))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return VendorVerification.fromJson(body['data']);
    });
  }

  /// Submit verification for review
  Future<VendorVerification> submitVerification() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/verification/submit');

      final response = await http
          .post(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return VendorVerification.fromJson(body['data']);
    });
  }

  /// Resubmit after changes requested
  Future<VendorVerification> resubmitVerification() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/verification/resubmit');

      final response = await http
          .post(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return VendorVerification.fromJson(body['data']);
    });
  }
}
