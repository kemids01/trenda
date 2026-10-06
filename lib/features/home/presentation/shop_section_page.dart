// lib/features/home/presentation/shop_section_page.dart
// "See all" for a curated Shop-tab section: every product in the band, as a
// grid, with an Official Trenda ad slot above and below it.
//
// The band's own colours carry over — the header sits on the section's backdrop
// and the heading keeps its accent — so tapping "See all" reads as the same
// shelf opened up, not a different page.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_frontend/features/core/widgets/frontend_official_ad_slot.dart';
import '../providers/official_collections_provider.dart' show colorFromHex;
import '../providers/shop_sections_provider.dart';
import 'widgets/shop_card_grid.dart';
import 'widgets/shop_product_card.dart';
import 'widgets/shop_store_card.dart';

class ShopSectionPage extends ConsumerWidget {
  final ShopSection section;

  const ShopSectionPage({super.key, required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = colorFromHex(section.accentColor, scheme.primary);
    final band = section.backgroundColor == null
        ? scheme.surface
        : colorFromHex(section.backgroundColor, scheme.surface);
    final products = section.products;
    final stores = section.shelvesStores;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF0E1116)
          : const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: band,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _onBand(band, scheme),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              section.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: accent,
              ),
            ),
            Text(
              stores
                  ? (section.stores.length == 1
                      ? '1 store'
                      : '${section.stores.length} stores')
                  : (products.length == 1
                      ? '1 product'
                      : '${products.length} products'),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _onBand(band, scheme).withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          if (section.subtitle != null)
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                color: band,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  section.subtitle!,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: _onBand(band, scheme).withValues(alpha: 0.66),
                  ),
                ),
              ),
            ),

          // Official Trenda ads — above the grid.
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 10, 0, 2),
              child: FrontendOfficialAdSlot(slotId: 'frontend.shop_section.top'),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            sliver: SliverGrid(
              gridDelegate: ShopCardGridDelegate(
                // A store card carries three short lines under a 1:1 facade; a
                // product card carries price and rating too, so it needs the
                // taller cell.
                detailsHeight: stores
                    ? kShopStoreCardDetailsHeight
                    : kShopProductCardDetailsHeight,
              ),
              delegate: stores
                  ? SliverChildBuilderDelegate(
                      (context, i) => ShopStoreCard(
                        store: section.stores[i],
                        onTap: () =>
                            context.push('/store/${section.stores[i].id}'),
                      ),
                      childCount: section.stores.length,
                    )
                  : SliverChildBuilderDelegate(
                      (context, i) => ShopProductCard(
                        product: products[i],
                        onTap: () => context.push('/product/${products[i].id}'),
                      ),
                      childCount: products.length,
                    ),
            ),
          ),

          // Official Trenda ads — below the grid.
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 4, 0, 8),
              child:
                  FrontendOfficialAdSlot(slotId: 'frontend.shop_section.bottom'),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  /// Readable ink for the admin's backdrop — a pale band keeps dark text even in
  /// dark mode, because the band is its own surface, not the page's.
  Color _onBand(Color band, ColorScheme scheme) {
    if (section.backgroundColor == null) return scheme.onSurface;
    return band.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
