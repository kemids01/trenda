// lib/features/home/presentation/shop_category_page.dart
// A Shop tab category page (/shop-category/<group>), one per store-category
// group in trenda_shared kShopCategoryPages — Pharmacy & Health, Hardware &
// Construction …
//
//   1. the category's STORES, as a swipeable row (tap → the store page),
//   2. an Official Trenda ad slot (frontend.shop_category.<group>),
//   3. the stores' PRODUCTS, with All · On sale · subcategory chips.
//
// Stores come from /api/stores (city-scoped) filtered by the shared
// storeMatchesCategory rule; products from /api/products?storeCategory=, so the
// page never depends on the Shop tab's capped all-products list.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_shared/models/ad_placement.dart'
    show kShopCategoryPages, shopCategorySlotId;
import 'package:trenda_shared/models/product_model.dart';

import '../../core/widgets/frontend_official_ad_slot.dart';
import '../providers/shop_category_provider.dart';
import '../providers/stores_provider.dart';
import '../utils/shop_category_filters.dart';
import '../utils/shop_category_lanes.dart';
import 'widgets/shop_card_grid.dart';
import 'widgets/shop_product_card.dart';
import 'widgets/shop_stores_row.dart';

class ShopCategoryPage extends ConsumerStatefulWidget {
  final String groupKey;

  const ShopCategoryPage({super.key, required this.groupKey});

  @override
  ConsumerState<ShopCategoryPage> createState() => _ShopCategoryPageState();
}

class _ShopCategoryPageState extends ConsumerState<ShopCategoryPage> {
  String _chip = kCategoryChipAll;

  String get _name {
    for (final p in kShopCategoryPages) {
      if (p.key == widget.groupKey) return p.name;
    }
    return shopCategoryLook(widget.groupKey).label;
  }

  Future<void> _refresh() async {
    ref.invalidate(publicStoresProvider);
    ref.invalidate(shopCategoryProductsProvider(widget.groupKey));
    await ref.read(shopCategoryProductsProvider(widget.groupKey).future);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final look = shopCategoryLook(widget.groupKey);
    final storesAsync = ref.watch(shopCategoryStoresProvider(widget.groupKey));
    final productsAsync = ref.watch(shopCategoryProductsProvider(widget.groupKey));

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF0E1116)
          : const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: look.color,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Icon(look.icon, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1 — the stores.
            SliverToBoxAdapter(
              child: ShopStoresRow(
                stores: storesAsync,
                accent: look.color,
                emptyText: 'No $_name stores in your city yet.',
              ),
            ),

            // 2 — the category's Official ad, under the stores.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FrontendOfficialAdSlot(
                  slotId: shopCategorySlotId(widget.groupKey),
                ),
              ),
            ),

            // 3 — the products.
            SliverToBoxAdapter(
              child: ShopSectionTitle(
                icon: Icons.inventory_2_rounded,
                title: 'Products',
                accent: look.color,
                trailing: productsAsync.maybeWhen(
                  data: (p) => p.isEmpty ? null : '${p.length}',
                  orElse: () => null,
                ),
              ),
            ),
            ...productsAsync.when(
              loading: () => [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
              error: (_, __) => [
                const SliverToBoxAdapter(
                    child: ShopNote('Could not load the products.')),
              ],
              data: (products) => _productSlivers(products, look.color),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  List<Widget> _productSlivers(List<ProductModel> products, Color accent) {
    if (products.isEmpty) {
      return [SliverToBoxAdapter(child: ShopNote('No $_name products yet.'))];
    }
    final chips = categoryChips(products);
    // A chip can vanish on reload (last item on sale sold out) — fall back.
    final chip = chips.contains(_chip) ? _chip : kCategoryChipAll;
    final shown = filterByCategoryChip(products, chip);
    return [
      SliverToBoxAdapter(
        child: SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final c = chips[i];
              final selected = c == chip;
              return ChoiceChip(
                label: Text(c),
                selected: selected,
                onSelected: (_) => setState(() => _chip = c),
                selectedColor: accent.withValues(alpha: 0.16),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : null,
                ),
                side: BorderSide(
                  color: selected
                      ? accent
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.12),
                ),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        sliver: SliverGrid(
          gridDelegate: const ShopCardGridDelegate(),
          delegate: SliverChildBuilderDelegate(
            (context, i) => ShopProductCard(
              product: shown[i],
              onTap: () => context.push('/product/${shown[i].id}'),
            ),
            childCount: shown.length,
          ),
        ),
      ),
    ];
  }
}
