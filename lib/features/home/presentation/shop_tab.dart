// lib/features/home/presentation/shop_tab.dart
// The Shop tab — the storefront window for the customer's own municipality.
//
// Shelves are derived from the catalogue that is already loaded (see
// utils/home_rails.dart), which replaced two wireframe placeholders that
// shipped to customers as grey boxes reading "TOP 10 / NON FEATURED ADS /
// CAROUSEL".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_shared/models/product_model.dart';
import 'package:trenda_shared/models/ad_placement.dart' show kShopBetweenSectionSlotIds;
import 'package:trenda_frontend/features/core/widgets/frontend_official_ad_slot.dart';
import 'package:trenda_frontend/features/products/providers/products_provider.dart';
import '../../ads/presentation/widgets/ad_carousel_widget.dart';
import '../../ads/providers/ads_provider.dart';
import '../providers/ads_section_provider.dart';
import '../providers/flash_sale_provider.dart';
import '../providers/shop_sections_provider.dart';
import '../utils/home_rails.dart';
import 'widgets/ads_section_band.dart';
import 'widgets/flash_sale_band.dart';
import 'widgets/shop_feature_band.dart';
import 'widgets/shop_card_grid.dart';
import 'widgets/shop_product_card.dart';
import 'widgets/shop_section.dart';
import 'widgets/shop_quick_lanes.dart';


class ShopTab extends ConsumerStatefulWidget {
  const ShopTab({super.key});

