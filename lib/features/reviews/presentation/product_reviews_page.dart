// lib/features/reviews/presentation/product_reviews_page.dart
// Full "See All" reviews page for a product: rating summary, sorting,
// helpful voting, vendor replies, pagination, and write-a-review.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/reviews_repository.dart';
import '../providers/reviews_provider.dart';
import 'reviews_widgets.dart';
import '../../auth/data/providers.dart';

/// Sort options mapped to the backend `sortBy` query values.
enum _ReviewSort { helpful, recent, ratingHigh, ratingLow }

extension _ReviewSortX on _ReviewSort {
  String get apiValue => switch (this) {
        _ReviewSort.helpful => 'helpful',
        _ReviewSort.recent => 'recent',
        _ReviewSort.ratingHigh => 'rating_high',
        _ReviewSort.ratingLow => 'rating_low',
      };

  String get label => switch (this) {
        _ReviewSort.helpful => 'Most helpful',
        _ReviewSort.recent => 'Most recent',
        _ReviewSort.ratingHigh => 'Highest rated',
        _ReviewSort.ratingLow => 'Lowest rated',
      };
}

class ProductReviewsPage extends ConsumerStatefulWidget {
  final String productId;
  final String? productName;

  const ProductReviewsPage({
    super.key,
    required this.productId,
    this.productName,
  });

  @override
  ConsumerState<ProductReviewsPage> createState() => _ProductReviewsPageState();
}

class _ProductReviewsPageState extends ConsumerState<ProductReviewsPage> {
  static const _pageSize = 10;

  final _reviews = <ReviewModel>[];
  final _scrollController = ScrollController();

  _ReviewSort _sort = _ReviewSort.helpful;
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _reviews.clear();
      _page = 1;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final result = await ref.read(reviewsRepositoryProvider).getProductReviews(
            productId: widget.productId,
            page: _page,
            limit: _pageSize,
            sortBy: _sort.apiValue,
          );
      if (!mounted) return;
      setState(() {
        _reviews.addAll(result.reviews);
        _hasMore = result.reviews.length == _pageSize;
        _page += 1;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(productRatingSummaryProvider(widget.productId));
    await _loadFirstPage();
  }

  void _changeSort(_ReviewSort sort) {
    if (sort == _sort) return;
    setState(() => _sort = sort);
    _loadFirstPage();
  }

  Future<void> _voteHelpful(ReviewModel review) async {
    final ok = await ref.read(reviewsActionsProvider).voteHelpful(review.id);
    if (!mounted) return;
    if (ok) {
      // Reflect the vote locally without a full reload.
      final i = _reviews.indexWhere((r) => r.id == review.id);
      if (i != -1) {
        setState(() {
          _reviews[i] = ReviewModel(
            id: review.id,
            productId: review.productId,
            userId: review.userId,
            userName: review.userName,
            userPhoto: review.userPhoto,
            rating: review.rating,
            title: review.title,
            comment: review.comment,
            createdAt: review.createdAt,
            helpfulCount: review.helpfulCount + 1,
            isVerifiedBuyer: review.isVerifiedBuyer,
            vendorResponseText: review.vendorResponseText,
            vendorResponseBy: review.vendorResponseBy,
            vendorResponseAt: review.vendorResponseAt,
          );
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not record your vote')),
      );
    }
  }

  void _openWriteReview() {
    final isLoggedIn = ref.read(authNotifierProvider).user != null;
    if (!isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to write a review')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => WriteReviewDialog(
        productId: widget.productId,
        onSuccess: _refresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync =
        ref.watch(productRatingSummaryProvider(widget.productId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Reviews'),
            if (widget.productName != null && widget.productName!.isNotEmpty)
              Text(
                widget.productName!,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          // header + sort + reviews + footer
          itemCount: _reviews.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildHeader(summaryAsync);
            }
            if (index <= _reviews.length) {
              final review = _reviews[index - 1];
              return ReviewCard(
                review: review,
                onHelpfulTap: () => _voteHelpful(review),
              );
            }
            return _buildFooter();
          },
        ),
      ),
    );
  }

  Widget _buildHeader(AsyncValue<ProductRatingSummary> summaryAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        summaryAsync.when(
          data: (summary) => summary.totalReviews == 0
              ? const SizedBox.shrink()
              : Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: RatingBreakdown(
                      averageRating: summary.averageRating,
                      totalReviews: summary.totalReviews,
                      distribution: summary.distribution,
                    ),
                  ),
                ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openWriteReview,
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: const Text('Write a Review'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.sort, size: 18),
            const SizedBox(width: 8),
            const Text('Sort by:'),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<_ReviewSort>(
                value: _sort,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                onChanged: (s) => s == null ? null : _changeSort(s),
                items: _ReviewSort.values
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.label),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildFooter() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Unable to load reviews'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadFirstPage,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_reviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.reviews_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text('No reviews yet. Be the first!',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text("You've reached the end",
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}
