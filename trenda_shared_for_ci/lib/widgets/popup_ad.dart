// lib/widgets/popup_ad.dart
// Pop Up ads: one dismissible modal shown when an app opens, holding EVERY live
// pop-up as a swipeable carousel. Tap (customer/vendor only) → scrollable landing images or a
// product deep-link. Self-contained: plain http, never throws, degrades to nothing.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../core/config.dart';
import 'official_ad_slot.dart' show OfficialAdsRepository, officialAdMunicipality;

/// A pop-up ad served on app open.
class PopupAdItem {
  final String id;
  final List<String> images; // carousel images
  final String audience; // frontend | vendor | supplier | rider
  final String tapAction; // none | landing | product
  final String productId; // frontend: marketplace product; vendor: supplier product
  final List<String> landingImages; // scrollable full-width images

  const PopupAdItem({
    required this.id,
    required this.images,
    required this.audience,
    required this.tapAction,
    required this.productId,
    required this.landingImages,
  });

  factory PopupAdItem.fromJson(Map<String, dynamic> j) => PopupAdItem(
        id: (j['id'] ?? '').toString(),
        images: ((j['images'] as List?) ?? [])
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList(),
        audience: (j['audience'] ?? '').toString(),
        tapAction: (j['tapAction'] ?? 'none').toString(),
        productId: (j['productId'] ?? '').toString(),
        landingImages: ((j['landingImages'] as List?) ?? [])
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList(),
      );

  bool get tappable =>
      (tapAction == 'landing' && landingImages.isNotEmpty) ||
      (tapAction == 'product' && productId.isNotEmpty);
}

