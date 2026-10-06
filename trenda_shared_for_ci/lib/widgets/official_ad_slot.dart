// lib/widgets/official_ad_slot.dart
// Self-contained official-ad slot renderer. No app-provider dependency (mirrors
// AppConfigGate): plain http, never throws, degrades to SizedBox.shrink().
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../core/config.dart';
import '../core/ads/ad_tracking_identity.dart';
import '../models/ad_placement.dart';
import '../models/map_pin.dart';
import 'official_ad_detail_screen.dart';

// The tap-through screen lives in its own file; re-exported so every existing
// `import 'official_ad_slot.dart'` still sees OfficialAdDetailScreen.
export 'official_ad_detail_screen.dart' show OfficialAdDetailScreen;

/// App-supplied handler for `store` / `product` CTA deep-links. The shared package
/// has no knowledge of app routes, so a host app registers this ONCE at startup
/// (e.g. in `main()`); when it is null, store/product CTAs are hidden. `url` CTAs
/// never need it (handled here via url_launcher).
typedef OfficialAdDeepLinkHandler = void Function(
    BuildContext context, String type, String targetId);
OfficialAdDeepLinkHandler? officialAdDeepLinkHandler;

/// Current municipality supplied by the host app (e.g. the consumer's selected
/// area). When non-null, the serve endpoint scopes municipality-targeted ads to
/// it; untargeted ads (no municipalities) always show. Apps keep this updated as
/// the user's municipality changes.
String? officialAdMunicipality;

class OfficialAdCta {
  final String type; // none|store|product|url
  final String label;
  final String targetId;
  final String url;
  const OfficialAdCta({this.type = 'none', this.label = '', this.targetId = '', this.url = ''});
  factory OfficialAdCta.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    return OfficialAdCta(
      type: (j['type'] ?? 'none').toString(),
      label: (j['label'] ?? '').toString(),
      targetId: (j['targetId'] ?? '').toString(),
      url: (j['url'] ?? '').toString(),
    );
  }
}

