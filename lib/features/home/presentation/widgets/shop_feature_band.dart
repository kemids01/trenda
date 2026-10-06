// lib/features/home/presentation/widgets/shop_feature_band.dart
// A curated merchandising band on the Shop tab: an admin-named heading over a
// centre-large carousel, drawn on an admin-chosen backdrop.
//
// The carousel is a PageView whose focused card is rendered at full size and
// whose neighbours shrink and fade — the shopper's eye lands on one product at a
// time instead of scanning a rail of equals. Everything visible here (name,
// subtitle, colours, products and their order) comes from the admin app; the
// widget hardcodes none of it.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_shared/models/product_model.dart';
import '../../providers/official_collections_provider.dart' show colorFromHex;
import '../../providers/stores_provider.dart' show StoreData;
import '../../providers/shop_sections_provider.dart';
import '../../utils/carousel_loop.dart';
import 'shop_card_grid.dart';
import 'shop_product_card.dart';
import 'shop_store_card.dart';

/// Card geometry.
///
/// The card sizes itself from its width (a 1:1 photo above a fixed text block),
/// so the width is the only dial — a forced height just clips it. The page is
/// [_kViewportFraction] of the screen and the card fills it minus [_kGap], which
/// is therefore the exact gutter between neighbours on any screen size.
const double _kViewportFraction = 0.38;
const double _kGap = 10;

/// Height below the square photo: the taller of the two cards' details blocks,
/// since a band holds either.
const double _kTextBlockHeight =
    kShopProductCardDetailsHeight > kShopStoreCardDetailsHeight
        ? kShopProductCardDetailsHeight
        : kShopStoreCardDetailsHeight;

/// Neighbours scale down to this, which is what produces the "centre is large"
/// shape without shrinking them into thumbnails.
const double _kSideScale = 0.88;

/// The carousel is a teaser, not the catalogue — past this, "See all" takes over.
const int _kMaxInCarousel = 10;

/// The band opens on the SECOND pick, so the first one is visible off to the
/// left and the shelf reads as already scrolled into — a carousel resting on its
/// first item looks like a list that has not started. Clamped for short bands.
const int _kInitialPage = 1;

class ShopFeatureBand extends StatefulWidget {
  final ShopSection section;

  const ShopFeatureBand({super.key, required this.section});

  @override
  State<ShopFeatureBand> createState() => _ShopFeatureBandState();
}

class _ShopFeatureBandState extends State<ShopFeatureBand> {
  late final PageController _controller;

  /// Fractional page position, driven by the controller so the scale reacts to
  /// the drag itself rather than snapping when the page settles. Seeded to the
  /// opening page: `_controller.page` is null until the viewport is laid out, so
  /// a 0 here would render the first frame with the wrong card enlarged.
  late double _page;

