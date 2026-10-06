// lib/features/home/presentation/trenda_hub_tab.dart
// Official Trenda Store — Trenda Hub tab (main_screen index 1).
//
// Layout, top to bottom:
//   • a gold hero stating the brand promise + trust points;
//   • collection carousels (merchandising), tap title → See all;
//   • a PINNED filter bar — Category / Filters / Sort, all dropdowns — so the
//     catalogue can be narrowed from anywhere in the grid without scrolling back;
//   • the product grid, headed by a live result count.
//
// Search and QR scanning are NOT on this page — they live in the shop dock
// above the bottom navigation bar; the query arrives via
// [officialHubSearchProvider].
//
// Gold (#D4AF37) is the Official Trenda accent and is used here deliberately to
// separate first-party stock from ordinary vendor shelves.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// kOfficialHubBetweenCollectionSlotIds comes through this barrel — the gap ids
// are taken from there, never built by hand (see ad_placement.dart).
import 'package:trenda_shared/trenda_shared.dart';
import '../providers/official_store_provider.dart';
import '../providers/official_collections_provider.dart';
import '../providers/official_favorites_provider.dart';
import '../utils/official_store_filters.dart';
import '../../core/widgets/frontend_official_ad_slot.dart';
import '../../products/presentation/compare_bar.dart';
import 'widgets/ads_section_band.dart' show adsSectionFeaturedHeight;
import 'widgets/official_product_card.dart';
import 'widgets/shop_section.dart';

// Gold accent for the Official Trenda Store branding.
const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldDark = Color(0xFFB8860B);
const Color _kGoldDeep = Color(0xFF6E4E10);

/// The three boolean shelf filters, as dropdown entries.
enum _HubFilter { onSale, freeDelivery, saved }

class TrendaHubTab extends ConsumerStatefulWidget {
  const TrendaHubTab({super.key});

  @override
  ConsumerState<TrendaHubTab> createState() => _TrendaHubTabState();
}

class _TrendaHubTabState extends ConsumerState<TrendaHubTab> {
  String _selectedCategory = 'All';
  String _sort = 'newest';
  bool _onSale = false;
  bool _freeDelivery = false;
  bool _savedOnly = false;

  /// The query lives in [officialHubSearchProvider] because the field itself is
  /// in the shop dock above the bottom nav, not on this page.
  String get _search => ref.read(officialHubSearchProvider);

  int get _activeFilterCount =>
      (_onSale ? 1 : 0) + (_freeDelivery ? 1 : 0) + (_savedOnly ? 1 : 0);

  bool get _isNarrowed =>
      _search.trim().isNotEmpty ||
      _activeFilterCount > 0 ||
      _selectedCategory != 'All';

  void _clearFilters() {
    ref.read(officialHubSearchProvider.notifier).state = '';
    setState(() {
      _onSale = false;
      _freeDelivery = false;
      _savedOnly = false;
      _selectedCategory = 'All';
    });
  }

