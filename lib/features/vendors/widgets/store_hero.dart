// lib/features/vendors/widgets/store_hero.dart
// The shopfront at the top of a store page. Deliberately the same building the
// customer tapped on the Stores street — same seeded awning colour, same
// signboard, same hanging sign — so opening a shop feels like walking into the
// one you were just looking at.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../stores/utils/storefront_style.dart';
import '../../stores/widgets/storefront_awning.dart';

class StoreHero extends StatelessWidget {
  /// Seed for the awning colour — the store id, matching the street card.
  final String seed;
  final String storeName;
  final String? bannerUrl;
  final String? logoUrl;
  final String? category;
  final String? municipality;
  final bool isOpen;
  final bool isVerified;
  final bool isFeatured;

  const StoreHero({
    super.key,
    required this.seed,
    required this.storeName,
    this.bannerUrl,
    this.logoUrl,
    this.category,
    this.municipality,
    this.isOpen = true,
    this.isVerified = false,
    this.isFeatured = false,
  });

  static const _greyscale = ColorFilter.matrix(<double>[
    0.30, 0.59, 0.11, 0, 0, //
    0.30, 0.59, 0.11, 0, 0, //
    0.30, 0.59, 0.11, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final closed = !isOpen;
    final house = awningPaletteFor(seed, brightness: theme.brightness);
    final palette =
        closed ? shutteredPalette(brightness: theme.brightness) : house;

    final banner = bannerUrl?.trim();
    final Widget painted =
        StorefrontWall(palette: house, brightness: theme.brightness);

    Widget facade = (banner != null && banner.isNotEmpty)
        ? CachedNetworkImage(
            imageUrl: banner,
            fit: BoxFit.cover,
            placeholder: (_, __) => painted,
            errorWidget: (_, __, ___) => painted,
          )
        : painted;

    if (closed) {
      facade = ColorFiltered(colorFilter: _greyscale, child: facade);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        facade,

        // Shade under the awning and a deep scrim at the base, so the fascia
        // sign stays legible over any banner a vendor uploads.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: closed ? 0.48 : 0.34),
                Colors.black.withValues(alpha: closed ? 0.36 : 0.06),
                Colors.black.withValues(alpha: closed ? 0.72 : 0.66),
              ],
              stops: const [0.0, 0.38, 1.0],
            ),
          ),
        ),

        Align(
          alignment: Alignment.topCenter,
          child: StorefrontAwning(palette: palette, height: 36, scallops: 11),
        ),

        Positioned(top: 36, right: 16, child: _hangingSign(closed)),

        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _signboard(house.stripe, closed),
              const SizedBox(width: 12),
              Expanded(child: _fascia(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fascia(BuildContext context) {
    final meta = joinMeta([category, municipality]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFeatured) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF3D68B), Color(0xFFC79A3C)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'FEATURED SHOP',
              style: TextStyle(
                color: Color(0xFF4A3405),
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Flexible(
              child: Text(
                storeName.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  height: 1.12,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
            if (isVerified) ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified_rounded,
                  size: 17, color: Color(0xFF60A5FA)),
            ],
          ],
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
        ],
      ],
    );
  }

  Widget _hangingSign(bool closed) {
    final label = closed ? 'CLOSED' : 'OPEN';
    final bg = closed ? const Color(0xFF2B2F36) : const Color(0xFFFDFBF5);
    final fg = closed ? const Color(0xFFF3F4F6) : const Color(0xFF157347);
    final edge = closed ? const Color(0xFF11151A) : const Color(0xFF157347);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 10,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(7),
              border:
                  Border.all(color: edge.withValues(alpha: 0.65), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 7,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _signboard(Color houseColor, bool closed) {
    const size = 70.0;
    final logo = logoUrl?.trim();

    final Widget monogram = Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(
        storeMonogram(storeName),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 3.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: closed
          ? ColorFiltered(colorFilter: _greyscale, child: inner)
          : inner,
    );
  }
}
