// lib/features/stores/widgets/storefront_card.dart
// A store rendered as a physical shopfront: striped awning, banner facade,
// hanging OPEN/CLOSED placard, a mounted signboard for the logo, and a counter
// strip underneath carrying the shop's details.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../home/providers/stores_provider.dart';
import '../utils/storefront_style.dart';
import 'storefront_awning.dart';

class StorefrontCard extends StatefulWidget {
  final StoreData store;
  final bool isFeatured;
  final bool isClosed;
  final VoidCallback onTap;

  const StorefrontCard({
    super.key,
    required this.store,
    required this.onTap,
    this.isFeatured = false,
    this.isClosed = false,
  });

  @override
  State<StorefrontCard> createState() => _StorefrontCardState();
}

class _StorefrontCardState extends State<StorefrontCard> {
  bool _pressed = false;

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
    final store = widget.store;

    final seed = store.id.isNotEmpty ? store.id : store.name;
    // A shuttered shop rolls out a weathered grey awning, but keeps its house
    // colour for trim and accents so the street holds its character.
    final houseColor = awningPaletteFor(seed, brightness: theme.brightness).stripe;
    final palette = widget.isClosed
        ? shutteredPalette(brightness: theme.brightness)
        : awningPaletteFor(seed, brightness: theme.brightness);

