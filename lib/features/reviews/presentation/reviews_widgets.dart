// lib/features/reviews/presentation/reviews_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/reviews_repository.dart';
import '../providers/reviews_provider.dart';
import '../../../design_system/design_system.dart';
import 'package:trenda_shared/core/timezone.dart';
import 'package:intl/intl.dart';
import 'package:trenda_shared/core/taps/taps.dart';

/// Rating breakdown widget showing star distribution
class RatingBreakdown extends StatelessWidget {
  final double averageRating;
  final int totalReviews;
  final RatingDistribution? distribution;

  const RatingBreakdown({
    super.key,
    required this.averageRating,
    required this.totalReviews,
    this.distribution,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Average rating
        Column(
          children: [
            Text(
              averageRating.toStringAsFixed(1),
              style: AppTypography.displaySmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < averageRating.round()
                      ? Icons.star
                      : Icons.star_border,
                  color: AppColors.starFilled,
                  size: 16,
                );
              }),
            ),
            AppSpacing.verticalXXS,
            Text(
              '$totalReviews reviews',
              style: AppTypography.asSecondary(AppTypography.bodySmall),
            ),
          ],
        ),
        AppSpacing.horizontalLG,
        // Distribution bars
        if (distribution != null)
          Expanded(
            child: Column(
              children: [
                _buildRatingBar(5, distribution!.star5, distribution!.total),
                _buildRatingBar(4, distribution!.star4, distribution!.total),
                _buildRatingBar(3, distribution!.star3, distribution!.total),
                _buildRatingBar(2, distribution!.star2, distribution!.total),
                _buildRatingBar(1, distribution!.star1, distribution!.total),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRatingBar(int stars, int count, int total) {
    final percentage = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$stars',
            style: AppTypography.bodySmall,
          ),
          const Icon(Icons.star, size: 12, color: Colors.amber),
          AppSpacing.horizontalXS,
          Expanded(
            child: ClipRRect(
              borderRadius: AppSpacing.borderRadiusSM,
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.starFilled),
                minHeight: 8,
              ),
            ),
          ),
          AppSpacing.horizontalXS,
          SizedBox(
            width: 32,
            child: Text(
              '${(percentage * 100).round()}%',
              style: AppTypography.bodySmall,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single review card widget
class ReviewCard extends ConsumerWidget {
  final ReviewModel review;
  final VoidCallback? onHelpfulTap;

  const ReviewCard({
    super.key,
    required this.review,
    this.onHelpfulTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: User info + rating
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryContainer,
                  backgroundImage: review.userPhoto != null
                      ? NetworkImage(review.userPhoto!)
                      : null,
                  child: review.userPhoto == null
                      ? Text(
                          review.userName[0].toUpperCase(),
                          style: AppTypography.titleSmall,
                        )
                      : null,
                ),
                AppSpacing.horizontalSM,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            review.userName,
                            style: AppTypography.titleSmall,
                          ),
                          if (review.isVerifiedBuyer == true) ...[
                            AppSpacing.horizontalXS,
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.successContainer,
                                borderRadius: AppSpacing.borderRadiusSM,
                              ),
                              child: Text(
                                'Verified',
                                style: AppTypography.withColor(
                                  AppTypography.labelSmall,
                                  AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < review.rating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: AppColors.starFilled,
                              size: 14,
                            );
                          }),
                          AppSpacing.horizontalXS,
                          Text(
                            _formatDate(review.createdAt),
                            style: AppTypography.asTertiary(
                                AppTypography.bodySmall),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.verticalSM,
            // Title (if any)
            if (review.title != null && review.title!.isNotEmpty) ...[
              Text(
                review.title!,
                style: AppTypography.titleSmall,
              ),
              AppSpacing.verticalXXS,
            ],
            // Comment
            Text(
              review.comment,
              style: AppTypography.bodyMedium,
            ),
            AppSpacing.verticalSM,
            // Footer: Helpful button
            Row(
              children: [
                TextButton.icon(
                  onPressed: onHelpfulTap,
                  icon: const Icon(Icons.thumb_up_outlined, size: 16),
                  label: Text('Helpful (${review.helpfulCount})'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    textStyle: AppTypography.labelSmall,
                  ),
                ),
              ],
            ),
            // Vendor's public reply (from trenda_vendor).
            if (review.hasVendorResponse) ...[
              AppSpacing.verticalXS,
              Container(
                width: double.infinity,
                padding: AppSpacing.paddingCard,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: AppSpacing.borderRadiusSM,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront,
                            size: 14, color: AppColors.primary),
                        AppSpacing.horizontalXS,
                        Expanded(
                          child: Text(
                            'Response from ${review.vendorResponseBy ?? 'Seller'}',
                            style: AppTypography.withColor(
                              AppTypography.labelMedium,
                              AppColors.primary,
                            ),
                          ),
                        ),
                        if (review.vendorResponseAt != null)
                          Text(
                            _formatDate(review.vendorResponseAt!),
                            style: AppTypography.asTertiary(
                                AppTypography.bodySmall),
                          ),
                      ],
                    ),
                    AppSpacing.verticalXXS,
                    Text(
                      review.vendorResponseText!,
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} weeks ago';
    } else {
      return DateFormat('d/M/y').formatPh(date);
    }
  }
}

/// Write review dialog
class WriteReviewDialog extends ConsumerStatefulWidget {
  final String productId;
  final VoidCallback? onSuccess;

  const WriteReviewDialog({
    super.key,
    required this.productId,
    this.onSuccess,
  });

  @override
  ConsumerState<WriteReviewDialog> createState() => _WriteReviewDialogState();
}

class _WriteReviewDialogState extends ConsumerState<WriteReviewDialog> {
  int _rating = 0;
  final _titleController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      setState(() => _error = 'Please select a rating');
      return;
    }
    if (_commentController.text.trim().length < 10) {
      setState(() => _error = 'Review must be at least 10 characters');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final actions = ref.read(reviewsActionsProvider);
      final result = await actions.submitReview(
        productId: widget.productId,
        rating: _rating,
        comment: _commentController.text.trim(),
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
      );

      if (!mounted) return;

      if (result != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Review submitted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onSuccess?.call();
      } else {
        setState(() => _error = 'Failed to submit review. Please try again.');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Write a Review'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Star rating selector
            Text('Rating', style: AppTypography.titleSmall),
            AppSpacing.verticalXS,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: () => setState(() => _rating = index + 1),
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: AppColors.starFilled,
                    size: 36,
                  ),
                );
              }),
            ),
            AppSpacing.verticalMD,
            // Title (optional)
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                hintText: 'Summarize your review',
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
            ),
            AppSpacing.verticalSM,
            // Comment (required)
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Your Review',
                hintText: 'Share your experience with this product',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              maxLength: 500,
            ),
            if (_error != null) ...[
              AppSpacing.verticalXS,
              Text(
                _error!,
                style: AppTypography.withColor(
                  AppTypography.bodySmall,
                  AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : () => TapGuard.run('reviews_widgets.submitReview', _submitReview),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
