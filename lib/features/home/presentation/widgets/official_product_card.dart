// lib/features/home/presentation/widgets/official_product_card.dart
// Reusable Official Trenda Store product card: gold Official pill, discount,
// store name top-right, wishlist + compare toggles over the photo, then name, free-delivery chip, the price
// in green, and the star rating and units sold under it. Shared by the Trenda Hub tab, the Official Store
// landing page, the collection "See all" grid and the related-products rail.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trenda_shared/trenda_shared.dart';
import '../../../products/utils/price_display.dart';
import '../../../products/widgets/product_card_parts.dart';
import '../../../products/utils/seller_label.dart';
import '../../../products/providers/comparison_provider.dart';
import '../../providers/official_favorites_provider.dart';
import '../../utils/home_rails.dart' show shelfPrice;

const Color kOfficialGold = Color(0xFFD4AF37);
const Color kOfficialGoldDark = Color(0xFFB8860B);

/// Height of the card's details block (name, chips, price, rating) in
/// [OfficialProductCard.compact] mode. A carousel sizes a compact card as
/// `width + kOfficialCompactDetailsHeight` so its photo stays square.
const double kOfficialCompactDetailsHeight = 110;

class OfficialProductCard extends ConsumerWidget {
  final ProductModel product;

  /// Narrow carousel card (three on a phone screen): the Official pill shrinks
  /// to its tick so it cannot collide with the discount badge, and the text and
  /// buttons step down a size. Grids keep the full card.
  final bool compact;

  const OfficialProductCard({super.key, required this.product, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final isCompared = ref.watch(comparisonProvider).contains(product.id);
    final isSaved = ref.watch(officialFavoritesProvider).contains(product.id);
    final discount = product.discountPercentage;
    // Gold reads darker on white and brighter on the dark surface.
    final gold = dark ? kOfficialGold : kOfficialGoldDark;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: kOfficialGold.withValues(alpha: dark ? 0.45 : 0.55),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _photo(scheme),
                    // Official pill, then the discount, down the top-left; the
                    // top-right is the store name, as on every product card.
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _officialPill(compact),
                          if (discount > 0) ...[
                            const SizedBox(height: 3),
                            _badge('-$discount%', const Color(0xFFDC2626)),
                          ],
                        ],
                      ),
                    ),
                    StoreNameCorner(
                      storeName: (product.storeName ?? '').trim().isNotEmpty
                          ? product.storeName
                          : sellerRoleLabel(isOfficial: true),
                      house: gold,
                    ),
                    if (product.isOutOfStock)
                      Positioned.fill(
                        child: ColoredBox(
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
                        ),
                      ),
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: _RoundToggle(
                        size: compact ? 24 : 28,
                        icon: isSaved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isSaved
                            ? const Color(0xFFE11D48)
                            : scheme.onSurface.withValues(alpha: 0.6),
                        tooltip: isSaved ? 'Remove from saved' : 'Save',
                        onTap: () => ref
                            .read(officialFavoritesProvider.notifier)
                            .toggle(product.id),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: _RoundToggle(
                        size: compact ? 24 : 28,
                        icon: Icons.compare_arrows_rounded,
                        color: isCompared
                            ? gold
                            : scheme.onSurface.withValues(alpha: 0.6),
                        tooltip: isCompared ? 'Remove from compare' : 'Compare',
                        onTap: () {
                          final comparison = ref.read(comparisonProvider);
                          if (!isCompared && comparison.isFull) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Compare list is full (max 4)')),
                            );
                            return;
                          }
                          ref
                              .read(comparisonProvider.notifier)
                              .toggleProduct(product);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: compact
                    ? const EdgeInsets.fromLTRB(7, 6, 7, 7)
                    : const EdgeInsets.fromLTRB(9, 7, 9, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (product.freeDelivery) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          if (product.freeDelivery)
                            _chip(
                              'FREE DELIVERY',
                              const Color(0xFF059669),
                              icon: Icons.local_shipping_rounded,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 5),
                    // Price in green, then the star rating and units sold.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              text: shelfPrice(product.basePrice),
                              style: TextStyle(
                                fontSize: compact ? 13 : 14.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                color: productPriceColor(context),
                              ),
                              children: [
                                TextSpan(
                                  text: pricingUnitSuffix(product.pricingUnit),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (discount > 0 && product.compareAtPrice != null) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              shelfPrice(product.compareAtPrice!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                                color: scheme.onSurface.withValues(alpha: 0.4),
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
                      fontSize: compact ? 9 : 10,
                    ),
                    if (showsStockCount(product)) ...[
                      const SizedBox(height: 2),
                      StockCountLine(
                        stock: product.stock,
                        lowThreshold: product.lowStockThreshold,
                        fontSize: compact ? 9 : 10,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photo(ColorScheme scheme) {
    final url = product.images.isNotEmpty ? product.images.first.trim() : '';
    final plate = ColoredBox(
      color: Color.lerp(kOfficialGold, scheme.surface, 0.9)!,
      child: Center(
        child: Icon(Icons.image_outlined,
            size: 30, color: kOfficialGold.withValues(alpha: 0.45)),
      ),
    );
    if (url.isEmpty) return plate;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => plate,
      errorWidget: (_, __, ___) => plate,
    );
  }

  Widget _officialPill(bool tickOnly) {
    return Container(
      padding: tickOnly ? const EdgeInsets.all(3) : const EdgeInsets.fromLTRB(5, 3, 7, 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kOfficialGoldDark, kOfficialGold],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: tickOnly
          ? const Icon(Icons.verified_rounded, color: Colors.white, size: 12)
          : const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: Colors.white, size: 11),
          SizedBox(width: 3),
          Text(
            'OFFICIAL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _chip(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          // Shrinks with an ellipsis rather than overflowing a narrow card.
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small round button over the photo that reads on any image and in dark
/// mode — the card's own surface colour, slightly translucent.
class _RoundToggle extends StatelessWidget {
  const _RoundToggle({
    this.size = 28,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final double size;
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surface.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.57, color: color),
          ),
        ),
      ),
    );
  }
}
