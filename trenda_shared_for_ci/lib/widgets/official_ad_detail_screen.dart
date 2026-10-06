// lib/widgets/official_ad_detail_screen.dart
// What a shopper sees after tapping an Official Trenda ad in any placement slot
// (customer, vendor and supplier apps all open this one screen).
//
// Layout: the full poster, then a "coupon" card that rides up over its bottom
// edge. The card leads with the offer, tears along a perforation, and lists the
// fine print as scannable rows (Where / How to avail / Valid until) built by
// parseAdCopy from the admin's free-text body. The action stays pinned to the
// bottom so it is never scrolled away.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/ads/ad_copy.dart';
import 'official_ad_slot.dart';

const _kGold = Color(0xFFC9971C);
const _kGoldSoft = Color(0xFFF6E7BF);

class OfficialAdDetailScreen extends StatelessWidget {
  final OfficialAdItem ad;
  const OfficialAdDetailScreen({super.key, required this.ad});

  bool get _hasCta {
    final cta = ad.landing.cta;
    return (cta.type == 'url' && cta.url.isNotEmpty) ||
        ((cta.type == 'store' || cta.type == 'product') &&
            cta.targetId.isNotEmpty &&
            officialAdDeepLinkHandler != null);
  }

  String get _ctaLabel {
    final cta = ad.landing.cta;
    if (cta.label.isNotEmpty) return cta.label;
    switch (cta.type) {
      case 'store':
        return 'Visit Store';
      case 'product':
        return 'View Product';
      default:
        return 'Learn more';
    }
  }

  IconData get _ctaIcon {
    switch (ad.landing.cta.type) {
      case 'store':
        return Icons.storefront_rounded;
      case 'product':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.open_in_new_rounded;
    }
  }

