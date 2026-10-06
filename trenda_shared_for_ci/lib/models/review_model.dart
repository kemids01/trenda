// trenda_shared/lib/models/review_model.dart
// Review model for reviews management

class ReviewModel {
  final String id;
  final String productId;
  final String productName;
  final String? productImage;
  final String customerId;
  final String customerName;
  final String? customerAvatar;
  final String? orderId;
  final double rating;
  final String? title;
  final String comment;
  final List<String> images;
  final bool verified;
  final int helpfulCount;
  final VendorResponse? vendorResponse;
  final ReviewStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReviewModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImage,
    required this.customerId,
    required this.customerName,
    this.customerAvatar,
    this.orderId,
    required this.rating,
    this.title,
    required this.comment,
    this.images = const [],
    this.verified = false,
    this.helpfulCount = 0,
    this.vendorResponse,
    this.status = ReviewStatus.published,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    // Handle productId which can be either a string or a populated object
    String productId = '';
    String productName = json['productName'] ?? '';
    String? productImage = json['productImage'];

    if (json['product'] != null) {
      if (json['product'] is String) {
        productId = json['product'];
      } else if (json['product'] is Map<String, dynamic>) {
        final product = json['product'] as Map<String, dynamic>;
        productId = product['_id'] ?? product['id'] ?? '';
        productName = productName.isEmpty
            ? (product['name'] ?? '')
            : productName;
        productImage =
            productImage ?? (product['images'] as List?)?.firstOrNull;
      }
    }
    productId = productId.isEmpty ? (json['productId'] ?? '') : productId;

    // Handle customerId which can be either a string or a populated object
    String customerId = '';
    String customerName = json['customerName'] ?? 'Anonymous';
    String? customerAvatar = json['customerAvatar'];

    if (json['customer'] != null) {
      if (json['customer'] is String) {
        customerId = json['customer'];
      } else if (json['customer'] is Map<String, dynamic>) {
        final customer = json['customer'] as Map<String, dynamic>;
        customerId = customer['_id'] ?? customer['id'] ?? '';
        customerName = customerName == 'Anonymous'
            ? (customer['name'] ?? customer['displayName'] ?? 'Anonymous')
            : customerName;
        customerAvatar =
            customerAvatar ?? customer['avatar'] ?? customer['photoURL'];
      }
    }
    customerId = customerId.isEmpty ? (json['customerId'] ?? '') : customerId;

    return ReviewModel(
      id: json['_id'] ?? json['id'] ?? '',
      productId: productId,
      productName: productName,
      productImage: productImage,
      customerId: customerId,
      customerName: customerName,
      customerAvatar: customerAvatar,
      orderId: json['orderId'] is String
          ? json['orderId']
          : (json['orderId']?['_id']),
      rating: (json['rating'] ?? 0).toDouble(),
      title: json['title'],
      comment: json['comment'] ?? json['review'] ?? '',
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      verified: json['verified'] ?? json['verifiedPurchase'] ?? false,
      helpfulCount: json['helpfulCount'] ?? 0,
      vendorResponse: json['vendorResponse'] != null
          ? VendorResponse.fromJson(json['vendorResponse'])
          : null,
      status: ReviewStatus.fromString(json['status'] ?? 'published'),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  bool get hasVendorResponse => vendorResponse != null;
  bool get isPositive => rating >= 4;
  bool get isNegative => rating <= 2;
  bool get isNeutral => rating > 2 && rating < 4;

  String get ratingText {
    if (rating >= 4.5) return 'Excellent';
    if (rating >= 4) return 'Great';
    if (rating >= 3) return 'Good';
    if (rating >= 2) return 'Fair';
    return 'Poor';
  }
}

class VendorResponse {
  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;

  VendorResponse({required this.text, required this.createdAt, this.updatedAt});

  factory VendorResponse.fromJson(Map<String, dynamic> json) {
    return VendorResponse(
      text: json['text'] ?? json['response'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }
}

enum ReviewStatus {
  pending('pending'),
  published('published'),
  hidden('hidden'),
  flagged('flagged'),
  removed('removed');

  final String value;
  const ReviewStatus(this.value);

  static ReviewStatus fromString(String value) {
    return ReviewStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReviewStatus.published,
    );
  }
}

class ReviewStats {
  final int totalReviews;
  final double averageRating;
  final int fiveStarCount;
  final int fourStarCount;
  final int threeStarCount;
  final int twoStarCount;
  final int oneStarCount;
  final int pendingResponseCount;
  final int respondedCount;
  final double responseRate;

  ReviewStats({
    this.totalReviews = 0,
    this.averageRating = 0,
    this.fiveStarCount = 0,
    this.fourStarCount = 0,
    this.threeStarCount = 0,
    this.twoStarCount = 0,
    this.oneStarCount = 0,
    this.pendingResponseCount = 0,
    this.respondedCount = 0,
    this.responseRate = 0,
  });

  factory ReviewStats.fromJson(Map<String, dynamic> json) {
    return ReviewStats(
      totalReviews: json['totalReviews'] ?? 0,
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      fiveStarCount: json['fiveStarCount'] ?? json['5'] ?? 0,
      fourStarCount: json['fourStarCount'] ?? json['4'] ?? 0,
      threeStarCount: json['threeStarCount'] ?? json['3'] ?? 0,
      twoStarCount: json['twoStarCount'] ?? json['2'] ?? 0,
      oneStarCount: json['oneStarCount'] ?? json['1'] ?? 0,
      pendingResponseCount: json['pendingResponseCount'] ?? 0,
      respondedCount: json['respondedCount'] ?? 0,
      responseRate: (json['responseRate'] ?? 0).toDouble(),
    );
  }

  int get positiveCount => fiveStarCount + fourStarCount;
  int get negativeCount => oneStarCount + twoStarCount;

  double get fiveStarPercentage =>
      totalReviews > 0 ? (fiveStarCount / totalReviews) * 100 : 0;
  double get fourStarPercentage =>
      totalReviews > 0 ? (fourStarCount / totalReviews) * 100 : 0;
  double get threeStarPercentage =>
      totalReviews > 0 ? (threeStarCount / totalReviews) * 100 : 0;
  double get twoStarPercentage =>
      totalReviews > 0 ? (twoStarCount / totalReviews) * 100 : 0;
  double get oneStarPercentage =>
      totalReviews > 0 ? (oneStarCount / totalReviews) * 100 : 0;
}

class ReviewsFetchResult {
  final List<ReviewModel> reviews;
  final int total;
  final int page;
  final int totalPages;
  final ReviewStats? stats;

  ReviewsFetchResult({
    required this.reviews,
    required this.total,
    required this.page,
    required this.totalPages,
    this.stats,
  });

  bool get hasMore => page < totalPages;
}
