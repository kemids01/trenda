// lib/features/home/presentation/widgets/shop_card_grid.dart
// Cell sizing for grids and bands of ShopProductCard / ShopStoreCard.
//
// Both cards are a square photo over a fixed details block, so a cell is
// exactly "its width + the details height". A fixed childAspectRatio cannot say
// that — it leaves empty space on wide screens and clips on narrow ones.

import 'package:flutter/rendering.dart';

/// Height under the photo for a product card. Measured 83 at its tallest
/// (two-line name + rating row + price), plus a few px because device fonts
/// render slightly taller than test fonts. Re-measure if the card grows.
/// Height under the photo for a product card. Measured up to 108px at its tallest
/// (two-line name + rating row + stock line + price). Re-measure if the card grows.
const double kShopProductCardDetailsHeight = 110;

/// Height under the photo for a store card. Measured 80 at its tallest.
const double kShopStoreCardDetailsHeight = 88;

/// A fixed-column grid whose cells are square-photo cards: each cell is as
/// tall as it is wide plus [detailsHeight].
class ShopCardGridDelegate extends SliverGridDelegate {
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double detailsHeight;

  const ShopCardGridDelegate({
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 10,
    this.crossAxisSpacing = 10,
    this.detailsHeight = kShopProductCardDetailsHeight,
  });

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final usable =
        constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1);
    final cellWidth = (usable / crossAxisCount).clamp(0.0, double.infinity);
    final cellHeight = cellWidth + detailsHeight;
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: cellHeight + mainAxisSpacing,
      crossAxisStride: cellWidth + crossAxisSpacing,
      childMainAxisExtent: cellHeight,
      childCrossAxisExtent: cellWidth,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(ShopCardGridDelegate oldDelegate) =>
      oldDelegate.crossAxisCount != crossAxisCount ||
      oldDelegate.mainAxisSpacing != mainAxisSpacing ||
      oldDelegate.crossAxisSpacing != crossAxisSpacing ||
      oldDelegate.detailsHeight != detailsHeight;
}