  @override
  void initState() {
    super.initState();
    // Whichever shelf the band uses — both draw through the same carousel.
    final count = widget.section.itemCount.clamp(0, _kMaxInCarousel);
    // A one-product band has no second pick to open on.
    final initial =
        loopInitialPage(count, _kInitialPage.clamp(0, count > 0 ? count - 1 : 0));
    _page = initial.toDouble();
    _controller = PageController(
      viewportFraction: _kViewportFraction,
      initialPage: initial,
    );
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    // `page` is null until the viewport has been laid out once.
    final p = _controller.page;
    if (p != null && p != _page) setState(() => _page = p);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stores = widget.section.shelvesStores;
    // Explicitly typed: an inferred `const []` here would make the index read
    // dynamic, and a wrong-typed card would then fail at runtime, not in
    // analysis.
    final List<ProductModel> shownProducts = stores
        ? const <ProductModel>[]
        : widget.section.products.take(_kMaxInCarousel).toList();
    final List<StoreData> shownStores = stores
        ? widget.section.stores.take(_kMaxInCarousel).toList()
        : const <StoreData>[];
    final shownCount = stores ? shownStores.length : shownProducts.length;

    // An unset backdrop leaves the page surface showing — the band still reads
    // as a section thanks to the heading, it just does not tint.
    final background = widget.section.backgroundColor == null
        ? Colors.transparent
        : colorFromHex(widget.section.backgroundColor, Colors.transparent);
    final accent = colorFromHex(widget.section.accentColor, scheme.primary);

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(accent),
          const SizedBox(height: 10),
          // The carousel sits on its own rounded card INSIDE the band. White by
          // default — that contrast is what lifts the products off a tinted
          // backdrop; admin can recolour it per section.
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colorFromHex(widget.section.carouselColor, Colors.white),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth =
                        constraints.maxWidth * _kViewportFraction - _kGap;
                    return SizedBox(
                      // Photo is 1:1, so the card's own height tracks its width.
                      height: cardWidth + _kTextBlockHeight,
                      child: PageView.builder(
                        controller: _controller,
                        padEnds: true,
                        // Endless: past the last pick comes the first again.
                        itemCount: loopItemCount(shownCount),
                        itemBuilder: (context, page) {
                          final index = loopIndex(page, shownCount);
                          return _slot(
                            page,
                            cardWidth,
                            // A store card and a product card share the
                            // carousel's geometry, so only the card differs.
                            child: stores
                                ? ShopStoreCard(
                                    store: shownStores[index],
                                    width: cardWidth,
                                    onTap: () => context
                                        .push('/store/${shownStores[index].id}'),
                                  )
                                : ShopProductCard(
                                    product: shownProducts[index],
                                    width: cardWidth,
                                    onTap: () => context.push(
                                        '/product/${shownProducts[index].id}'),
                                  ),
                          );
                        },
                      ),
                    );
                  },
                ),
                if (shownCount > 1) ...[
                  const SizedBox(height: 10),
                  _dots(accent, shownCount),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(Color accent) {
    final scheme = Theme.of(context).colorScheme;
    // On a tinted band the page's own text colours can wash out, so the copy is
    // keyed off the backdrop's brightness rather than the theme's.
    final onBand = _onBandColor(scheme);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 34,
            margin: const EdgeInsets.only(right: 11),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.section.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: accent,
                  ),
                ),
                if (widget.section.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.section.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      // Admin's colour if set; otherwise follow the band's own
                      // ink, which stays readable on a pale or a dark backdrop.
                      color: colorFromHex(widget.section.subtitleColor,
                          onBand.withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Opens the whole shelf as a grid — the carousel only ever shows the
          // first [_kMaxInCarousel].
          InkWell(
            onTap: () => context.push(
              '/shop-section',
              extra: widget.section,
            ),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.fromLTRB(11, 6, 7, 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16, color: accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The centre-large treatment, applied to whatever card sits in the slot.
  ///
  /// Width only — the card derives its own height, and forcing one clips the
  /// bottom row off (the price on a product, the opening line on a store).
  Widget _slot(int index, double cardWidth, {required Widget child}) {
    // Distance from the focused page, clamped so a fast fling cannot shrink a
    // card to nothing.
    final distance = (index - _page).abs().clamp(0.0, 1.0);
    final scale = 1 - (1 - _kSideScale) * distance;
    final opacity = 1 - 0.3 * distance;

    return Padding(
      // Half the gutter each side: adjacent pages together make exactly [_kGap].
      padding: const EdgeInsets.symmetric(horizontal: _kGap / 2),
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: Opacity(opacity: opacity, child: child),
        ),
      ),
    );
  }

  Widget _dots(Color accent, int count) {
    final current = loopIndex(_page.round(), count);
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == current ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: i == current ? 1 : 0.28),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }

  /// Readable ink for whatever backdrop the admin picked. A pale band keeps dark
  /// text even in dark mode — the band is its own surface, not the page's.
  Color _onBandColor(ColorScheme scheme) {
    final hex = widget.section.backgroundColor;
    if (hex == null) return scheme.onSurface;
    final band = colorFromHex(hex, scheme.surface);
    return band.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