class OfficialAdLanding {
  final bool enabled;
  final String image; // full-page image shown when the ad is tapped (falls back to the slot image)
  final String headline;
  final String body;
  final OfficialAdCta cta;
  const OfficialAdLanding({this.enabled = false, this.image = '', this.headline = '', this.body = '', this.cta = const OfficialAdCta()});
  factory OfficialAdLanding.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    return OfficialAdLanding(
      enabled: j['enabled'] == true,
      image: (j['image'] ?? '').toString(),
      headline: (j['headline'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      cta: OfficialAdCta.fromJson(j['cta'] as Map<String, dynamic>?),
    );
  }
}

class OfficialAdItem {
  final String id;
  final String title;
  final String businessName;
  final String description;
  final String image;
  final bool tappable;
  final String badgeText;
  final double weight; // A/B weight for weighted selection (default 1)
  final OfficialAdLanding landing;
  /// The advertiser's map pin, flattened by the serve DTO. Null when unpinned.
  final MapPin? location;
  const OfficialAdItem({
    required this.id,
    required this.title,
    required this.businessName,
    required this.description,
    required this.image,
    required this.tappable,
    required this.badgeText,
    required this.weight,
    required this.landing,
    this.location,
  });
  factory OfficialAdItem.fromJson(Map<String, dynamic> j) => OfficialAdItem(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        businessName: (j['businessName'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        image: (j['image'] ?? '').toString(),
        tappable: j['tappable'] == true,
        badgeText: (j['badgeText'] ?? 'Trenda Official').toString(),
        weight: (j['weight'] is num) ? (j['weight'] as num).toDouble() : 1.0,
        landing: OfficialAdLanding.fromJson(j['landing'] as Map<String, dynamic>?),
        location: MapPin.fromJson(
          j['location'] is Map ? Map<String, dynamic>.from(j['location'] as Map) : null,
        ),
      );
}

/// Weighted pick: returns an index into [weights] chosen by [roll] (0.0–1.0).
/// Weights ≤ 0 are never picked; all-zero → index 0. Pure + deterministic for
/// a given roll (used for A/B selection of official ads).
int weightedPickIndex(List<num> weights, double roll) {
  if (weights.isEmpty) return 0;
  final total = weights.fold<double>(0, (s, w) => s + (w > 0 ? w.toDouble() : 0));
  if (total <= 0) return 0;
  var r = roll.clamp(0.0, 0.9999999) * total;
  for (var i = 0; i < weights.length; i++) {
    final w = weights[i] > 0 ? weights[i].toDouble() : 0.0;
    if (r < w) return i;
    r -= w;
  }
  return weights.length - 1;
}

class OfficialAdsRepository {
  static Future<List<OfficialAdItem>> forSlot(String slotId) async {
    try {
      final muni = officialAdMunicipality;
      final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/ads/official').replace(
        queryParameters: {
          'slot': slotId,
          if (muni != null && muni.isNotEmpty) 'municipality': muni,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? [];
      return list.map((e) => OfficialAdItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static void track(String id, String kind) {
    // kind = 'impression' | 'click'; fire-and-forget. The identity headers let the backend count
    // unique viewers / tappers (AdTrackingIdentity); they never delay the host screen.
    () async {
      try {
        await http
            .post(Uri.parse('${AppConfig.backendBaseUrl}/api/ads/official/$id/$kind'),
                headers: await AdTrackingIdentity.headers())
            .timeout(const Duration(seconds: 6));
      } catch (_) {}
    }();
  }
}

/// Horizontal inset of a standard (not full-bleed) ad card, each side.
const double kOfficialAdCardInset = 12;

/// Height of an ad card in a slot [maxWidth] wide. An explicit [height] wins
/// (the full-width heroes match the Shop tab's Featured card). Otherwise the
/// card takes its slot's recommended SHAPE — 1200×400 → 3:1 of the card's own
/// width — so a correctly sized creative fits exactly, on every phone. The old
/// fixed recHeight/3 (133px) made a 2.5–2.9:1 box that cropped a 3:1 banner.
double officialAdCardHeight({
  required String slotId,
  required double maxWidth,
  bool fullBleed = false,
  double? height,
}) {
  if (height != null) return height;
  final slot = adSlotById(slotId);
  final w = slot?.recWidth ?? 1200;
  final h = slot?.recHeight ?? 400;
  if (!maxWidth.isFinite) return h / 3;
  final cardWidth = maxWidth - (fullBleed ? 0 : kOfficialAdCardInset * 2);
  return cardWidth * h / w;
}

class OfficialAdSlot extends StatefulWidget {
  final String slotId;
  final double? height;
  /// Edge-to-edge banner: no horizontal inset and no rounded corners. Default
  /// false preserves the standard padded/rounded card used at most placements.
  final bool fullBleed;

  /// Drawn while nothing is showing (loading, or no live ad), e.g. a spacer a
  /// host wants only when the ad is absent. Null = nothing (SizedBox.shrink).
  final Widget? whenEmpty;
  const OfficialAdSlot(
      {super.key,
      required this.slotId,
      this.height,
      this.fullBleed = false,
      this.whenEmpty});
  @override
  State<OfficialAdSlot> createState() => _OfficialAdSlotState();
}

class _OfficialAdSlotState extends State<OfficialAdSlot> {
  // A slot may hold several live ads. We rotate through all of them as an
  // auto-advancing carousel (every 5s). Each ad is counted once per mount, as it
  // first appears, so per-variant impression/click/CTR stays meaningful. A single
  // ad renders static (no timer, no controls).
  List<OfficialAdItem> _ads = const [];
  bool _loaded = false;
  int _index = 0;
  final Set<String> _tracked = {}; // ad ids already counted this mount
  PageController? _pageController;
  Timer? _timer;

  static const _rotateEvery = Duration(seconds: 5);

  /// Rounds of the ad list before the opening page — never reached by a swipe.
  static const _loopCycles = 500;


  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ads = await OfficialAdsRepository.forSlot(widget.slotId);
    if (!mounted) return;
    // Set the controller/timer before setState so build() always has them ready.
    if (ads.length > 1) {
      // Endless: opens deep in an unbounded PageView, so the rotation and the
      // shopper's swipes both run on past the last ad into the first.
      _pageController = PageController(initialPage: ads.length * _loopCycles);
      _timer = Timer.periodic(_rotateEvery, (_) => _advance());
    }
    setState(() {
      _ads = ads;
      _loaded = true;
      _index = 0;
    });
    if (ads.isNotEmpty) _trackImpression(0);
  }

  void _advance() {
    final c = _pageController;
    if (!mounted || c == null || _ads.length < 2 || !c.hasClients) return;
    // nextPage, not animateToPage(0): from the last ad it slides forward
    // into the first instead of rewinding back through every ad.
    c.nextPage(
        duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
  }

  void _trackImpression(int i) {
    if (i < 0 || i >= _ads.length) return;
    if (_tracked.add(_ads[i].id)) {
      OfficialAdsRepository.track(_ads[i].id, 'impression');
    }
  }

  void _onPageChanged(int page) {
    final i = page % _ads.length;
    setState(() => _index = i);
    _trackImpression(i);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ads.isEmpty) {
      return widget.whenEmpty ?? const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) => _buildAds(officialAdCardHeight(
        slotId: widget.slotId,
        maxWidth: constraints.maxWidth,
        fullBleed: widget.fullBleed,
        height: widget.height,
      )),
    );
  }

  Widget _buildAds(double height) {
    if (_ads.length == 1) {
      return _AdCard(
          ad: _ads.first, height: height, fullBleed: widget.fullBleed);
    }
    // Carousel height = card height + the _AdCard vertical padding (4 + 4),
    // which is zero when full-bleed.
    return SizedBox(
      height: height + (widget.fullBleed ? 0 : 8),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            // No itemCount: unbounded, mapped back onto the ads by modulo.
            onPageChanged: _onPageChanged,
            itemBuilder: (_, page) => _AdCard(
                ad: _ads[page % _ads.length],
                height: height,
                fullBleed: widget.fullBleed),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_ads.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdCard extends StatelessWidget {
  final OfficialAdItem ad;
  final double height;
  final bool fullBleed;
  const _AdCard({required this.ad, required this.height, this.fullBleed = false});

  void _open(BuildContext context) {
    OfficialAdsRepository.track(ad.id, 'click');
    if (!ad.tappable) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => OfficialAdDetailScreen(ad: ad)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: fullBleed
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(
              horizontal: kOfficialAdCardInset, vertical: 4),
      child: GestureDetector(
        onTap: ad.tappable ? () => _open(context) : null,
        child: ClipRRect(
          borderRadius:
              fullBleed ? BorderRadius.zero : BorderRadius.circular(12),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: ad.image.isEmpty
                ? Container(color: Colors.grey.shade200)
                : CachedNetworkImage(
                    imageUrl: ad.image,
                    // The WHOLE creative, forced to the card. A creative at
                    // the slot's recommended size fits exactly (the card takes
                    // that shape — see officialAdCardHeight; the heroes are
                    // within ~2%); any other size is stretched, never cropped.
                    fit: BoxFit.fill,
                    errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200),
                  ),
          ),
        ),
      ),
    );
  }
}
