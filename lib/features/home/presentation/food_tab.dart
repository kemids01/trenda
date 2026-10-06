// lib/features/home/presentation/food_tab.dart
// FOOD tab (main_screen index 2). One scrolling sliver page:
//   1. a short greeting naming the city,
//   2. the Official Trenda ads carousel (slot `frontend.food.top`, set in
//      admin ▸ Official Ads),
//   3. the admin's Food carousels (admin ▸ ADVERTISING ▸ Food Tab) — each a row
//      of stores or of featured food, per city with an all-cities default,
//   4. "All restaurant food": a pinned header with subcategory chips over a
//      grid of every in-stock Restaurant Food product in the city.
// Everything is theme-driven so it holds up in dark mode.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_shared/models/product_model.dart';
import '../../core/providers/municipality_provider.dart';
import '../../core/widgets/frontend_official_ad_slot.dart';
import '../../products/providers/products_provider.dart';
import '../providers/shop_sections_provider.dart';
import '../utils/food_catalogue.dart';
import 'widgets/ads_section_band.dart' show adsSectionFeaturedHeight;
import 'widgets/shop_feature_band.dart';
import 'widgets/shop_card_grid.dart';
import 'widgets/shop_product_card.dart';

/// Official ad slot at the top of the tab. Declared in trenda_shared
/// `kAdPlacementSlots` and backend `utils/adPlacements.js`.
const String kFoodTabAdSlotId = 'frontend.food.top';

/// Space under the greeting when no Food ad is showing (the ad itself sits
/// flush under the greeting).
const double kFoodGreetingGap = 12;

/// The Food tab's warm accent — food, not the marketplace blue.
const Color _kFood = Color(0xFFEA580C);

/// Selected subcategory chip; null = All. Riverpod, not widget state (§13).
final foodSubcategoryProvider = StateProvider.autoDispose<String?>((_) => null);

class FoodTab extends ConsumerWidget {
  const FoodTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bands =
        ref.watch(shopSectionsForPlacementProvider(ShopSectionPlacement.foodTab));
    final productsAsync = ref.watch(categoryProductsProvider(kRestaurantFoodCategory));
    final food = restaurantFood(productsAsync.valueOrNull ?? const []);
    final chips = foodSubcategories(food);
    final selected = ref.watch(foodSubcategoryProvider);
    // A chip that no longer exists (stock sold out) falls back to All.
    final active = chips.any((c) => c.toLowerCase() == selected?.toLowerCase())
        ? selected
        : null;
    final shown = filterFoodBySubcategory(food, active);

    return Container(
      color: dark ? const Color(0xFF0E1116) : const Color(0xFFF5F6F8),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(
              shopSectionsForPlacementProvider(ShopSectionPlacement.foodTab));
          ref.invalidate(categoryProductsProvider(kRestaurantFoodCategory));
          await ref.read(categoryProductsProvider(kRestaurantFoodCategory).future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _Greeting()),
            // Edge-to-edge and flush top and bottom, as tall as the Shop tab's
            // Featured ad. With no ad showing, the greeting keeps a little
            // space before what follows instead of touching it.
            SliverToBoxAdapter(
              child: FrontendOfficialAdSlot(
                slotId: kFoodTabAdSlotId,
                fullBleed: true,
                whenEmpty: const SizedBox(height: kFoodGreetingGap),
                height: adsSectionFeaturedHeight(
                    MediaQuery.sizeOf(context).width),
              ),
            ),
            ...bands.maybeWhen(
              data: (sections) => [
                for (var i = 0; i < sections.length; i++)
                  SliverToBoxAdapter(
                    child: Padding(
                      // The first band sits straight on the ad; later bands
                      // keep their gap from each other.
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                      child: ShopFeatureBand(section: sections[i]),
                    ),
                  ),
              ],
              orElse: () => const <Widget>[],
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _FoodHeaderDelegate(
                count: food.length,
                chips: chips,
                selected: active,
                background:
                    dark ? const Color(0xFF0E1116) : const Color(0xFFF5F6F8),
                onSelect: (c) =>
                    ref.read(foodSubcategoryProvider.notifier).state = c,
              ),
            ),
            if (productsAsync.isLoading && food.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (food.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyFood(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                sliver: SliverGrid(
                  gridDelegate: const ShopCardGridDelegate(
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _card(context, shown[i]),
                    childCount: shown.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, ProductModel p) => ShopProductCard(
        product: p,
        onTap: () => context.push('/product/${p.id}'),
      );
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final city = ref.watch(municipalityProvider)?.trim();
    return Padding(
      // No bottom padding: the Food ad sits flush under the greeting.
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kFood.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.restaurant_rounded, color: _kFood, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hungry?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  (city == null || city.isEmpty)
                      ? 'Order from local restaurants'
                      : 'Order from restaurants in $city',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "All restaurant food" + count + chips, pinned while the grid scrolls.
class _FoodHeaderDelegate extends SliverPersistentHeaderDelegate {
  _FoodHeaderDelegate({
    required this.count,
    required this.chips,
    required this.selected,
    required this.background,
    required this.onSelect,
  });

  final int count;
  final List<String> chips;
  final String? selected;
  final Color background;
  final ValueChanged<String?> onSelect;

  static const double _titleHeight = 46;
  static const double _chipsHeight = 44;

  double get _height => _titleHeight + (chips.isEmpty ? 0 : _chipsHeight);

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: background,
      elevation: overlapsContent ? 1 : 0,
      shadowColor: Colors.black26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _titleHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Text(
                    'All restaurant food',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (count > 0)
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (chips.isNotEmpty)
            SizedBox(
              height: _chipsHeight,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                children: [
                  _chip(context, 'All', selected == null, () => onSelect(null)),
                  for (final c in chips)
                    _chip(context, c,
                        selected?.toLowerCase() == c.toLowerCase(),
                        () => onSelect(c)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(
      BuildContext context, String label, bool on, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: on,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: _kFood,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: on ? Colors.white : scheme.onSurface,
        ),
        side: BorderSide(
            color: on ? _kFood : scheme.outlineVariant.withValues(alpha: 0.8)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  @override
  bool shouldRebuild(_FoodHeaderDelegate old) =>
      old.count != count ||
      old.selected != selected ||
      old.background != background ||
      old.chips.join('|') != chips.join('|');
}

class _EmptyFood extends StatelessWidget {
  const _EmptyFood();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ramen_dining_outlined,
              size: 44, color: scheme.onSurface.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          Text(
            'No restaurant food here yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Restaurants in your city will appear here as soon as they list a dish.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
