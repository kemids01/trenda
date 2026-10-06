// lib/features/vendors/screens/category_products_screen.dart
// ============================================================================
// CATEGORY PRODUCTS SCREEN - VIEW ALL PRODUCTS IN A CATEGORY
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:trenda_shared/trenda_shared.dart';
import 'package:trenda_frontend/features/core/widgets/frontend_official_ad_slot.dart';
import '../providers/vendor_category_provider.dart';
import '../providers/vendor_follow_provider.dart';
import '../../stores/utils/storefront_style.dart';
import 'package:trenda_frontend/features/products/utils/price_display.dart';
import 'package:trenda_frontend/features/products/widgets/product_card_parts.dart';

class CategoryProductsScreen extends ConsumerWidget {
  final String vendorId;
  final String categoryId;

  const CategoryProductsScreen({
    super.key,
    required this.vendorId,
    required this.categoryId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(
        categoryProductsProvider((vendorId: vendorId, categoryId: categoryId)));
    final categoriesAsync = ref.watch(vendorCategoriesProvider(vendorId));
    final storeName =
        ref.watch(vendorProfileProvider(vendorId)).valueOrNull?.storeName;

    // Get category name from categories list
    final categoryName = categoriesAsync.maybeWhen(
      data: (categories) {
        final category =
            categories.where((c) => c.id == categoryId).firstOrNull;
        return category?.name ?? 'Category';
      },
      orElse: () => 'Category',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(categoryProductsProvider(
                (vendorId: vendorId, categoryId: categoryId))),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No products in this category',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                const FrontendOfficialAdSlot(slotId: 'frontend.category.top'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: MasonryGridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _ProductCard(
                    product: product,
                    index: index,
                    vendorId: vendorId,
                    storeName: storeName,
                  );
                },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(categoryProductsProvider(
                    (vendorId: vendorId, categoryId: categoryId))),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tile of the vendor category masonry grid: staggered photo heights and
/// sharp corners, then name, a description hint, a stock meter, the price in
/// green and the star rating and units sold under it.
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final int index;

  /// The shop all these products belong to, for the store-name chip.
  final String vendorId;
  final String? storeName;

  const _ProductCard({
    required this.product,
    required this.index,
    required this.vendorId,
    this.storeName,
  });

  /// Staggered photo heights, so the masonry reads as a shelf, not a table.
  static const _heightVariants = [160.0, 130.0, 145.0, 120.0, 155.0];

  /// A product is HOT past this many real sales.
  static const _hotSales = 200;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final imageHeight = _heightVariants[index % _heightVariants.length];

    final hasDiscount = product.compareAtPrice != null &&
        product.compareAtPrice! > product.basePrice;
    final discountPercent = hasDiscount
        ? ((1 - product.basePrice / product.compareAtPrice!) * 100).round()
        : 0;
    // Real figures only (RatingSoldRow): an unrated product reads "New", never
    // an invented 4.5.
    final sold = product.sales;
    final stock = product.stock;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final url = product.images.isNotEmpty ? product.images.first.trim() : '';
    final plate = ColoredBox(
      color: scheme.onSurface.withValues(alpha: 0.05),
      child: Center(
        child: Icon(Icons.image_outlined,
            size: 30, color: scheme.onSurface.withValues(alpha: 0.25)),
      ),
    );

    return Material(
      color: scheme.surface,
      shape: Border.all(
        color: dark ? Colors.white12 : Colors.black.withValues(alpha: 0.07),
        width: 0.5,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  url.isEmpty
                      ? plate
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => plate,
                          errorWidget: (_, __, ___) => plate,
                        ),
                  if (hasDiscount)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        color: const Color(0xFFE53935),
                        child: Text(
                          '-$discountPercent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  // HOT under the discount: top-right is the store name.
                  if (sold > _hotSales)
                    Positioned(
                      top: hasDiscount ? 21 : 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 3),
                        color: const Color(0xFFF4511E),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department_rounded,
                                size: 10, color: Colors.white),
                            SizedBox(width: 2),
                            Text(
                              'HOT',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 8.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  StoreNameCorner(
                    storeName: (product.storeName ?? '').trim().isNotEmpty
                        ? product.storeName
                        : storeName,
                    house: awningPaletteFor(vendorId,
                            brightness: theme.brightness)
                        .stripe,
                  ),
                  if (product.isOutOfStock)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: const Center(
                        child: Text(
                          'SOLD OUT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    )
                  else if (stock <= 5)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        color: const Color(0xFFB45309),
                        child: Text(
                          'ONLY $stock LEFT',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      letterSpacing: -0.2,
                      color: scheme.onSurface,
                    ),
                  ),
                  if ((product.description ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        product.description!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: muted),
                      ),
                    ),
                  // Stock meter: how much is left, coloured by urgency.
                  if (stock > 0) ...[
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (stock / 100).clamp(0.04, 1.0),
                        minHeight: 3,
                        backgroundColor:
                            scheme.onSurface.withValues(alpha: 0.08),
                        color: stock <= 10
                            ? const Color(0xFFE53935)
                            : stock <= 30
                                ? const Color(0xFFFB8C00)
                                : const Color(0xFF43A047),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('$stock in stock',
                        style: TextStyle(fontSize: 9, color: muted)),
                  ],
                  const SizedBox(height: 5),
                  // Price in green, then the star rating and units sold.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          '₱${product.basePrice.toStringAsFixed(0)}'
                          '${pricingUnitSuffix(product.pricingUnit)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: productPriceColor(context),
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '₱${product.compareAtPrice!.toStringAsFixed(0)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.4),
                              decoration: TextDecoration.lineThrough,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  RatingSoldRow(
                    rating: product.averageRating,
                    reviews: product.totalReviews,
                    sold: product.sales,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
