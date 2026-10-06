// lib/features/home/presentation/widgets/shop_product_card.dart
// One product card for every shelf on the home tab. Carries the things a
// shopper decides with — photo, discount, name, price, what it was, rating and
// who is selling — instead of just a name and a number.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:trenda_shared/models/product_model.dart';
import '../../../products/utils/price_display.dart';
import '../../../products/widgets/product_card_parts.dart';
import '../../../stores/utils/storefront_style.dart';
import '../../utils/home_rails.dart';

class ShopProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;

  /// Rail cards are fixed-width; a grid cell passes null and fills its slot.
  final double? width;

  const ShopProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final discount = product.discountPercentage;
    final rated = product.totalReviews > 0 && product.averageRating > 0;
    // The seller's house colour, so a shelf still reads as a row of shops.
    final house = awningPaletteFor(
      product.vendorId.isNotEmpty ? product.vendorId : product.id,
      brightness: theme.brightness,
    ).stripe;

    return SizedBox(
      width: width,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: dark
                    ? Colors.white12
                    : Colors.black.withValues(alpha: 0.07),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Builder(builder: (context) {
                    final isNew = !rated && product.sales == 0;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        _photo(context, house),
                        // Deal badges stack down the top-left corner, leaving the
                        // top-right to the shop.
                        if (discount > 0 || product.freeDelivery)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (discount > 0)
                                  _badge(
                                      '-$discount%', const Color(0xFFDC2626)),
                                if (discount > 0 && product.freeDelivery)
                                  const SizedBox(height: 3),
                                if (product.freeDelivery)
                                  _badge(
                                      'FREE DELIVERY', const Color(0xFF157347)),
                              ],
                            ),
                          ),
                        // Who is selling, top-right (shared with every card).
                        StoreNameCorner(
                            storeName: product.storeName, house: house),
                        // Ribbons hang off the lower-left edge of the photo.
                        if (!product.isOutOfStock &&
                            (isNew || product.isLowStock))
                          Positioned(
                            left: 0,
                            bottom: 8,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (product.isLowStock)
                                  _ribbon('ONLY ${product.stock} LEFT',
                                      const Color(0xFFB45309)),
                                if (product.isLowStock && isNew)
                                  const SizedBox(height: 3),
                                if (isNew)
                                  _ribbon('New listing', scheme.primary),
                              ],
                            ),
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
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                ),
                // Compact details: name, the price in green, then the star
                // rating and units sold under it.
                Padding(
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
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                text: shelfPrice(product.basePrice),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                  color: productPriceColor(context),
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        pricingUnitSuffix(product.pricingUnit),
                                    style: TextStyle(
                                      fontSize: 9.5,
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
                          if (discount > 0 &&
                              product.compareAtPrice != null) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                shelfPrice(product.compareAtPrice!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  decoration: TextDecoration.lineThrough,
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.38),
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
                        fontSize: 9.5,
                      ),
                      if (showsStockCount(product)) ...[
                        const SizedBox(height: 2),
                        StockCountLine(
                          stock: product.stock,
                          lowThreshold: product.lowStockThreshold,
                          fontSize: 9.5,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A banner flush with the photo's left edge, squared on that side so it
  /// reads as hanging off the image rather than floating on it.
  Widget _ribbon(String text, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _photo(BuildContext context, Color house) {
    final url = product.images.isNotEmpty ? product.images.first.trim() : '';
    final plate = _Plate(accent: house);
    if (url.isEmpty) return plate;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => plate,
      errorWidget: (_, __, ___) => plate,
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Plate extends StatelessWidget {
  final Color accent;

  const _Plate({required this.accent});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, dark ? Colors.black : Colors.white, 0.86)!,
            Color.lerp(accent, dark ? Colors.black : Colors.white, 0.95)!,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 30,
          color: accent.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