  void _toggleFilter(_HubFilter f) {
    setState(() {
      switch (f) {
        case _HubFilter.onSale:
          _onSale = !_onSale;
        case _HubFilter.freeDelivery:
          _freeDelivery = !_freeDelivery;
        case _HubFilter.saved:
          _savedOnly = !_savedOnly;
      }
    });
  }

  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(officialStoreProductsProvider);
    ref.invalidate(officialStoreCollectionsProvider);
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(officialStoreProductsProvider);
    final allProducts = productsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <ProductModel>[],
    );
    final categories = officialCategories(allProducts);
    // Guard: a previously-selected category may no longer exist after a refetch.
    final effectiveCategory =
        categories.contains(_selectedCategory) ? _selectedCategory : 'All';

    // Watched, not read: the field lives in the dock, so a keystroke there has
    // to rebuild this grid.
    final query = ref.watch(officialHubSearchProvider);
    // While searching, only the matches are shown. The hero, the ads and the
    // collection carousels are NOT filtered by the query, so they step aside —
    // otherwise the results sit below every carousel, off screen, and typing
    // looks like it does nothing.
    final searching = query.trim().isNotEmpty;
    // A new query starts at the top, where its results are. Listened (not done
    // in build) so the jump happens once per change, after the frame.
    ref.listen<String>(officialHubSearchProvider, (prev, next) {
      if ((prev ?? '').trim() == next.trim()) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
      });
    });

    final visible = applyOfficialFilters(
      allProducts,
      category: effectiveCategory,
      query: query,
      sort: _sort,
      onSaleOnly: _onSale,
      freeDeliveryOnly: _freeDelivery,
      savedOnly: _savedOnly,
      savedIds: ref.watch(officialFavoritesProvider),
    );

    final collections = ref.watch(officialStoreCollectionsProvider).maybeWhen(
          data: (list) => list,
          orElse: () => const <StoreCollection>[],
        );

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF0E1116)
          : const Color(0xFFF4F6F8),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (!searching) ...[
                  _buildHeroHeader(),
                  // Official Trenda ad — the top of the shelf, under the brand
                  // promise and above the merchandising. An unsold slot renders
                  // as nothing, so the hero still sits straight on the
                  // collections when nobody has bought it. Edge-to-edge and
                  // flush top and bottom, as tall as the Shop tab's Featured ad.
                  SliverToBoxAdapter(
                    child: FrontendOfficialAdSlot(
                      slotId: 'frontend.official_hub.top',
                      fullBleed: true,
                      height: adsSectionFeaturedHeight(
                          MediaQuery.sizeOf(context).width),
                    ),
                  ),
                  if (collections.isNotEmpty)
                    SliverToBoxAdapter(child: _buildCollections(collections)),
                ],
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _FilterBarDelegate(
                    height: 58,
                    builder: (context, overlapped) =>
                        _buildFilterBar(categories, effectiveCategory, overlapped),
                  ),
                ),
                productsAsync.when(
                  data: (_) => _buildResultHeader(visible.length),
                  loading: () =>
                      const SliverToBoxAdapter(child: SizedBox.shrink()),
                  error: (_, __) =>
                      const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),
                productsAsync.when(
                  data: (_) => _buildGrid(visible),
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: ShopRailSkeleton(
                        count: 2,
                        itemWidth: 170,
                        height: 280,
                      ),
                    ),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildError(e),
                  ),
                ),
                // Official Trenda ad — the foot of the shelf, after the grid.
                if (!searching)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: FrontendOfficialAdSlot(
                        slotId: 'frontend.official_hub.bottom',
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: CompareBar(),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HERO — the brand promise, stated once at the top of the shelf
  // ==========================================================================

  Widget _buildHeroHeader() {
    return SliverToBoxAdapter(
      child: _HeroPanel(onOpenStore: () => context.push('/official-store')),
    );
  }

  // ==========================================================================
  // FILTER BAR — three dropdowns, pinned above the grid
  // ==========================================================================

  Widget _buildFilterBar(
      List<String> categories, String effectiveCategory, bool overlapped) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF141922) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: scheme.onSurface.withValues(alpha: overlapped ? 0.10 : 0.06),
          ),
        ),
        boxShadow: overlapped
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.4 : 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      child: Row(
        children: [
          // CATEGORY — the primary product filter, now a dropdown.
          Expanded(
            child: _DropdownPill<String>(
              icon: Icons.category_rounded,
              label: effectiveCategory == 'All'
                  ? 'All categories'
                  : effectiveCategory,
              active: effectiveCategory != 'All',
              tooltip: 'Filter by category',
              itemBuilder: (context) => [
                for (final c in categories)
                  PopupMenuItem<String>(
                    value: c,
                    child: _MenuLine(
                      label: c == 'All' ? 'All categories' : c,
                      selected: c == effectiveCategory,
                    ),
                  ),
              ],
              onSelected: (c) => setState(() => _selectedCategory = c),
            ),
          ),
          const SizedBox(width: 8),
          // DEAL FILTERS — multi-select, each tap toggles one.
          _DropdownPill<_HubFilter>(
            icon: Icons.tune_rounded,
            label: _activeFilterCount == 0
                ? 'Filters'
                : 'Filters · $_activeFilterCount',
            active: _activeFilterCount > 0,
            tooltip: 'Deal filters',
            itemBuilder: (context) => [
              PopupMenuItem<_HubFilter>(
                value: _HubFilter.onSale,
                child: _MenuLine(
                  label: 'On sale',
                  icon: Icons.local_offer_rounded,
                  selected: _onSale,
                ),
              ),
              PopupMenuItem<_HubFilter>(
                value: _HubFilter.freeDelivery,
                child: _MenuLine(
                  label: 'Free delivery',
                  icon: Icons.local_shipping_rounded,
                  selected: _freeDelivery,
                ),
              ),
              PopupMenuItem<_HubFilter>(
                value: _HubFilter.saved,
                child: _MenuLine(
                  label: 'Saved',
                  icon: Icons.favorite_rounded,
                  selected: _savedOnly,
                ),
              ),
            ],
            onSelected: _toggleFilter,
          ),
          const SizedBox(width: 8),
          // SORT.
          _DropdownPill<String>(
            icon: Icons.swap_vert_rounded,
            label: _sort == 'newest' ? 'Sort' : officialSortLabel(_sort),
            active: _sort != 'newest',
            tooltip: 'Sort products',
            compact: true,
            itemBuilder: (context) => [
              for (final k in kOfficialSortKeys)
                PopupMenuItem<String>(
                  value: k,
                  child: _MenuLine(
                    label: officialSortLabel(k),
                    selected: k == _sort,
                  ),
                ),
            ],
            onSelected: (v) => setState(() => _sort = v),
          ),
        ],
      ),
    );
  }

  /// Live count + a one-tap way out of a filter set that found nothing.
  Widget _buildResultHeader(int count) {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 0),
        child: Row(
          children: [
            Text(
              count == 1 ? '1 product' : '$count products',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (_isNarrowed) ...[
              // Gives way (ellipsis) before the Clear button ever overflows.
              Expanded(
                child: Text(
                  '  ·  filtered',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: _kGoldDark,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // COLLECTIONS
  // ==========================================================================

  /// Cards per screen in a collection carousel, and the spacing they share.
  static const int _kCarouselCardsPerScreen = 3;
  static const double _kCarouselInset = 14;
  static const double _kCarouselGap = 10;

  /// The collection carousels, with an Official Trenda ad in each GAP between
  /// them.
  ///
  /// The gap slots are positional, so a newly created collection takes the next
  /// free one with no code change — a 4th collection turns the old trailing
  /// position into gap 3. Never AFTER the last carousel: that would be a
  /// trailing ad rather than a divider, and the pinned filter bar and grid
  /// already sit directly below. Past the declared ids the carousels simply sit
  /// next to each other, exactly as they did before.
  Widget _buildCollections(List<StoreCollection> collections) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < collections.length; i++) ...[
          _buildCollectionCarousel(collections[i]),
          if (i < collections.length - 1 &&
              i < kOfficialHubBetweenCollectionSlotIds.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              // An unsold gap renders as SizedBox.shrink, so it closes up
              // instead of leaving a hole between two carousels.
              child: FrontendOfficialAdSlot(
                slotId: kOfficialHubBetweenCollectionSlotIds[i],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildCollectionCarousel(StoreCollection collection) {
    // Per-collection accent (admin-set hex) → falls back to the default gold.
    final accent = colorFromHex(collection.accentColor, _kGoldDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Optional hero banner image (tap → See all).
        if ((collection.bannerImage ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: InkWell(
              onTap: () => context.push('/official-collection', extra: collection),
              borderRadius: BorderRadius.circular(14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 6,
                  child: Image.network(
                    collection.bannerImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: accent.withValues(alpha: 0.15)),
                  ),
                ),
              ),
            ),
          ),
        // Tappable header → dedicated "See all" grid for this collection.
        InkWell(
          onTap: () => context.push('/official-collection', extra: collection),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                // Accent bar makes each collection visually distinct.
                Container(
                  width: 4,
                  height: 32,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collection.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: accent,
                        ),
                      ),
                      if ((collection.subtitle ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          collection.subtitle!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('See all',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: accent,
                              fontWeight: FontWeight.w700)),
                      Icon(Icons.chevron_right_rounded, size: 16, color: accent),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Three whole cards on screen: the width comes from the screen, the
        // height from the width (square photo + the compact details block).
        Builder(builder: (context) {
          final screen = MediaQuery.sizeOf(context).width;
          final cardWidth = (screen -
                  _kCarouselInset * 2 -
                  _kCarouselGap * (_kCarouselCardsPerScreen - 1)) /
              _kCarouselCardsPerScreen;
          return SizedBox(
            height: cardWidth + kOfficialCompactDetailsHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: _kCarouselInset),
              itemCount: collection.products.length,
              separatorBuilder: (_, __) => const SizedBox(width: _kCarouselGap),
              itemBuilder: (context, index) => SizedBox(
                width: cardWidth,
                child: OfficialProductCard(
                  product: collection.products[index],
                  compact: true,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
      ],
    );
  }

  // ==========================================================================
  // GRID / STATES
  // ==========================================================================

  Widget _buildGrid(List<ProductModel> products) {
    if (products.isEmpty) {
      // A shopper who filtered everything away needs a way back, not the same
      // "nothing here yet" message an empty catalogue shows.
      final filtered = _isNarrowed;
      final scheme = Theme.of(context).colorScheme;

      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 44, 28, 40),
          child: Column(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  filtered
                      ? Icons.filter_alt_off_rounded
                      : Icons.storefront_rounded,
                  size: 34,
                  color: _kGoldDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                filtered
                    ? 'Nothing matches those filters'
                    : 'No official products yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                filtered
                    ? 'Try clearing a filter or searching for something else.'
                    : 'Check back soon for Official Trenda Store items.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              if (filtered) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kGoldDark,
                    side: BorderSide(
                      color: _kGoldDark.withValues(alpha: 0.5),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Clear filters'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.57,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => OfficialProductCard(product: products[index]),
          childCount: products.length,
        ),
      ),
    );
  }

  Widget _buildError(Object e) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 44, color: Colors.redAccent),
          const SizedBox(height: 12),
          const Text('Could not load official products',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('$e',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => ref.invalidate(officialStoreProductsProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// The expanded hero: what the Official Trenda Store is, and why it is different
/// from an ordinary vendor shelf.
class _HeroPanel extends StatelessWidget {
  final VoidCallback onOpenStore;

  const _HeroPanel({required this.onOpenStore});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B2A06), _kGoldDeep, _kGoldDark, _kGold],
          stops: [0, 0.34, 0.72, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // A soft light sweep across the panel, so the gold reads as metal
          // rather than as a flat block of colour.
          Positioned.fill(child: CustomPaint(painter: _SheenPainter())),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onOpenStore,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        child: const Icon(Icons.verified_rounded,
                            color: Colors.white, size: 23),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OFFICIAL TRENDA STORE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Sold and fulfilled directly by Trenda',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Shop all',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                )),
                            Icon(Icons.chevron_right_rounded,
                                size: 16, color: Colors.white),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Why buying first-party is different — stated, not implied.
                const Row(
                  children: [
                    _BannerPoint(
                        icon: Icons.inventory_2_rounded, label: 'Trenda stock'),
                    SizedBox(width: 8),
                    _BannerPoint(
                        icon: Icons.local_shipping_rounded,
                        label: 'Warehouse dispatch'),
                    SizedBox(width: 8),
                    _BannerPoint(
                        icon: Icons.payments_rounded, label: 'Cash on delivery'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A diagonal highlight + faint hairlines across the gold hero.
class _SheenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sweep = Path()
      ..moveTo(size.width * 0.42, 0)
      ..lineTo(size.width * 0.66, 0)
      ..lineTo(size.width * 0.30, size.height)
      ..lineTo(size.width * 0.06, size.height)
      ..close();
    canvas.drawPath(
      sweep,
      Paint()..color = Colors.white.withValues(alpha: 0.07),
    );

    final hairline = Paint()
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.06);
    for (var i = 1; i < 5; i++) {
      final x = size.width * (0.62 + i * 0.09);
      canvas.drawLine(Offset(x, 0), Offset(x - size.height * 0.5, size.height),
          hairline);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A compact dropdown rendered as a pill — the shelf's only filter affordance,
/// so all three (category, deal filters, sort) look and behave identically.
class _DropdownPill<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final String tooltip;
  final bool compact;
  final List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder;
  final ValueChanged<T> onSelected;

  const _DropdownPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.tooltip,
    required this.itemBuilder,
    required this.onSelected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = active ? Colors.white : scheme.onSurface.withValues(alpha: 0.78);

    return PopupMenuButton<T>(
      tooltip: tooltip,
      itemBuilder: itemBuilder,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        height: 38,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
        decoration: BoxDecoration(
          color: active ? _kGoldDark : scheme.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: active
                ? _kGoldDark
                : scheme.onSurface.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? Colors.white : _kGoldDark),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 17, color: fg),
          ],
        ),
      ),
    );
  }
}

/// One row inside a [_DropdownPill] menu, with its on/off state made visible.
class _MenuLine extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;

  const _MenuLine({required this.label, this.icon, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon,
              size: 15,
              color: selected
                  ? _kGoldDark
                  : scheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 9),
        ],
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? _kGoldDark : scheme.onSurface,
            ),
          ),
        ),
        if (selected) ...[
          const SizedBox(width: 8),
          const Icon(Icons.check_rounded, size: 16, color: _kGoldDark),
        ],
      ],
    );
  }
}

/// Pins the filter bar under the app bar and tells the builder whether content
/// is scrolling beneath it (so it can raise a shadow).
class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget Function(BuildContext context, bool overlapped) builder;

  _FilterBarDelegate({required this.height, required this.builder});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: height,
      child: builder(context, overlapsContent),
    );
  }

  @override
  bool shouldRebuild(covariant _FilterBarDelegate oldDelegate) => true;
}

/// One trust point on the Official Trenda hero.
class _BannerPoint extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BannerPoint({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