  @override
  ConsumerState<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends ConsumerState<ShopTab> {
  Future<void> _refreshData() async {
    ref.invalidate(publicProductsProvider);
    ref.invalidate(adsListProvider);
    // The family is what fetches; `shopSectionsProvider` only watches it, so
    // invalidating the alias alone would re-read the same cached list.
    ref.invalidate(
      shopSectionsForPlacementProvider(ShopSectionPlacement.shopTab),
    );
    ref.invalidate(shopSectionsProvider);
    ref.invalidate(adsSectionProvider);
    ref.invalidate(flashSaleFeedProvider);
    await ref.read(publicProductsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(publicProductsProvider);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF0E1116)
          : const Color(0xFFF4F6F8),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // No page header: the brand mark and the "Shopping in <city>" pill live
            // in the app-bar above every tab.
            const SliverToBoxAdapter(child: SizedBox(height: 4)),

            // Official Trenda ads (platform-owned) — top hero
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 8, 0, 4),
                child: FrontendOfficialAdSlot(slotId: 'frontend.home.hero'),
              ),
            ),

            // Lane buttons (swipeable) + a scroll indicator under them.
            const SliverToBoxAdapter(child: ShopQuickLanes()),

            // ⚡ Flash Sale (admin ▸ ADVERTISING ▸ Flash Sales). Builds nothing
            // when no sale is live or coming up in this city.
            const SliverToBoxAdapter(child: FlashSaleBand()),

            // Sold Ads & Services placements (admin ▸ ADVERTISING ▸ Ad
            // Placements). No live bookings → the provider returns null and the
            // band is not built at all, rather than a coloured empty strip.
            ...ref.watch(adsSectionProvider).maybeWhen(
                  data: (section) => section == null
                      ? const <Widget>[]
                      : [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: AdsSectionBand(section: section),
                            ),
                          ),
                        ],
                  orElse: () => const <Widget>[],
                ),

            // Admin-curated merchandising bands (admin ▸ Shop Tab Sections),
            // with an Official Trenda ad slot in each GAP between them.
            // Absent/empty config renders nothing.
            ...ref.watch(shopSectionsProvider).maybeWhen(
                  data: (sections) => [
                    for (var i = 0; i < sections.length; i++) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: ShopFeatureBand(section: sections[i]),
                        ),
                      ),
                      // Only BETWEEN bands: never after the last one, which
                      // would be a trailing ad rather than a divider — and the
                      // vendor ads section already sits directly below.
                      // An unsold slot renders as SizedBox.shrink, so a gap
                      // nobody bought closes up instead of leaving a hole.
                      if (i < sections.length - 1 &&
                          i < kShopBetweenSectionSlotIds.length)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: FrontendOfficialAdSlot(
                              slotId: kShopBetweenSectionSlotIds[i],
                            ),
                          ),
                        ),
                    ],
                  ],
                  orElse: () => const <Widget>[],
                ),

            SliverToBoxAdapter(child: _vendorAdsSection()),

            ...productsAsync.when(
              data: _shelves,
              loading: () => [
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                const SliverToBoxAdapter(child: ShopRailSkeleton()),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                const SliverToBoxAdapter(child: ShopRailSkeleton()),
              ],
              error: (e, _) => [
                SliverToBoxAdapter(child: _errorState(e)),
              ],
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // SHELVES
  // ==========================================================================

  List<Widget> _shelves(List<ProductModel> products) {
    // No products = no shelves, and nothing said about it. The page still has
    // its lanes, ads and curated bands, so an "empty" notice would be both
    // wrong and the loudest thing on the screen.
    if (products.isEmpty) return const [];

    final deals = topDeals(products);
    final sellers = bestSellers(products);
    final fresh = freshArrivals(products);
    final featured = featuredShelf(products);
    final categories = catalogueCategories(products);

    return [
      if (deals.isNotEmpty)
        SliverToBoxAdapter(
          child: _shelf(
            title: 'Deals in your area',
            subtitle: 'Biggest markdowns right now',
            icon: Icons.local_fire_department_rounded,
            accent: const Color(0xFFDC2626),
            products: deals,
            onSeeAll: () => context.push('/category/sale'),
          ),
        ),

      if (categories.isNotEmpty)
        SliverToBoxAdapter(child: _categoryStrip(categories)),

      if (sellers.isNotEmpty)
        SliverToBoxAdapter(
          child: _shelf(
            title: 'Popular nearby',
            subtitle: 'What your neighbours are buying',
            icon: Icons.trending_up_rounded,
            accent: const Color(0xFF0F766E),
            products: sellers,
          ),
        ),

      if (fresh.isNotEmpty)
        SliverToBoxAdapter(
          child: _shelf(
            title: 'Just listed',
            subtitle: 'Newest from local shops',
            icon: Icons.fiber_new_rounded,
            accent: const Color(0xFF1E4FA3),
            products: fresh,
          ),
        ),

      if (featured.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: ShopSectionHeader(
              title: 'Featured products',
              subtitle: 'Handpicked from shops near you',
              icon: Icons.star_rounded,
              accent: const Color(0xFFB4831F),
              onSeeAll: () => context.push('/products-grid'),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const ShopCardGridDelegate(
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => ShopProductCard(
                product: featured[i],
                onTap: () => context.push('/product/${featured[i].id}'),
              ),
              childCount: featured.length,
            ),
          ),
        ),
      ],
    ];
  }

  Widget _shelf({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required List<ProductModel> products,
    VoidCallback? onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShopSectionHeader(
            title: title,
            subtitle: subtitle,
            icon: icon,
            accent: accent,
            onSeeAll: onSeeAll,
          ),
          ShopRail(
            itemCount: products.length,
            itemBuilder: (context, i) => ShopProductCard(
              product: products[i],
              onTap: () => context.push('/product/${products[i].id}'),
            ),
          ),
        ],
      ),
    );
  }

  /// Categories are derived from what this municipality actually stocks, so a
  /// city never advertises a shelf it cannot fill.
  Widget _categoryStrip(List<String> categories) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShopSectionHeader(
            title: 'Browse by category',
            accent: scheme.primary,
            onSeeAll: () => context.push('/products-grid'),
          ),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final category = categories[i];
                return ActionChip(
                  label: Text(category),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.8),
                  ),
                  backgroundColor: scheme.surface,
                  side: BorderSide(
                    color: scheme.onSurface.withValues(alpha: 0.12),
                  ),
                  onPressed: () => context.push('/products-grid'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ADS
  // ==========================================================================

  Widget _vendorAdsSection() {
    final adsAsync = ref.watch(adsListProvider);

    return adsAsync.when(
      data: (ads) {
        final featuredAds = ads.where((ad) => ad.featured).take(5).toList();
        if (featuredAds.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShopSectionHeader(
                title: 'Featured ads',
                subtitle: 'Promotions from shops in your area',
                icon: Icons.campaign_rounded,
                accent: const Color(0xFFB4831F),
                onSeeAll: () => context.push('/category/ads'),
              ),
              AdCarouselWidget(ads: featuredAds, height: 180, autoPlay: true),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 10),
        child: ShopRailSkeleton(count: 1, itemWidth: 320, height: 180),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ==========================================================================
  // STATES
  // ==========================================================================

  Widget _errorState(Object e) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      child: Column(
        children: [
          Icon(Icons.wifi_tethering_off_rounded,
              size: 44, color: scheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Could not load the shelves',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '$e',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => ref.invalidate(publicProductsProvider),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
