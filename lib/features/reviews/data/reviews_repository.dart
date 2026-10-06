// lib/features/reviews/data/reviews_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/data/base_repository.dart';
import 'package:trenda_shared/core/config.dart';

class ReviewsRepository extends BaseRepository {
  ReviewsRepository({super.baseUrl});

  /// Token is optional for the public review endpoints so guests can browse
  /// reviews without being logged in (and without triggering an auto sign-out).
  Future<String?> _optionalToken() async {
    try {
      return await getIdToken();
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _publicHeaders(String? token) => {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Get reviews for a product (public — approved reviews only).
  Future<ReviewsResult> getProductReviews({
    required String productId,
    int page = 1,
    int limit = 10,
    String? sortBy,
  }) async {
    return retryRequest(() async {
      final token = await _optionalToken();

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (sortBy != null) 'sortBy': sortBy,
      };

      final uri = Uri.parse('$baseUrl/api/reviews/product/$productId')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: _publicHeaders(token))
          .timeout(AppConfig.connectTimeout);

      final body = parsePublicResponse(response);

      final reviews =
          (body['data'] as List).map((e) => ReviewModel.fromJson(e)).toList();

      return ReviewsResult(
        reviews: reviews,
        total: body['pagination']?['total'] ?? reviews.length,
        averageRating: body['averageRating']?.toDouble() ?? 0.0,
        ratingDistribution: body['ratingDistribution'] != null
            ? RatingDistribution.fromJson(body['ratingDistribution'])
            : null,
      );
    });
  }

  /// Get the rating summary (average + star distribution) for a product.
  /// Backend: GET /api/reviews/product/:productId/distribution
  Future<ProductRatingSummary> getRatingSummary(String productId) async {
    return retryRequest(() async {
      final token = await _optionalToken();
      final uri =
          Uri.parse('$baseUrl/api/reviews/product/$productId/distribution');

      final response = await http
          .get(uri, headers: _publicHeaders(token))
          .timeout(AppConfig.connectTimeout);

      final body = parsePublicResponse(response);
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final distribution = RatingDistribution.fromJson(data);
      final total = distribution.total;
      final average = total > 0
          ? (distribution.star5 * 5 +
                  distribution.star4 * 4 +
                  distribution.star3 * 3 +
                  distribution.star2 * 2 +
                  distribution.star1) /
              total
          : 0.0;
      return ProductRatingSummary(
        averageRating: average,
        totalReviews: total,
        distribution: distribution,
      );
    });
  }

  /// Create a review
  Future<ReviewModel> createReview({
    required String productId,
    required int rating,
    required String comment,
    String? title,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/reviews');

      final data = {
        'productId': productId,
        'rating': rating,
        'comment': comment,
        if (title != null) 'title': title,
      };

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ReviewModel.fromJson(body['data']);
    });
  }

  /// Vote on a review (helpful/not helpful)
  Future<void> voteOnReview({
    required String reviewId,
    required bool isHelpful,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/reviews/$reviewId/vote');

      final data = {'helpful': isHelpful};

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
    });
  }

  /// Check if user can review a product
  Future<bool> canReviewProduct(String productId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/reviews/can-review/$productId');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return body['canReview'] ?? false;
    });
  }
}

/// Review model
class ReviewModel {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final String? userPhoto;
  final int rating;
  final String? title;
  final String comment;
  final DateTime createdAt;
  final int helpfulCount;
  final bool? isVerifiedBuyer;
  // Vendor's public reply (wires trenda_vendor → trenda_frontend).
  final String? vendorResponseText;
  final String? vendorResponseBy;
  final DateTime? vendorResponseAt;

  ReviewModel({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.rating,
    this.title,
    required this.comment,
    required this.createdAt,
    required this.helpfulCount,
    this.isVerifiedBuyer,
    this.vendorResponseText,
    this.vendorResponseBy,
    this.vendorResponseAt,
  });

  bool get hasVendorResponse =>
      vendorResponseText != null && vendorResponseText!.trim().isNotEmpty;

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final vr = json['vendorResponse'];
    final respondedBy = vr is Map ? vr['respondedBy'] : null;
    return ReviewModel(
      id: json['_id'] ?? json['id'],
      productId: json['productId'] ?? json['product'],
      userId: json['userId'] ?? json['user']?['_id'] ?? '',
      userName: json['userName'] ?? json['user']?['name'] ?? 'Anonymous',
      userPhoto: json['userPhoto'] ?? json['user']?['photoUrl'],
      rating: json['rating'] ?? 0,
      title: json['title'],
      comment: json['comment'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      helpfulCount: json['helpfulCount'] ?? json['helpful'] ?? 0,
      isVerifiedBuyer: json['isVerifiedBuyer'] ?? json['verifiedPurchase'],
      vendorResponseText: vr is Map ? vr['text'] as String? : null,
      vendorResponseBy: respondedBy is Map
          ? (respondedBy['vendorProfile']?['storeName'] ??
              respondedBy['name']) as String?
          : null,
      vendorResponseAt: vr is Map && vr['respondedAt'] != null
          ? DateTime.tryParse(vr['respondedAt'].toString())
          : null,
    );
  }
}

/// Rating distribution model
class RatingDistribution {
  final int star5;
  final int star4;
  final int star3;
  final int star2;
  final int star1;

  RatingDistribution({
    required this.star5,
    required this.star4,
    required this.star3,
    required this.star2,
    required this.star1,
  });

  factory RatingDistribution.fromJson(Map<String, dynamic> json) {
    return RatingDistribution(
      star5: json['5'] ?? json['star5'] ?? 0,
      star4: json['4'] ?? json['star4'] ?? 0,
      star3: json['3'] ?? json['star3'] ?? 0,
      star2: json['2'] ?? json['star2'] ?? 0,
      star1: json['1'] ?? json['star1'] ?? 0,
    );
  }

  int get total => star5 + star4 + star3 + star2 + star1;
}

/// Product rating summary (average + distribution) for the reviews header.
class ProductRatingSummary {
  final double averageRating;
  final int totalReviews;
  final RatingDistribution distribution;

  ProductRatingSummary({
    required this.averageRating,
    required this.totalReviews,
    required this.distribution,
  });
}

/// Reviews result
class ReviewsResult {
  final List<ReviewModel> reviews;
  final int total;
  final double averageRating;
  final RatingDistribution? ratingDistribution;

  ReviewsResult({
    required this.reviews,
    required this.total,
    required this.averageRating,
    this.ratingDistribution,
  });
}
