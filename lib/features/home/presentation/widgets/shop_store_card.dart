// lib/features/home/presentation/widgets/shop_store_card.dart
// One vendor store on a curated Shop-tab band — the Main Street storefront,
// shrunk to carousel scale.
//
// It deliberately does NOT reuse `StorefrontCard`: that card is a full shopfront
// built for a two-column grid, and at a carousel card's ~140px it collapses into
// unreadable detail. What carries over is the LANGUAGE, so a shop looks like the
// same shop on either screen — its own house colour, a striped scalloped awning,
// the hanging signboard with logo or monogram, weathered greys and a reopening
// line when it is shut.
//
// Geometry mirrors ShopProductCard exactly (a 1:1 facade over a fixed text
// block, sized from WIDTH alone) so one band height serves a product shelf and a
// store shelf without either being clipped.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../stores/utils/storefront_style.dart';
import '../../../stores/widgets/storefront_awning.dart';
import '../../providers/stores_provider.dart' show StoreData;

class ShopStoreCard extends StatelessWidget {
  final StoreData store;
  final VoidCallback onTap;

  /// Rail cards are fixed-width; a grid cell passes null and fills its slot.
  final double? width;

  const ShopStoreCard({
    super.key,
    required this.store,
    required this.onTap,
    this.width,
  });

  /// A shuttered shop is drawn desaturated, the way the Stores tab draws it.
  static const _greyscale = ColorFilter.matrix(<double>[
    0.30, 0.59, 0.11, 0, 0, //
    0.30, 0.59, 0.11, 0, 0, //
    0.30, 0.59, 0.11, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final closed = !store.storeStatus.isOpen;

    final seed = store.id.isNotEmpty ? store.id : store.name;
    // The house colour survives closing — the street keeps its character even
    // when a shop is shut.
    final house = awningPaletteFor(seed, brightness: theme.brightness).stripe;
    final palette = closed
        ? shutteredPalette(brightness: theme.brightness)
        : awningPaletteFor(seed, brightness: theme.brightness);

    return SizedBox(
      width: width,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: house.withValues(alpha: 0.10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: dark ? Colors.white12 : Colors.black.withValues(alpha: 0.07),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(aspectRatio: 1, child: _facade(context, palette, house, closed)),
                _counter(context, house, closed),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Banner (or a painted wall), the awning across the top, and the signboard
  /// hanging under it.
  Widget _facade(
    BuildContext context,
    AwningPalette palette,
    Color house,
    bool closed,
  ) {
    final theme = Theme.of(context);
    final banner = store.coverImage?.trim();
    final hasBanner = banner != null && banner.isNotEmpty;

    final Widget wall = hasBanner
        ? CachedNetworkImage(
            imageUrl: banner,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (_, __) => StorefrontWall(
                palette: awningPaletteFor(
                  store.id.isNotEmpty ? store.id : store.name,
                  brightness: theme.brightness,
                ),
                brightness: theme.brightness),
            errorWidget: (_, __, ___) => StorefrontWall(
                palette: awningPaletteFor(
                  store.id.isNotEmpty ? store.id : store.name,
                  brightness: theme.brightness,
                ),
                brightness: theme.brightness),
          )
        : StorefrontWall(
            palette: awningPaletteFor(
              store.id.isNotEmpty ? store.id : store.name,
              brightness: theme.brightness,
            ),
            brightness: theme.brightness,
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        closed ? ColorFiltered(colorFilter: _greyscale, child: wall) : wall,
        // Reads the sign against a busy banner photo.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black26, Colors.transparent, Colors.black26],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        // Fewer scallops than the full card: at this width nine would read as
        // noise rather than as canvas.
        Align(
          alignment: Alignment.topCenter,
          child: StorefrontAwning(palette: palette, height: 18, scallops: 5),
        ),
        Align(alignment: Alignment.center, child: _signboard(context, house, closed)),
        if (closed)
          Positioned(
            left: 6,
            bottom: 6,
            child: _chip('CLOSED', const Color(0xFF6B7280), Colors.white),
          ),
      ],
    );
  }

  /// The logo on a hanging board, or the shop's monogram when it has none.
  Widget _signboard(BuildContext context, Color house, bool closed) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final logo = store.logo?.trim();
    final hasLogo = logo != null && logo.isNotEmpty;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1F2430) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: house.withValues(alpha: closed ? 0.25 : 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? CachedNetworkImage(
              imageUrl: logo,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _monogram(house, closed),
            )
          : _monogram(house, closed),
    );
  }

  Widget _monogram(Color house, bool closed) => Center(
        child: Text(
          storeMonogram(store.name),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: closed ? const Color(0xFF9AA1AB) : house,
          ),
        ),
      );

  /// The counter strip: name, where it is, and whether it is open now.
  Widget _counter(BuildContext context, Color house, bool closed) {
    final scheme = Theme.of(context).colorScheme;
    final status = store.storeStatus;
    final reopening = closed
        ? formatReopening(day: status.nextOpenDay, time: status.nextOpenTime)
        : null;
    final meta = joinMeta([store.category, store.municipality]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            store.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            meta.isEmpty ? 'Vendor store' : meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (store.rating > 0) ...[
                const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF5A623)),
                const SizedBox(width: 2),
                Text(
                  store.rating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Text(
                  // A shut shop says when it opens; "Closed" alone tells a
                  // shopper nothing they can act on.
                  closed ? (reopening ?? 'Closed') : 'Open now',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: closed
                        ? scheme.onSurface.withValues(alpha: 0.5)
                        : const Color(0xFF2F6B3C),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            color: fg,
          ),
        ),
      );
}
