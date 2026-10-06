// lib/features/products/widgets/product_card_parts.dart
// The pieces every product card shares, so they read the same on all of
// them (Shop, Official, Search/Products, vendor category grid and rails,
// vendor store, Recently viewed):
//   • the price colour — one green, brighter in dark mode so it still reads;
//   • the line under the price — star rating and units sold;
//   • the store name over the top-right corner of the photo;
//   • the stock count line under the rating.
import 'package:flutter/material.dart';
import 'package:trenda_shared/models/product_model.dart';

/// Light-theme price green.
const Color kPriceGreen = Color(0xFF16A34A);

/// Dark-theme price green: the light one is too dim on a dark card.
const Color kPriceGreenDark = Color(0xFF4ADE80);

/// The colour of a product's price on every card.
Color productPriceColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? kPriceGreenDark
        : kPriceGreen;

/// Star rating and units sold, shown under the price.
///
/// Real figures only: an unrated product reads "New" with an empty star rather
/// than an invented score, and the sold count is the product's own.
class RatingSoldRow extends StatelessWidget {
  final double rating;
  final int reviews;
  final int sold;

  /// Text size; the star scales with it.
  final double fontSize;

  const RatingSoldRow({
    super.key,
    required this.rating,
    required this.reviews,
    required this.sold,
    this.fontSize = 10,
  });

  bool get _rated => reviews > 0 && rating > 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    return Row(
      children: [
        Icon(
          _rated ? Icons.star_rounded : Icons.star_outline_rounded,
          size: fontSize + 2,
          color: const Color(0xFFF5A623),
        ),
        const SizedBox(width: 2),
        Text(
          _rated ? rating.toStringAsFixed(1) : 'New',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        Container(
          width: 1,
          height: fontSize - 1,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          color: scheme.onSurface.withValues(alpha: 0.2),
        ),
        Flexible(
          child: Text(
            '$sold sold',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: fontSize, color: muted),
          ),
        ),
      ],
    );
  }
}

/// Who is selling, over the TOP-RIGHT corner of a product photo — the same chip
/// on every product card. Dark glass so it reads on any image, with a dot in the
/// seller's house colour so a shelf still reads as a row of shops.
///
/// Put it straight inside the photo's `Stack` (it is a `Positioned`). Renders
/// nothing for a blank name. Badges on a card belong on the top-LEFT; this
/// corner is the shop's.
class StoreNameCorner extends StatelessWidget {
  final String? storeName;

  /// The seller's house colour (`awningPaletteFor(vendorId).stripe`).
  final Color house;

  /// Share of the photo's width the chip may take before it ellipsizes.
  final double maxWidthFactor;

  const StoreNameCorner({
    super.key,
    required this.storeName,
    required this.house,
    this.maxWidthFactor = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    final store = (storeName ?? '').trim();
    if (store.isEmpty) return const Positioned(child: SizedBox.shrink());
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, box) => Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: box.maxWidth * maxWidthFactor),
              child: StoreNameChip(storeName: store, house: house),
            ),
          ),
        ),
      ),
    );
  }
}

/// The chip itself, for a card that positions it on its own.
class StoreNameChip extends StatelessWidget {
  final String storeName;
  final Color house;

  const StoreNameChip({super.key, required this.storeName, required this.house});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 6, 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: house, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              storeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a card or the product page says about stock, and how loudly.
enum StockLevel { out, low, plenty }

/// Products at or below this count read "Only N left" (ProductModel's own
/// `lowStockThreshold` wins where a card has it).
const int kDefaultLowStockThreshold = 5;

/// The stock count in words: "Out of stock", "Only 3 left" or "24 in stock".
/// Pure so the wording is pinned by a test and identical on every surface.
({String label, StockLevel level}) stockCountLabel(int stock,
    {int lowThreshold = kDefaultLowStockThreshold}) {
  if (stock <= 0) return (label: 'Out of stock', level: StockLevel.out);
  if (stock <= lowThreshold) {
    return (label: 'Only $stock left', level: StockLevel.low);
  }
  return (label: '$stock in stock', level: StockLevel.plenty);
}

/// The colour of a [StockLevel]; the plenty case is a quiet green.
Color stockLevelColor(BuildContext context, StockLevel level) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (level) {
    StockLevel.out => dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
    StockLevel.low => dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
    StockLevel.plenty => dark ? kPriceGreenDark : const Color(0xFF157347),
  };
}

/// The stock count line under [RatingSoldRow] on every product card.
class StockCountLine extends StatelessWidget {
  final int stock;
  final int lowThreshold;
  final double fontSize;

  const StockCountLine({
    super.key,
    required this.stock,
    this.lowThreshold = kDefaultLowStockThreshold,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final s = stockCountLabel(stock, lowThreshold: lowThreshold);
    final color = stockLevelColor(context, s.level);
    return Row(
      children: [
        Icon(Icons.inventory_2_outlined, size: fontSize + 1, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            s.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Whether a product's stock count means anything: an inquiry listing (a
/// service, a booking) or an untracked product has no count to show.
bool showsStockCount(ProductModel product) =>
    product.trackInventory && product.transactionMode != 'inquiry';
