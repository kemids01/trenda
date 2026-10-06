// lib/features/home/presentation/widgets/ads_section_band.dart
// The "Ads & Services" band on the Shop tab: two carousels side by side, each
// showing one paid placement at a time.
//
// Side by side means each carousel is roughly half the screen — about 180px on a
// typical phone. That is why the card is an image plus a single line of title
// and nothing else: a description does not fit at this width, and a truncated
// one reads worse than none. The admin uploader states the near-square creative
// size this expects.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_shared/models/ad_model.dart';
import '../ad_showcase_page.dart' show openAd;
import '../ads_section_page.dart' show AdsKind, AdsSectionPageArgs;
import '../../providers/ads_section_provider.dart';
import '../../providers/official_collections_provider.dart' show colorFromHex;
import '../../utils/carousel_loop.dart';
import '../../../ads/utils/ad_click_handler.dart' show recordAdImpression;

/// Ads & Services placements already counted as viewed this app session — shared by the band
/// and its See-all page, so rebuilding the Shop tab never re-counts the same ad. (The backend
/// still counts unique viewers separately; this keeps the running TOTAL honest.)
final Set<String> adsSectionSeenAds = {};

/// Gap between the two carousels.
const double _kColumnGap = 10;

/// The featured card is taller than the rest — that height difference is most of
/// what an advertiser is buying.
const double _kFeaturedExtra = 18;

/// Title strip under each card's square image.
const double _kTitleStrip = 40;

/// Horizontal inset of the two-column row inside the band.
const double _kBandInset = 14;

/// Height of the band's Featured card for a band [bandWidth] wide — the same
/// arithmetic the columns use (square image + title strip + featured extra).
/// Other surfaces that must match the Featured card size from this.
double adsSectionFeaturedHeight(double bandWidth) {
  final column = (bandWidth - _kBandInset * 2 - _kColumnGap) / 2;
  return column + _kTitleStrip + _kFeaturedExtra;
}

class AdsSectionBand extends StatelessWidget {
  final AdsSection section;

