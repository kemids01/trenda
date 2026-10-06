// lib/features/home/presentation/ad_showcase_page.dart
// The advertiser's showcase: up to ten full-screen pages — the event flyer, the
// service menu, the price list — swiped one at a time.
//
// Horizontal paging rather than a long vertical scroll: each page is a whole
// creative the advertiser paid to have looked at, and paging makes "page 3 of 10"
// a thing the shopper can see. The pop-up ads' vertical `PopupLandingScreen` is
// a different product and is left alone.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_shared/models/ad_model.dart';
import 'package:trenda_shared/widgets/map_pin_button.dart';
import '../../ads/utils/ad_click_handler.dart' show recordAdClick;

/// Opens the right destination for an ad card.
///
/// One helper so the band and the see-all grid cannot drift apart: an ad with a
/// live showcase opens it, everything else keeps today's behaviour.
void openAd(BuildContext context, AdModel ad) {
  // The tap is the moment an advertiser pays for — record it before navigating. (This is the
  // only tap path for the Ads & Services band and its See-all grid.)
  recordAdClick(ad);
  if (ad.showcasePages.isEmpty) {
    context.push('/ad-details', extra: ad);
  } else {
    context.push('/ad-showcase', extra: ad);
  }
}

class AdShowcasePage extends StatefulWidget {
  final AdModel ad;

  const AdShowcasePage({super.key, required this.ad});

  @override
  State<AdShowcasePage> createState() => _AdShowcasePageState();
}

class _AdShowcasePageState extends State<AdShowcasePage> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final p = _controller.page?.round() ?? 0;
      if (p != _page) setState(() => _page = p);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.ad.showcasePages;
    final total = pages.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // The creatives own the screen — everything else floats over them.
            PageView.builder(
              controller: _controller,
              itemCount: total,
              itemBuilder: (context, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: pages[i],
                    fit: BoxFit.contain,
                    width: double.infinity,
                    placeholder: (_, __) => const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white24,
                        ),
                      ),
                    ),
                    // A page that will not load stays a page: the counter must
                    // keep matching what the advertiser was sold.
                    errorWidget: (_, __, ___) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_not_supported_outlined,
                              color: Colors.white24, size: 36),
                          SizedBox(height: 10),
                          Text(
                            'This page could not be loaded',
                            style: TextStyle(color: Colors.white38, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            _topBar(total),

            // The pin and the dots share one bottom overlay so neither can sit on
            // top of the other when an ad has both.
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.ad.location != null) ...[
                    Center(
                      child: MapPinButton(
                        location: widget.ad.location,
                        compact: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (total > 1) _dots(total),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(int total) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.65),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              tooltip: 'Close',
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.ad.businessName.trim().isNotEmpty
                        ? widget.ad.businessName
                        : widget.ad.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.ad.title.trim().isNotEmpty &&
                      widget.ad.businessName.trim().isNotEmpty)
                    Text(
                      widget.ad.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_page + 1} / $total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dots(int total) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _page ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: i == _page ? 0.95 : 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
