import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_shared/models/ad_model.dart';
import 'package:trenda_shared/models/ad_placement.dart' show kAdListingImageAspect;
import 'package:trenda_shared/data/ads_repository.dart';
import 'package:trenda_frontend/features/ads/providers/ads_provider.dart';
import 'package:trenda_frontend/widgets/ad_transparency_modal.dart';
import '../../core/router/app_router.dart';

typedef AdTapCallback = void Function(AdModel ad);

class AdsTab extends ConsumerStatefulWidget {
  final AdTapCallback? onAdTap;

  /// Which lane this is: [AdKind.vendor] (the Ads button) or [AdKind.service]
  /// (the Services button). The two render identically — same cards, same
  /// search, same impression tracking — and differ only in what they list and
  /// what they call it.
  final String kind;

  const AdsTab({
    super.key,
    this.onAdTap,
    this.kind = AdKind.vendor,
  });

  @override
  ConsumerState<AdsTab> createState() => _AdsTabState();
}

class _AdsTabState extends ConsumerState<AdsTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final Set<String> _trackedImpressions = {};
  Timer? _debounce;
  bool _showSearch = false;

  @override
  bool get wantKeepAlive => true;

  /// What this lane calls its rows, so one widget can say "ads" or "services"
  /// without a second copy of the page.
  bool get _isServices => widget.kind == AdKind.service;
  String get _plural => _isServices ? 'services' : 'ads';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(paginatedAdsProvider(widget.kind).notifier).loadMore();
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(paginatedAdsProvider(widget.kind).notifier).search(query);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    ref.read(paginatedAdsProvider(widget.kind).notifier).clearSearch();
    setState(() => _showSearch = false);
  }

  Future<void> _refreshAds() async {
    await ref.read(paginatedAdsProvider(widget.kind).notifier).refresh();
  }

  void _trackImpressions(List<AdModel> ads) {
    final newIds = ads
        .map((ad) => ad.id)
        .where((id) => !_trackedImpressions.contains(id))
        .toList();
    if (newIds.isNotEmpty) {
      _trackedImpressions.addAll(newIds);
      try {
        AdsRepository().trackAdViews(newIds);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final adsState = ref.watch(paginatedAdsProvider(widget.kind));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Search Bar
          _buildSearchBar(),

          // Ads Content
          Expanded(
            child: adsState.when(
              loading: () => _buildShimmerLoading(),
              error: (e, _) => _buildErrorState(e),
              data: (state) {
                if (state.isSearching) {
                  return _buildShimmerLoading();
                }
                if (state.ads.isEmpty) {
                  return _buildEmptyState(state.searchQuery);
                }

                _trackImpressions(state.ads);

                return RefreshIndicator(
                  onRefresh: _refreshAds,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Results count when searching
                      if (state.searchQuery.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _buildSearchResultsHeader(state),
                        ),

                      // Featured Ads Carousel
                      if (state.featuredAds.isNotEmpty &&
                          state.searchQuery.isEmpty)
                        SliverToBoxAdapter(
                          child: _buildFeaturedSection(state.featuredAds),
                        ),

                      // Normal Ads Grid/List
                      if (state.normalAds.isNotEmpty ||
                          (state.searchQuery.isNotEmpty &&
                              state.ads.isNotEmpty))
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final displayAds = state.searchQuery.isNotEmpty
                                    ? state.ads
                                    : state.normalAds;
                                if (index >= displayAds.length) return null;
                                final ad = displayAds[index];
                                return _buildAdCard(ad);
                              },
                              childCount: state.searchQuery.isNotEmpty
                                  ? state.ads.length
                                  : state.normalAds.length,
                            ),
                          ),
                        ),

                      // Load More Indicator
                      if (state.isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            ),
                          ),
                        ),

                      // "No more ads" indicator
                      if (!state.hasMore && state.ads.length > 5)
                        SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            alignment: Alignment.center,
                            child: Text(
                              'You\'ve seen all $_plural',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                      // Bottom padding
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 20),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SEARCH BAR
  // ===========================================================================

  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        16,
        10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                onTap: () => setState(() => _showSearch = true),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _isServices
                      ? 'Search services, providers...'
                      : 'Search businesses, products...',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),

          // Cancel button when search is active
          if (_showSearch) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _clearSearch,
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // SEARCH RESULTS HEADER
  // ===========================================================================

  Widget _buildSearchResultsHeader(PaginatedAdsState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '${state.totalAds} result${state.totalAds == 1 ? '' : 's'} for "${state.searchQuery}"',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _clearSearch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Clear',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FEATURED SECTION
  // ===========================================================================

  Widget _buildFeaturedSection(List<AdModel> featuredAds) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.amber.shade400, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.star, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text(
                  'Featured Offers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),
          // Each featured card is 6:5 (a 1200×1000 ad image shows whole): its
          // height follows its width — 92% of the row, less 8px margins each
          // side — plus the 8px top and bottom margins.
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
            height: (constraints.maxWidth * 0.92 - 16) / kAdListingImageAspect + 16,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.92),
              padEnds: false,
              itemCount: featuredAds.length,
              itemBuilder: (context, index) {
                final ad = featuredAds[index];
                return GestureDetector(
                  onTap: () => context.push(Routes.adDetails, extra: ad),
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Colors.amber.shade400, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _buildAdCardContent(ad, isFeatured: true),
                    ),
                  ),
                );
              },
            ),
          ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ===========================================================================
  // NORMAL AD CARD
  // ===========================================================================

  Widget _buildAdCard(AdModel ad) {
    return GestureDetector(
      onTap: () => context.push(Routes.adDetails, extra: ad),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        // 6:5 on every phone, so the ad's 1200×1000 image shows whole.
        child: AspectRatio(
          aspectRatio: kAdListingImageAspect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildAdCardContent(ad),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // AD CARD CONTENT (shared between featured + normal)
  // ===========================================================================

  Widget _buildAdCardContent(AdModel ad, {bool isFeatured = false}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen ad image
        GestureDetector(
          onTap: () {
            AdsRepository().trackAdClick(ad.id).catchError((_) {});
            widget.onAdTap?.call(ad);
          },
          child: ad.photos.isNotEmpty
              ? Image.network(
                  ad.photos.first,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return _ShimmerBox(
                      width: double.infinity,
                      height: double.infinity,
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade300,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, size: 60),
                  ),
                )
              : Container(
                  color: Colors.grey.shade300,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported, size: 60),
                ),
        ),

        // Gradient overlay
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: isFeatured ? 100 : 120,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
          ),
        ),

        // Featured Badge
        if (isFeatured)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 14, color: Colors.black),
                  SizedBox(width: 4),
                  Text(
                    'FEATURED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Days Remaining Badge
        if (!isFeatured && ad.daysRemaining != null)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ad.daysRemaining! <= 3
                    ? Colors.red.shade600
                    : ad.daysRemaining! <= 7
                        ? Colors.orange.shade600
                        : Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, size: 11, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    ad.daysRemaining! <= 3
                        ? 'Ending soon'
                        : '${ad.daysRemaining}d left',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Sponsored Label + Info button
        Positioned(
          top: 12,
          left: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Sponsored',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => AdTransparencyModal.show(context, {
                  'id': ad.id,
                  'vendorName': ad.businessName,
                  'targeting': {
                    'municipality': ad.municipalities.isNotEmpty
                        ? ad.municipalities.first
                        : null,
                    'locationBased': ad.municipalities.isNotEmpty,
                  },
                }),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.info_outline,
                      color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
        ),

        // Owner info overlay
        Positioned(
          left: 16,
          bottom: 16,
          right: 16,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage:
                    (ad.ownerPhotoUrl != null && ad.ownerPhotoUrl!.isNotEmpty)
                        ? NetworkImage(ad.ownerPhotoUrl!)
                        : null,
                child: (ad.ownerPhotoUrl == null || ad.ownerPhotoUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ad.businessName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Ad title (if different from business name)
                    if (ad.title.isNotEmpty && ad.title != ad.businessName)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          ad.title,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (ad.contact != null && ad.contact!.isNotEmpty)
                      Text(
                        ad.contact!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // EMPTY & ERROR STATES
  // ===========================================================================

  Widget _buildEmptyState(String searchQuery) {
    final isSearch = searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSearch
                      ? [Colors.grey.shade200, Colors.grey.shade300]
                      : [Colors.blue.shade50, Colors.blue.shade100],
                ),
              ),
              child: Icon(
                isSearch
                    ? Icons.search_off_rounded
                    : (_isServices
                        ? Icons.handyman_outlined
                        : Icons.campaign_outlined),
                size: 48,
                color: isSearch ? Colors.grey[400] : Colors.blue[300],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSearch ? 'No results found' : 'No $_plural right now',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSearch
                  ? 'We couldn\'t find $_plural for "$searchQuery".\nTry a different keyword.'
                  : (_isServices
                      ? 'No one in your city is advertising a service yet.\nCheck back soon.'
                      : 'Local businesses are gearing up.\nCheck back soon for great deals!'),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSearch) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text('Show all $_plural'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Failed to load ads',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString().replaceAll('Exception: ', ''),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refreshAds,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SHIMMER SKELETON LOADING
  // ===========================================================================

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, i) => Container(
        height: 300,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder
              Expanded(
                child: _ShimmerBox(
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              // Text placeholders
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(width: 180, height: 14),
                    const SizedBox(height: 8),
                    _ShimmerBox(width: 120, height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SHIMMER EFFECT WIDGET
// =============================================================================

class _ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;

  static const double borderRadius = 6;

  const _ShimmerBox({
    this.width,
    this.height,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_ShimmerBox.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-0.5 + 2.0 * _controller.value, 0),
              colors: const [
                Color(0xFFEEEEEE),
                Color(0xFFF5F5F5),
                Color(0xFFEEEEEE),
              ],
            ),
          ),
        );
      },
    );
  }
}
