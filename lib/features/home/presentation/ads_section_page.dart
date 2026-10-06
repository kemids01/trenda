// lib/features/home/presentation/ads_section_page.dart
// "See all" for ONE carousel of the Ads & Services band — Top 10 Vendor Ads or
// Top 10 Services, each on its own page.
//
// The band shows ~180px cards; here each ad gets most of the screen: a
// semi-full-screen carousel where the current ad fills the width and the
// neighbours peek in at the edges, so it is obvious there is more to swipe.
// Every ad on this page was paid for, so the creative is the hero — the text
// sits on a scrim over the photo instead of taking space below it.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:trenda_shared/models/ad_model.dart';
import '../providers/ads_section_provider.dart';
import '../providers/official_collections_provider.dart' show colorFromHex;
import 'ad_showcase_page.dart' show openAd;
import 'widgets/ads_section_band.dart' show adsSectionSeenAds;
import '../../ads/utils/ad_click_handler.dart' show recordAdImpression;

/// Which of the band's two carousels a See-all page shows.
enum AdsKind { vendor, services }

/// Route payload for `/ads-section`.
class AdsSectionPageArgs {
  final AdsSection section;
  final AdsKind kind;

  const AdsSectionPageArgs({required this.section, required this.kind});
}

/// How much of the width the current card takes; the rest is the neighbours'
/// peek. Also used to scale the neighbours down a little for depth.
const double _kViewportFraction = 0.86;
const double _kNeighbourScale = 0.92;

/// The card's shape: 9:16, a phone story. Locked so an ad's See-all image
/// (uploaded at 1080×1920 in admin ▸ Ad Placements) shows uncropped on every
/// phone. Before, the card stretched to fill the screen, so its shape — and
/// what any image lost to cropping — changed from phone to phone.
const double kAdsSeeAllCardAspect = 9 / 16;

class AdsSectionPage extends StatefulWidget {
  final AdsSection section;
  final AdsKind kind;

  const AdsSectionPage({super.key, required this.section, required this.kind});

  @override
  State<AdsSectionPage> createState() => _AdsSectionPageState();
}

class _AdsSectionPageState extends State<AdsSectionPage> {
  final _controller = PageController(viewportFraction: _kViewportFraction);
  double _page = 0;

  AdsCarousel get _carousel => widget.kind == AdsKind.vendor
      ? widget.section.vendor
      : widget.section.services;

  String get _title => widget.kind == AdsKind.vendor
      ? widget.section.vendorLabel
      : widget.section.servicesLabel;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final p = _controller.page;
      if (p != null && p != _page) setState(() => _page = p);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = colorFromHex(widget.section.accentColor, scheme.primary);
    final ads = _carousel.all;
    final hasFeatured = _carousel.featured != null;
    final current = ads.isEmpty ? 0 : _page.round().clamp(0, ads.length - 1);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF0E1116)
          : const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              widget.section.title,
              style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.55)),
            ),
          ],
        ),
      ),
      body: ads.isEmpty
          ? Center(
              child: Text('No ads here yet',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            )
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: ads.length,
                      itemBuilder: (context, i) {
                        // 1 on the current card, easing to _kNeighbourScale
                        // one page away.
                        final distance = (i - _page).abs().clamp(0.0, 1.0);
                        final scale = 1 - (1 - _kNeighbourScale) * distance;
                        return Transform.scale(
                          scale: scale,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            // The largest 9:16 card that fits the space.
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: kAdsSeeAllCardAspect,
                                child: _HeroAdCard(
                                  ad: ads[i],
                                  rank: hasFeatured ? i : i + 1,
                                  featured: hasFeatured && i == 0,
                                  accent: accent,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Pager(
                    count: ads.length,
                    current: current,
                    accent: accent,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

/// One ad, near full screen: the photo fills the card, a scrim carries the
/// rank, the business, the title and a call to action.
class _HeroAdCard extends StatelessWidget {
  const _HeroAdCard({
    required this.ad,
    required this.rank,
    required this.featured,
    required this.accent,
  });

  final AdModel ad;

  /// Slot number (1–10); 0 for the Featured ad, which has no number.
  final int rank;
  final bool featured;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // Deduped per session (shared with the Shop-tab band), so scrolling back never re-counts.
    recordAdImpression(ad, adsSectionSeenAds);
    final scheme = Theme.of(context).colorScheme;
    // The ad's own 9:16 See-all creative, when the admin uploaded one. It is
    // designed for this card, carries its own text, and is shown as-is — so
    // nothing is drawn over it but the slot badge. Without one, the card photo
    // fills the card with the business and title on a scrim, as before.
    final tall = ad.seeAllImage;
    final photo = tall ?? (ad.photos.isNotEmpty ? ad.photos.first : '');
    final business =
        ad.businessName.trim().isNotEmpty ? ad.businessName : ad.title;
    final showTitle =
        ad.title.trim().isNotEmpty && ad.title.trim() != business.trim();
    final description = (ad.description ?? '').trim();

    Widget placeholder() => Container(
          color: scheme.surfaceContainerHighest,
          child: Icon(Icons.campaign_rounded,
              size: 48, color: scheme.onSurface.withValues(alpha: 0.25)),
        );

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: () => openAd(context, ad),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo.isEmpty)
              placeholder()
            else
              CachedNetworkImage(
                imageUrl: photo,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: scheme.surfaceContainerHighest),
                errorWidget: (_, __, ___) => placeholder(),
              ),
            // Scrim so white text reads on any photo.
            if (tall == null)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 1],
                    colors: [Colors.transparent, Color(0xD9000000)],
                  ),
                ),
              ),
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:
                      featured ? accent : Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  featured ? 'FEATURED' : '#$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
            if (tall == null)
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (showTitle) ...[
                      const SizedBox(height: 4),
                      Text(
                        ad.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded,
                              size: 16, color: Colors.black),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dots plus "3 / 10", so the shopper knows how far through the ten they are.
class _Pager extends StatelessWidget {
  const _Pager({
    required this.count,
    required this.current,
    required this.accent,
  });

  final int count;
  final int current;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == current ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: i == current ? 1 : 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${current + 1} / $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