class PopupAdsRepository {
  /// [municipality] overrides the process-global `officialAdMunicipality` (some
  /// apps know their municipality before the ad-slot global is set).
  static Future<List<PopupAdItem>> forAudience(String audience,
      {String? municipality}) async {
    try {
      final muni = (municipality != null && municipality.isNotEmpty)
          ? municipality
          : officialAdMunicipality;
      final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/ads/popup').replace(
        queryParameters: {
          'audience': audience,
          if (muni != null && muni.isNotEmpty) 'municipality': muni,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? [];
      return list
          .map((e) => PopupAdItem.fromJson(e as Map<String, dynamic>))
          .where((p) => p.images.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}

/// App-supplied handler for a pop-up `product` tap. The shared package has no
/// route knowledge: the host app pushes its product/supplier-product screen.
typedef PopupProductTapHandler = void Function(
    BuildContext context, String productId);

/// Audiences that have already shown a pop-up this process launch. "Every app
/// open" == every cold launch, not every navigation/rebuild.
final Set<String> _popupShownThisLaunch = {};

/// Resets the once-per-launch guard (useful for tests / manual re-trigger).
void resetPopupAdGuard() => _popupShownThisLaunch.clear();

/// One swipeable page of the pop-up: an image and the ad it belongs to.
typedef PopupPage = ({PopupAdItem ad, String image});

/// Every live pop-up's images as ONE run of pages, in the order the backend
/// sent the ads (highest priority first). Pure, so the order is testable.
List<PopupPage> popupPages(List<PopupAdItem> ads) => [
      for (final ad in ads)
        for (final image in ad.images) (ad: ad, image: image),
    ];

/// Wrap an app's post-login home. On first build (per launch) it fetches the
/// pop-ups for [audience] and shows them ALL in one dismissible, swipeable
/// modal over [child].
class PopupAdHost extends StatefulWidget {
  final String audience;
  final Widget child;
  final PopupProductTapHandler? onProductTap;
  /// Explicit municipality for targeting (overrides the global). Pass this when
  /// the app knows its municipality before the ad-slot global is populated,
  /// otherwise municipality-targeted pop-ups are missed on cold launch.
  final String? municipality;

  const PopupAdHost({
    super.key,
    required this.audience,
    required this.child,
    this.onProductTap,
    this.municipality,
  });

  @override
  State<PopupAdHost> createState() => _PopupAdHostState();
}

class _PopupAdHostState extends State<PopupAdHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (_popupShownThisLaunch.contains(widget.audience)) return;
    _popupShownThisLaunch.add(widget.audience);
    final ads = await PopupAdsRepository.forAudience(widget.audience,
        municipality: widget.municipality);
    if (!mounted || ads.isEmpty) return;
    // Every live pop-up, in one dialog. The dialog counts each ad's impression
    // as its first page appears, and returns the ad the shopper tapped (null
    // on dismiss); the host navigates with its OWN stable context.
    final tapped = await showDialog<PopupAdItem>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PopupAdDialog(ads: ads),
    );
    if (!mounted || tapped == null) return;
    OfficialAdsRepository.track(tapped.id, 'click');
    if (tapped.tapAction == 'landing') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PopupLandingScreen(images: tapped.landingImages),
      ));
    } else if (tapped.tapAction == 'product') {
      widget.onProductTap?.call(context, tapped.productId);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The pop-up modal: every live ad's images as one swipeable, looping run.
/// Tapping a page pops with that page's ad (if it is tappable).
class PopupAdDialog extends StatefulWidget {
  final List<PopupAdItem> ads;
  const PopupAdDialog({super.key, required this.ads});

  @override
  State<PopupAdDialog> createState() => _PopupAdDialogState();
}

class _PopupAdDialogState extends State<PopupAdDialog> {
  /// Rounds of pages on each side of the opening page, so swiping either way
  /// loops and neither end is ever reached.
  static const _loopCycles = 500;

  late final List<PopupPage> _pages = popupPages(widget.ads);
  late final PageController _controller =
      PageController(initialPage: _loops ? _pages.length * _loopCycles : 0);
  final Set<String> _counted = {}; // ad ids whose impression is recorded
  Timer? _timer;
  int _index = 0;

  bool get _loops => _pages.length > 1;

  @override
  void initState() {
    super.initState();
    if (_pages.isNotEmpty) _countImpression(0);
    if (_loops) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) => _advance());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _countImpression(int i) {
    final ad = _pages[i].ad;
    if (_counted.add(ad.id)) OfficialAdsRepository.track(ad.id, 'impression');
  }

  void _advance() {
    if (!mounted || !_loops || !_controller.hasClients) return;
    // Forward into the first page after the last, never a rewind.
    _controller.nextPage(
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  void _onPageChanged(int page) {
    final i = page % _pages.length;
    setState(() => _index = i);
    _countImpression(i);
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) return const SizedBox.shrink();
    final current = _pages[_index].ad;
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: size.height * 0.7,
                      maxWidth: size.width,
                    ),
                    child: AspectRatio(
                      aspectRatio: 4 / 5,
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _loops ? null : _pages.length,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (_, page) {
                          final p = _pages[page % _pages.length];
                          return GestureDetector(
                            // The whole page is the target, even before
                            // its image has loaded.
                            behavior: HitTestBehavior.opaque,
                            onTap: p.ad.tappable
                                ? () => Navigator.of(context).pop(p.ad)
                                : null,
                            child: CachedNetworkImage(
                              imageUrl: p.image,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  Container(color: Colors.grey.shade300),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (_loops)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      key: const ValueKey('popup-ad-dots'),
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_pages.length, (i) {
                        final active = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active ? Colors.white : Colors.white54,
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 2)
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                if (current.tappable)
                  const Positioned(
                    bottom: 26,
                    child: IgnorePointer(
                      child: Chip(
                        label: Text('Tap to view'),
                        backgroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // One close button dismisses every pop-up.
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.close, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-page scrollable landing: full-width images stacked with no gaps.
class PopupLandingScreen extends StatelessWidget {
  final List<String> images;
  const PopupLandingScreen({super.key, required this.images});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: images.length,
        itemBuilder: (_, i) => CachedNetworkImage(
          imageUrl: images[i],
          width: double.infinity,
          fit: BoxFit.fitWidth,
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
