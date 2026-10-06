// lib/features/home/presentation/widgets/curated_carousel_header.dart
// The admin-curated carousel that sits above a browse grid ("All items",
// "On sale").
//
// It is the same band the Shop tab renders, fed by the same model and the same
// admin editor (📢 ADVERTISING ▸ Shop Tab Sections) — only the `placement` the
// admin picked decides which page it lands on. One widget, one band, so a new
// surface is a new placement rather than a new carousel.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/shop_sections_provider.dart';
import 'shop_feature_band.dart';

class CuratedCarouselHeader extends ConsumerWidget {
  const CuratedCarouselHeader({super.key, required this.placement});

  /// One of [ShopSectionPlacement].
  final String placement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Loading and error both render nothing: the grid below is the page, and a
    // spinner or an error box above it would be the loudest thing on screen
    // for something the admin may not even have configured.
    final sections = ref.watch(shopSectionsForPlacementProvider(placement));

    return sections.maybeWhen(
      data: (bands) {
        if (bands.isEmpty) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final band in bands)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ShopFeatureBand(section: band),
              ),
            const SizedBox(height: 4),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
