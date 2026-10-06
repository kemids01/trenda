// lib/features/reviews/providers/reviews_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/core/logger.dart';
import 'package:trenda_shared/core/config.dart';
import '../data/reviews_repository.dart';

/// Repository provider
final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  return ReviewsRepository(baseUrl: AppConfig.backendBaseUrl);
});

/// Get product reviews
final productReviewsProvider = FutureProvider.family<ReviewsResult, String>(
  (ref, productId) async {
    final repo = ref.watch(reviewsRepositoryProvider);
    return await repo.getProductReviews(productId: productId);
  },
);

/// Product rating summary (average + star distribution) for the reviews header.
final productRatingSummaryProvider =
    FutureProvider.family<ProductRatingSummary, String>(
  (ref, productId) async {
    final repo = ref.watch(reviewsRepositoryProvider);
    return await repo.getRatingSummary(productId);
  },
);

/// Check if user can review
final canReviewProductProvider = FutureProvider.family<bool, String>(
  (ref, productId) async {
    final repo = ref.watch(reviewsRepositoryProvider);
    try {
      return await repo.canReviewProduct(productId);
    } catch (e) {
      return false;
    }
  },
);

/// Reviews actions
class ReviewsActions {
  final ReviewsRepository _repository;

  ReviewsActions(this._repository);

  Future<ReviewModel?> submitReview({
    required String productId,
    required int rating,
    required String comment,
    String? title,
  }) async {
    try {
      return await _repository.createReview(
        productId: productId,
        rating: rating,
        comment: comment,
        title: title,
      );
    } catch (e) {
      AppLogger.error('Error submitting review', e);
      return null;
    }
  }

  Future<bool> voteHelpful(String reviewId) async {
    try {
      await _repository.voteOnReview(reviewId: reviewId, isHelpful: true);
      return true;
    } catch (e) {
      AppLogger.error('Error voting on review', e);
      return false;
    }
  }
}

final reviewsActionsProvider = Provider<ReviewsActions>((ref) {
  return ReviewsActions(ref.read(reviewsRepositoryProvider));
});
