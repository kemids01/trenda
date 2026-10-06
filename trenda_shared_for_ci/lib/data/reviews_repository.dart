// trenda_shared/lib/data/reviews_repository.dart
// Reviews repository for vendor reviews management

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'base_repository.dart';
import '../models/review_model.dart';

class ReviewsRepository extends BaseRepository {
  ReviewsRepository({super.baseUrl});

  /// Get vendor's product reviews
  Future<ReviewsFetchResult> getVendorReviews({
    int page = 1,
    int limit = 20,
    String? productId,
    int? rating,
    bool? hasResponse,
    String? sortBy,
    String? sortOrder,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (productId != null) 'productId': productId,
        if (rating != null) 'rating': rating.toString(),
        if (hasResponse != null) 'hasResponse': hasResponse.toString(),
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

      final uri = Uri.parse(
        '$baseUrl/api/vendor/reviews',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      final reviews = (body['data'] as List)
          .map((e) => ReviewModel.fromJson(e))
          .toList();

      ReviewStats? stats;
      if (body['stats'] != null) {
        stats = ReviewStats.fromJson(body['stats']);
      }

      return ReviewsFetchResult(
        reviews: reviews,
        total: body['pagination']?['total'] ?? reviews.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
        stats: stats,
      );
    });
  }

  /// Get review by ID
  Future<ReviewModel> getReviewById(String reviewId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/reviews/$reviewId');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ReviewModel.fromJson(body['data']);
    });
  }

  /// Respond to a review
  Future<ReviewModel> respondToReview(String reviewId, String response) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/reviews/$reviewId/respond');

      final res = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({'response': response}),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(res);
      return ReviewModel.fromJson(body['data']);
    });
  }

  /// Update review response
  Future<ReviewModel> updateReviewResponse(
    String reviewId,
    String response,
  ) async {
    return retryRequest(() async {
      final token = await getIdToken();
      // Backend: PUT /api/vendor/reviews/:reviewId/response (NOT /respond,
      // which is the POST create-response route).
      final uri = Uri.parse('$baseUrl/api/vendor/reviews/$reviewId/response');

      final res = await http
          .put(
            uri,
            headers: headers(token),
            body: jsonEncode({'response': response}),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(res);
      return ReviewModel.fromJson(body['data']);
    });
  }

  /// Delete review response
  Future<ReviewModel> deleteReviewResponse(String reviewId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      // Backend: DELETE /api/vendor/reviews/:reviewId/response
      final uri = Uri.parse('$baseUrl/api/vendor/reviews/$reviewId/response');

      final response = await http
          .delete(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ReviewModel.fromJson(body['data']);
    });
  }

  /// Get review statistics
  Future<ReviewStats> getReviewStats({String? productId}) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (productId != null) queryParams['productId'] = productId;

      final uri = Uri.parse(
        '$baseUrl/api/vendor/reviews/analytics',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ReviewStats.fromJson(body['data']);
    });
  }

  /// Report a review
  Future<bool> reportReview(String reviewId, String reason) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/reviews/$reviewId/report');

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({'reason': reason}),
          )
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
      return true;
    });
  }
}