  Future<void> _cta(BuildContext context) async {
    final cta = ad.landing.cta;
    if (cta.type == 'url' && cta.url.isNotEmpty) {
      final uri = Uri.tryParse(cta.url);
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    // store/product deep-links are handled by the host app (registered handler).
    if ((cta.type == 'store' || cta.type == 'product') && cta.targetId.isNotEmpty) {
      officialAdDeepLinkHandler?.call(context, cta.type, cta.targetId);
    }
  }

  Future<void> _directions(BuildContext context) async {
    final loc = ad.location;
    if (loc == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await launchUrl(Uri.parse(loc.mapsUrl), mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger?.showSnackBar(const SnackBar(content: Text('Could not open Maps on this device')));
    }
  }

  void _zoom(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PosterViewer(url: url),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final page = dark ? const Color(0xFF0F1115) : const Color(0xFFF4F1EA);
    final l = ad.landing;
    final image = l.image.isNotEmpty ? l.image : ad.image;
    var headline = l.headline.isNotEmpty ? l.headline : ad.title;
    // The card already names the business above the headline; "Jollibee:
    // Chickenjoy…" would say it twice.
    final prefix = '${ad.businessName}:';
    if (ad.businessName.isNotEmpty && headline.toLowerCase().startsWith(prefix.toLowerCase())) {
      headline = headline.substring(prefix.length).trim();
    }
    final copy = parseAdCopy(l.body.isNotEmpty ? l.body : ad.description);

    return Scaffold(
      backgroundColor: page,
      appBar: AppBar(
        backgroundColor: page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          ad.businessName.isNotEmpty ? ad.businessName : 'Promotion',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (image.isNotEmpty)
            GestureDetector(
              onTap: () => _zoom(context, image),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: image,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    placeholder: (_, __) => AspectRatio(
                      aspectRatio: 4 / 5,
                      child: ColoredBox(color: theme.colorScheme.onSurface.withValues(alpha: 0.06)),
                    ),
                    errorWidget: (_, __, ___) => const SizedBox(height: 120),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _GlassPill(icon: Icons.zoom_out_map_rounded, label: 'Tap to zoom'),
                  ),
                ],
              ),
            ),
          Transform.translate(
            offset: Offset(0, image.isNotEmpty ? -28 : 12),
            child: _Reveal(
              order: 0,
              child: _CouponCard(
                page: page,
                badge: ad.badgeText,
                business: ad.businessName,
                headline: headline,
                copy: copy,
                onDirections: ad.location == null ? null : () => _directions(context),
                directionsLabel: ad.location?.buttonLabel,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: (_hasCta || ad.location != null)
          ? _ActionBar(
              page: page,
              primaryLabel: _hasCta ? _ctaLabel : null,
              primaryIcon: _ctaIcon,
              onPrimary: _hasCta ? () => _cta(context) : null,
              onDirections: ad.location == null ? null : () => _directions(context),
            )
          : null,
    );
  }
}

// ── Coupon card ─────────────────────────────────────────────────────────────

class _CouponCard extends StatelessWidget {
  final Color page;
  final String badge;
  final String business;
  final String headline;
  final AdCopy copy;
  final VoidCallback? onDirections;
  final String? directionsLabel;

  const _CouponCard({
    required this.page,
    required this.badge,
    required this.business,
    required this.headline,
    required this.copy,
    this.onDirections,
    this.directionsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final card = dark ? const Color(0xFF1A1D23) : Colors.white;
    final ink = dark ? Colors.white : const Color(0xFF15171C);
    final muted = ink.withValues(alpha: 0.62);
    final hasDetails = copy.features.isNotEmpty || copy.facts.isNotEmpty || copy.notes.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.40 : 0.07),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A gold hairline across the top edge — the "official" seal.
          Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_kGold, Color(0xFFF2D27A), _kGold]),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _OfficialBadge(text: badge),
                    const Spacer(),
                    if (copy.facts.any((f) => f.kind == AdFactKind.valid))
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, size: 15, color: scheme.error),
                          const SizedBox(width: 2),
                          Text('Limited time',
                              style: TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w800, color: scheme.error)),
                        ],
                      ),
                  ],
                ),
                if (business.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    business.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w800,
                      color: muted,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.12,
                    letterSpacing: -0.6,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
                if (copy.lead.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    copy.lead,
                    style: TextStyle(fontSize: 15.5, height: 1.45, color: ink.withValues(alpha: 0.82)),
                  ),
                ],
                if (copy.features.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Reveal(
                    order: 1,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final f in copy.features) _FeatureChip(label: f)],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (copy.facts.isNotEmpty || copy.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Perforation(page: page),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 6),
              child: Column(
                children: [
                  for (final (i, f) in copy.facts.indexed)
                    _Reveal(
                      order: 2 + i,
                      child: _FactRow(
                        fact: f,
                        ink: ink,
                        muted: muted,
                        onTap: f.kind == AdFactKind.where ? onDirections : null,
                      ),
                    ),
                  for (final n in copy.notes)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(n, style: TextStyle(fontSize: 13.5, height: 1.45, color: muted)),
                    ),
                ],
              ),
            ),
          ],
          // A pin with no "Where" line still earns a row.
          if (onDirections != null && !copy.facts.any((f) => f.kind == AdFactKind.where))
            Padding(
              padding: EdgeInsets.fromLTRB(22, hasDetails ? 0 : 8, 22, 6),
              child: _FactRow(
                fact: AdFact('Location', directionsLabel ?? 'See location', AdFactKind.where),
                ink: ink,
                muted: muted,
                onTap: onDirections,
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _OfficialBadge extends StatelessWidget {
  final String text;
  const _OfficialBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: _kGoldSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kGold.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, size: 14, color: _kGold),
          const SizedBox(width: 5),
          Text(
            (text.isEmpty ? 'Trenda Official' : text).toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w900,
              color: Color(0xFF7A5A0A),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  const _FeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_offer_rounded, size: 13, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: scheme.primary)),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final AdFact fact;
  final Color ink;
  final Color muted;
  final VoidCallback? onTap;
  const _FactRow({required this.fact, required this.ink, required this.muted, this.onTap});

  static const _style = <AdFactKind, (IconData, Color)>{
    AdFactKind.where: (Icons.place_rounded, Color(0xFFE5484D)),
    AdFactKind.howTo: (Icons.confirmation_number_rounded, Color(0xFF3E63DD)),
    AdFactKind.valid: (Icons.event_available_rounded, Color(0xFF30A46C)),
    AdFactKind.price: (Icons.payments_rounded, Color(0xFFC9971C)),
    AdFactKind.contact: (Icons.call_rounded, Color(0xFF0091FF)),
    AdFactKind.hours: (Icons.schedule_rounded, Color(0xFF8E4EC6)),
    AdFactKind.other: (Icons.info_rounded, Color(0xFF6F6E77)),
  };

  String get _label => switch (fact.kind) {
        AdFactKind.valid => 'Valid until',
        _ => fact.label,
      };

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// (value, fine print). "Promo runs until December 31, 2026. While supplies
  /// last." → ("December 31, 2026", "While supplies last.").
  (String, String?) get _parts {
    if (fact.kind != AdFactKind.valid) return (_cap(fact.value), null);
    final m = RegExp(r'\buntil\s+(.+?)(?:\.\s+(.+))?\.?$', caseSensitive: false)
        .firstMatch(fact.value);
    if (m == null) return (_cap(fact.value), null);
    return (m.group(1)!.trim(), m.group(2)?.trim());
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style[fact.kind]!;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label.toUpperCase(),
                  style: TextStyle(fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: muted),
                ),
                const SizedBox(height: 3),
                Text(_parts.$1,
                    style: TextStyle(fontSize: 14.5, height: 1.38, fontWeight: FontWeight.w600, color: ink)),
                if (_parts.$2 != null) ...[
                  const SizedBox(height: 2),
                  Text(_parts.$2!, style: TextStyle(fontSize: 12.5, height: 1.35, color: muted)),
                ],
              ],
            ),
          ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: Icon(Icons.chevron_right_rounded, color: muted),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: row);
  }
}

