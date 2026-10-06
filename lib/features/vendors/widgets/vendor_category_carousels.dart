// lib/features/vendors/widgets/vendor_category_carousels.dart
// ============================================================================
// VENDOR CATEGORY CAROUSELS - DISPLAY CATEGORIES ON VENDOR STORE PAGE
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../providers/vendor_category_provider.dart';
import '../providers/vendor_follow_provider.dart';
import '../../stores/utils/storefront_style.dart';
import 'package:trenda_frontend/features/products/utils/price_display.dart';
import 'package:trenda_frontend/features/products/widgets/product_card_parts.dart';

class VendorCategoryCarousels extends ConsumerWidget {
  final String vendorId;

  /// The store page's house colour, so the store-name dot matches it.
  final Color? house;

  const VendorCategoryCarousels({super.key, required this.vendorId, this.house});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(vendorCategoriesProvider(vendorId));
    final storeName =
        ref.watch(vendorProfileProvider(vendorId)).valueOrNull?.storeName;

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();

        return Column(
          children: categories.map((category) {
            return _CategoryCarousel(
              category: category,
              vendorId: vendorId,
              storeName: storeName,
              house: house,
            );
          }).toList(),
        );
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

class _CategoryCarousel extends StatelessWidget {
  final VendorCategoryItem category;
  final String vendorId;
  final String? storeName;
  final Color? house;

  const _CategoryCarousel({
    required this.category,
    required this.vendorId,
    this.storeName,
    this.house,
  });

  @override
  Widget build(BuildContext context) {
    // Skip categories with no featured products
    if (category.featuredProducts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Category name and count
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (category.description != null &&
                      category.description!.isNotEmpty)
                    Text(
                      category.description!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),

              // View All button
              TextButton(
                onPressed: () {
                  context.push('/vendor/$vendorId/category/${category.id}');
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View All'),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Products Carousel
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: category.featuredProducts.length,
            itemBuilder: (context, index) {
              final product = category.featuredProducts[index];
              return _ProductCarouselCard(
                product: product,
                vendorId: vendorId,
                storeName: storeName,
                house: house,
              );
            },
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}

/// One card in a vendor category rail: sharp-cornered tile, photo, name, and
/// at the foot the price in green with the star rating and units sold under it.
class _ProductCarouselCard extends StatelessWidget {
  final ProductSummaryItem product;

  /// The shop these products belong to, for the store-name chip.
  final String vendorId;
  final String? storeName;
  final Color? house;

  const _ProductCarouselCard({
    required this.product,
    required this.vendorId,
    this.storeName,
    this.house,
  });

  /// A product is HOT past this many real sales.
  static const _hotSales = 200;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final hasDiscount = product.hasDiscount;
    final discountPercent = hasDiscount
        ? ((product.basePrice - product.displayPrice) / product.basePrice * 100)
            .round()
        : 0;
    // Real figures only (RatingSoldRow): no invented 4.5 stars.
    final sold = product.soldCount;
    final url = (product.primaryImage ?? '').trim();
    final plate = ColoredBox(
      color: scheme.onSurface.withValues(alpha: 0.05),
      child: Center(
        child: Icon(Icons.image_outlined,
            size: 28, color: scheme.onSurface.withValues(alpha: 0.25)),
      ),
    );

    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 8),
      child: Material(
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
            children: [
              SizedBox(
                height: 105,
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
                      storeName: storeName,
                      house: house ??
                          awningPaletteFor(vendorId,
                                  brightness: theme.brightness)
                              .stripe,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.2,
                          color: scheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      // Price in green at the foot, then the star rating and
                      // units sold under it.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              '₱${product.displayPrice.toStringAsFixed(0)}'
                              '${pricingUnitSuffix(product.pricingUnit)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: productPriceColor(context),
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (hasDiscount) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '₱${product.basePrice.toStringAsFixed(0)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.4),
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      // This summary carries a rating but no review count, so
                      // any real rating counts as rated.
                      RatingSoldRow(
                        rating: product.rating,
                        reviews: product.rating > 0 ? 1 : 0,
                        sold: sold,
                        fontSize: 9.5,
                      ),
                      const SizedBox(height: 2),
                      StockCountLine(stock: product.stock, fontSize: 9.5),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