  const AdsSectionBand({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final background = section.backgroundColor == null
        ? Colors.transparent
        : colorFromHex(section.backgroundColor, Colors.transparent);
    final accent = colorFromHex(section.accentColor, scheme.primary);
    final onBand = _onBandColor(scheme);

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, accent),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kBandInset),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _AdsColumn(
                    section: section,
                    kind: AdsKind.vendor,
                    label: section.vendorLabel,
                    carousel: section.vendor,
                    accent: accent,
                    onBand: onBand,
                  ),
                ),
                const SizedBox(width: _kColumnGap),
                Expanded(
                  child: _AdsColumn(
                    section: section,
                    kind: AdsKind.services,
                    label: section.servicesLabel,
                    carousel: section.services,
                    accent: accent,
                    onBand: onBand,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 30,
            margin: const EdgeInsets.only(right: 11),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              section.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Readable ink for whatever backdrop the admin picked. A pale band keeps dark
  /// text even in dark mode — the band is its own surface, not the page's.
  Color _onBandColor(ColorScheme scheme) {
    final hex = section.backgroundColor;
    if (hex == null) return scheme.onSurface;
    final band = colorFromHex(hex, scheme.surface);
    return band.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}

/// One column: a label, a one-at-a-time carousel, and its dots.
class _AdsColumn extends StatefulWidget {
  const _AdsColumn({
    required this.section,
    required this.kind,
    required this.label,
    required this.carousel,
    required this.accent,
    required this.onBand,
  });

  final AdsSection section;
  final AdsKind kind;
  final String label;
  final AdsCarousel carousel;
  final Color accent;
  final Color onBand;

  @override
  State<_AdsColumn> createState() => _AdsColumnState();
}

class _AdsColumnState extends State<_AdsColumn> {
  late final PageController _controller;
  late double _page;

  @override
  void initState() {
    super.initState();
    // Endless: opens deep in the loop so it can be swiped either way forever.
    final initial = loopInitialPage(widget.carousel.all.length);
    _page = initial.toDouble();
    _controller = PageController(initialPage: initial);
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
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
    final ads = widget.carousel.all;
    final hasFeatured = widget.carousel.featured != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The image is square, so the card's height follows the column width.
        final cardHeight = constraints.maxWidth + _kTitleStrip;
        // Both columns reserve the featured height, so an empty or unfeatured
        // column does not leave the row ragged.
        final slotHeight = cardHeight + _kFeaturedExtra;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label + this column's own See all (opens only this kind).
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                      color: widget.onBand.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                if (ads.isNotEmpty)
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => context.push(
                      '/ads-section',
                      extra: AdsSectionPageArgs(
                          section: widget.section, kind: widget.kind),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 2, 0, 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'See all',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: widget.accent,
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: 15, color: widget.accent),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: slotHeight,
              child: ads.isEmpty
                  ? _EmptyColumn(onBand: widget.onBand, accent: widget.accent)
                  : PageView.builder(
                      controller: _controller,
                      itemCount: loopItemCount(ads.length),
                      // A view is the card the shopper actually lands on (plus the first one,
                      // tracked from itemBuilder below) — not every card the PageView pre-builds.
                      onPageChanged: (page) => recordAdImpression(
                          ads[loopIndex(page, ads.length)], adsSectionSeenAds),
                      itemBuilder: (context, page) {
                        final index = loopIndex(page, ads.length);
                        if (index == 0) recordAdImpression(ads[0], adsSectionSeenAds);
                        return _AdCard(
                        ad: ads[index],
                        // Featured is always first, and is the only taller card.
                        featured: hasFeatured && index == 0,
                        accent: widget.accent,
                        height: cardHeight,
                        featuredHeight: cardHeight + _kFeaturedExtra,
                      );
                      },
                    ),
            ),
            if (ads.length > 1) ...[
              const SizedBox(height: 8),
              _Dots(
                count: ads.length,
                current: loopIndex(_page.round(), ads.length),
                accent: widget.accent,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AdCard extends StatelessWidget {
  const _AdCard({
    required this.ad,
    required this.featured,
    required this.accent,
    required this.height,
    required this.featuredHeight,
  });

  final AdModel ad;
  final bool featured;
  final Color accent;
  final double height;
  final double featuredHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The square band image (Ad.carouselImage, 1080×1080) when the ad has one —
    // an Official ad's photos[0] is a 3:1 slot banner — else the first photo.
    final photo = ad.carouselCardImage;

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: featured ? featuredHeight : height,
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openAd(context, ad),
            // No outline: the photo and the surface edge frame the card.
            // (The accent border read as a stray blue box around every ad.)
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exactly square on every card (the Featured card's extra
                // height goes to its text), so a square creative is shown whole.
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (photo.isEmpty)
                        Container(
                          color: scheme.onSurface.withValues(alpha: 0.05),
                          child: Icon(
                            Icons.campaign_rounded,
                            size: 26,
                            color: scheme.onSurface.withValues(alpha: 0.25),
                          ),
                        )
                      else
                        CachedNetworkImage(
                          imageUrl: photo,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: scheme.onSurface.withValues(alpha: 0.05),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: scheme.onSurface.withValues(alpha: 0.05),
                            child: Icon(
                              Icons.campaign_rounded,
                              size: 26,
                              color: scheme.onSurface.withValues(alpha: 0.25),
                            ),
                          ),
                        ),
                      if (featured)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'FEATURED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ad.businessName.trim().isNotEmpty
                              ? ad.businessName
                              : ad.title,
                          maxLines: featured ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        // The Featured card's extra height carries the ad's
                        // title under the business name.
                        if (featured &&
                            ad.businessName.trim().isNotEmpty &&
                            ad.title.trim().isNotEmpty)
                          Text(
                            ad.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              height: 1.3,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
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

/// A column with nothing sold. It keeps its height so the two sides stay level
/// and the row does not jump when a slot is bought, and it says "Coming soon"
/// rather than "empty" — the slots exist and are for sale, which is worth
/// signalling to shoppers and advertisers alike.
class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn({required this.onBand, required this.accent});

  final Color onBand;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DottedPlaceholder(onBand: onBand, accent: accent);
  }
}

/// Shared "Coming soon" plate.
class DottedPlaceholder extends StatelessWidget {
  const DottedPlaceholder({
    super.key,
    required this.onBand,
    required this.accent,
  });

  final Color onBand;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.campaign_rounded,
                  size: 22, color: accent.withValues(alpha: 0.55)),
              const SizedBox(height: 8),
              Text(
                'Coming soon',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: accent.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'This space is\nopen for ads',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.3,
                  color: onBand.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({
    required this.count,
    required this.current,
    required this.accent,
  });

  final int count;
  final int current;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: i == current ? 14 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: i == current ? 1 : 0.28),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