/// The tear line: two half-circle notches cut into the card's edges (painted in
/// the page colour) joined by a dashed rule.
class _Perforation extends StatelessWidget {
  final Color page;
  const _Perforation({required this.page});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CustomPaint(
                painter: _DashPainter((dark ? Colors.white : Colors.black).withValues(alpha: 0.16)),
              ),
            ),
          ),
          Positioned(left: -11, top: 0, child: _Notch(color: page)),
          Positioned(right: -11, top: 0, child: _Notch(color: page)),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  final Color color;
  const _Notch({required this.color});
  @override
  Widget build(BuildContext context) =>
      Container(width: 22, height: 22, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, y), Offset((x + 5).clamp(0, size.width), y), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

// ── Pinned action bar ───────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final Color page;
  final String? primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final VoidCallback? onDirections;

  const _ActionBar({
    required this.page,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasPrimary = primaryLabel != null && onPrimary != null;
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF15181D) : Colors.white,
        border: Border(top: BorderSide(color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.07))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              if (onDirections != null)
                hasPrimary
                    ? SizedBox(
                        height: 52,
                        width: 56,
                        child: OutlinedButton(
                          onPressed: onDirections,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Icon(Icons.near_me_rounded),
                        ),
                      )
                    : Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: onDirections,
                            icon: const Icon(Icons.near_me_rounded),
                            label: const Text('Get directions',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ),
              if (onDirections != null && hasPrimary) const SizedBox(width: 10),
              if (hasPrimary)
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(primaryIcon, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              primaryLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small pieces ────────────────────────────────────────────────────────────

class _GlassPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _GlassPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Fade + rise on first build, later items a beat behind the earlier ones.
/// Stateless (TweenAnimationBuilder) — no setState.
class _Reveal extends StatelessWidget {
  final int order;
  final Widget child;
  const _Reveal({required this.order, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + order * 90),
      curve: Curves.easeOutCubic,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: c),
      ),
      child: child,
    );
  }
}

class _PosterViewer extends StatelessWidget {
  final String url;
  const _PosterViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
      body: Center(
        child: InteractiveViewer(
          maxScale: 4,
          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
