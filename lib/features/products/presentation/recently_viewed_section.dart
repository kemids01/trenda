// lib/features/products/presentation/recently_viewed_section.dart
// Horizontal scrolling section showing recently viewed products

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trenda_shared/models/product_model.dart';
import '../providers/recently_viewed_provider.dart';
import '../utils/price_display.dart';
import '../widgets/product_card_parts.dart';
import '../../stores/utils/storefront_style.dart';

class RecentlyViewedSection extends ConsumerWidget {
  const RecentlyViewedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentProducts = ref.watch(recentlyViewedLimitedProvider);

    if (recentProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.history,
                      size: 20,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Text(
                    'Recently Viewed',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  ref.read(recentlyViewedProvider.notifier).clearAll();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('History cleared')),
                  );
                },
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        SizedBox(
          // Photo (120) + name, price and the rating/sold line.
          height: 196,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recentProducts.length,
            itemBuilder: (context, index) {
              final product = recentProducts[index];
              return _RecentProductCard(product: product);
            },
          ),
        ),
      ],
    );
  }
}

/// A small rounded tile in the Recently Viewed rail: photo, name, the price in
/// green and the star rating and units sold under it.
class _RecentProductCard extends StatelessWidget {
  final ProductModel product;

  const _RecentProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final discount = product.discountPercentage;
    final url = product.images.isNotEmpty ? product.images.first.trim() : '';
    final plate = ColoredBox(
      color: scheme.onSurface.withValues(alpha: 0.05),
      child: Center(
        child: Icon(Icons.image_outlined,
            size: 26, color: scheme.onSurface.withValues(alpha: 0.25)),
      ),
    );

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/product/${product.id}'),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: dark
                    ? Colors.white12
                    : Colors.black.withValues(alpha: 0.07),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
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
                      if (discount > 0)
                        Positioned(
                          top: 5,
                          left: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '-$discount%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      StoreNameCorner(
                        storeName: product.storeName,
                        house: awningPaletteFor(
                          product.vendorId.isNotEmpty
                              ? product.vendorId
                              : product.id,
                          brightness: theme.brightness,
                        ).stripe,
                        // A 120px card: let the name use more of the width.
                        maxWidthFactor: 0.6,
                      ),
                      if (product.isOutOfStock)
                        ColoredBox(
                          color: Colors.black.withValues(alpha: 0.45),
                          child: const Center(
                            child: Text(
                              'SOLD OUT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '₱${product.basePrice.toStringAsFixed(0)}'
                          '${pricingUnitSuffix(product.pricingUnit)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                            color: productPriceColor(context),
                          ),
                        ),
                        const SizedBox(height: 1),
                        RatingSoldRow(
                          rating: product.averageRating,
                          reviews: product.totalReviews,
                          sold: product.sales,
                          fontSize: 9,
                        ),
                        if (showsStockCount(product)) ...[
                          const SizedBox(height: 1),
                          StockCountLine(
                            stock: product.stock,
                            lowThreshold: product.lowStockThreshold,
                            fontSize: 9,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