    final facadeHeight = widget.isFeatured ? 178.0 : 138.0;

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.isFeatured
                ? const Color(0xFFD7A93E).withValues(alpha: 0.85)
                : (dark ? Colors.white12 : Colors.black.withValues(alpha: 0.07)),
            width: widget.isFeatured ? 1.6 : 1,
          ),
          boxShadow: [
            // Grounded: a soft cast shadow plus a tight contact one, so the card
            // reads as a building standing on the street rather than a tile.
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.45 : 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.30 : 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) {
              if (mounted) setState(() => _pressed = v);
            },
            splashColor: houseColor.withValues(alpha: 0.10),
            highlightColor: houseColor.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _facade(context, palette, houseColor, facadeHeight),
                _counter(context, houseColor),
                // Threshold: the shop's step down to the pavement.
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: houseColor
                        .withValues(alpha: widget.isClosed ? 0.10 : 0.22),
                    border: Border(
                      top: BorderSide(
                        color: houseColor.withValues(alpha: 0.22),
                      ),
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

  // ==========================================================================
  // FACADE - banner (or painted wall), awning, hanging sign, plaques
  // ==========================================================================

  Widget _facade(
    BuildContext context,
    AwningPalette palette,
    Color houseColor,
    double height,
  ) {
    final theme = Theme.of(context);
    final store = widget.store;
    final banner = store.coverImage?.trim();
    final hasBanner = banner != null && banner.isNotEmpty;

    final Widget painted = StorefrontWall(
      palette: awningPaletteFor(
        store.id.isNotEmpty ? store.id : store.name,
        brightness: theme.brightness,
      ),
      brightness: theme.brightness,
    );

    Widget wall = hasBanner
        ? CachedNetworkImage(
            imageUrl: banner,
            fit: BoxFit.cover,
            width: double.infinity,
            height: height,
            placeholder: (_, __) => painted,
            errorWidget: (_, __, ___) => painted,
          )
        : painted;

    if (widget.isClosed) {
      wall = ColorFiltered(colorFilter: _greyscale, child: wall);
    }

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          wall,

          // Shade under the awning, light in the middle of the shopfront, and a
          // scrim at the base so the painted sign stays legible on any banner.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: widget.isClosed ? 0.42 : 0.26),
                  Colors.black.withValues(alpha: widget.isClosed ? 0.34 : 0.02),
                  Colors.black.withValues(alpha: widget.isClosed ? 0.62 : 0.52),
                ],
                stops: const [0.0, 0.40, 1.0],
              ),
            ),
          ),

          // The awning itself.
          Align(
            alignment: Alignment.topCenter,
            child: StorefrontAwning(
              palette: palette,
              height: widget.isFeatured ? 34 : 29,
              scallops: widget.isFeatured ? 10 : 8,
            ),
          ),

          // Hanging door sign.
          Positioned(
            top: widget.isFeatured ? 34 : 29,
            right: 14,
            child: _hangingSign(),
          ),

          // Shop name painted across the fascia.
          Positioned(
            left: 88,
            right: 14,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isFeatured) ...[
                  _brassPlaque(),
                  const SizedBox(height: 6),
                ],
                Text(
                  store.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.isFeatured ? 19 : 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    height: 1.1,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  joinMeta([store.category, store.municipality]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
              ],
            ),
          ),

          // Signboard carrying the shop's logo, mounted beside the door.
          Positioned(left: 14, bottom: 12, child: _signboard(houseColor)),
        ],
      ),
    );
  }

  /// A small placard on two strings, hung under the awning.
  Widget _hangingSign() {
    final open = !widget.isClosed;
    final label = open ? 'OPEN' : 'CLOSED';
    final bg = open ? const Color(0xFFFDFBF5) : const Color(0xFF2B2F36);
    final fg = open ? const Color(0xFF157347) : const Color(0xFFF3F4F6);
    final edge = open ? const Color(0xFF157347) : const Color(0xFF11151A);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          height: 9,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              2,
              (_) => Container(
                width: 1.2,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
        Transform.rotate(
          angle: -0.03,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: edge.withValues(alpha: 0.65),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The logo, mounted like a sign screwed to the wall.
  Widget _signboard(Color houseColor) {
    final logo = widget.store.logo?.trim();
    final size = widget.isFeatured ? 64.0 : 58.0;

    final Widget monogram = Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(
        storeMonogram(widget.store.name),
        style: TextStyle(
          color: houseColor,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );

    final Widget inner = (logo != null && logo.isNotEmpty)
        ? CachedNetworkImage(
            imageUrl: logo,
            fit: BoxFit.cover,
            width: size,
            height: size,
            placeholder: (_, __) => Container(color: Colors.white),
            errorWidget: (_, __, ___) => monogram,
          )
        : monogram;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: widget.isClosed
          ? ColorFiltered(colorFilter: _greyscale, child: inner)
          : inner,
    );
  }

  Widget _brassPlaque() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3D68B), Color(0xFFC79A3C)],
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 11, color: Color(0xFF4A3405)),
          SizedBox(width: 3),
          Text(
            'FEATURED SHOP',
            style: TextStyle(
              color: Color(0xFF4A3405),
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // COUNTER - the details strip below the window
  // ==========================================================================

  Widget _counter(BuildContext context, Color houseColor) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.62);
    final store = widget.store;
    final reopening = formatReopening(
      day: store.storeStatus.nextOpenDay,
      time: store.storeStatus.nextOpenAt,
    );

    final address = (store.address ?? '').trim();
    final blurb = (store.description ?? '').trim();
    final tagline = address.isNotEmpty ? address : blurb;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tagline.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  address.isNotEmpty
                      ? Icons.place_outlined
                      : Icons.storefront_outlined,
                  size: 14,
                  color: muted,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: muted, height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          // The stats take whatever the trailing cue leaves behind, and every
          // label can ellipsize — so a long shop, a wide locale or a large
          // system font scale degrades instead of overflowing.
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: _stat(
                        context,
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFE9A227),
                        label: store.rating > 0
                            ? store.rating.toStringAsFixed(1)
                            : 'New',
                        sub: store.reviewCount > 0
                            ? '(${store.reviewCount})'
                            : null,
                      ),
                    ),
                    _tick(context),
                    Flexible(
                      child: _stat(
                        context,
                        icon: Icons.inventory_2_outlined,
                        iconColor: houseColor,
                        label: '${store.productCount}',
                        sub: store.productCount == 1 ? 'item' : 'items',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (widget.isClosed)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: _pill(
                    text: reopening ?? 'Browse the shelves',
                    color: const Color(0xFFB45309),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Step inside',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: houseColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: houseColor,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    String? sub,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ),
        if (sub != null) ...[
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _tick(BuildContext context) => Container(
        width: 1,
        height: 12,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Theme.of(context).dividerColor,
      );

  Widget _pill({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
