// lib/features/home/presentation/widgets/flash_sale_band.dart
// ⚡ The Shop tab's Flash Sale band — right under the lane buttons.
//
// An "electric arcade" strip: a hot red→orange gradient crossed by faint
// lightning stripes, a pulsing bolt, a heavy italic FLASH SALE, and flip-style
// countdown tiles. Each card carries a skewed volt-yellow discount tag and a
// sold bar with a moving shine. Nothing live but one coming up → the band
// counts down to it instead. Nothing at all → the band is not built.
//
// Prices here are DISPLAY only; the server charges the flash price at checkout.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/flash_sale_provider.dart';
import '../../utils/flash_sale_logic.dart';

const kFlashRed = Color(0xFFE5170B);
const kFlashOrange = Color(0xFFFF6A00);
const kFlashAmber = Color(0xFFFFA000);
const kFlashVolt = Color(0xFFFFE600);
const kFlashInk = Color(0xFF1A0500);

/// The campaign's colours (admin ▸ Flash Sales ▸ campaign form), handed to every flash widget
/// below it. Outside a scope — e.g. the discount tag on product detail — the default applies.
class FlashPaletteScope extends InheritedWidget {
  final FlashPalette palette;
  const FlashPaletteScope({super.key, required this.palette, required super.child});

  static FlashPalette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FlashPaletteScope>()?.palette ?? FlashPalette.fallback;

  @override
  bool updateShouldNotify(FlashPaletteScope old) =>
      old.palette.from != palette.from || old.palette.to != palette.to || old.palette.accent != palette.accent;
}

/// Section entry point for the Shop tab. Renders nothing when there is no deal.
class FlashSaleBand extends ConsumerWidget {
  const FlashSaleBand({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(flashSaleFeedProvider).valueOrNull;
    if (feed == null || feed.isEmpty) return const SizedBox.shrink();
    final sale = feed.featured;
    return FlashPaletteScope(
      palette: (sale ?? feed.upcoming!).palette,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        child: sale != null
            ? _LiveBand(sale: sale, moreSales: feed.sales.length - 1)
            : _UpcomingBand(sale: feed.upcoming!),
      ),
    );
  }
}

// ── the shell every state shares ─────────────────────────────────────────────

class FlashBackdrop extends StatelessWidget {
  final Widget child;
  final bool dim;
  final BorderRadius radius;
  const FlashBackdrop(
      {super.key, required this.child, this.dim = false, this.radius = const BorderRadius.all(Radius.circular(22))});

  @override
  Widget build(BuildContext context) {
    final p = dim ? FlashPaletteScope.of(context).dimmed : FlashPaletteScope.of(context);
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [p.from, p.mid, p.to],
            stops: const [0, 0.55, 1],
          ),
          boxShadow: [
            BoxShadow(color: p.from.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: CustomPaint(painter: _BoltStripesPainter(), child: child),
      ),
    );
  }
}

/// Faint diagonal zig-zag stripes — the "electric" texture behind the band.
class _BoltStripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeJoin = StrokeJoin.miter;
    for (double x = -size.height; x < size.width + size.height; x += 64) {
      final path = Path()..moveTo(x, 0);
      var y = 0.0, cx = x;
      var right = true;
      while (y < size.height) {
        y += 22;
        cx += right ? 18 : -6;
        path.lineTo(cx, y);
        right = !right;
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The ⚡ that breathes.
class PulsingBolt extends StatefulWidget {
  final double size;
  const PulsingBolt({super.key, this.size = 26});
  @override
  State<PulsingBolt> createState() => _PulsingBoltState();
}

class _PulsingBoltState extends State<PulsingBolt> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, __) {
          final t = Curves.easeInOut.transform(_c.value);
          final p = FlashPaletteScope.of(context);
          return Transform.scale(
            scale: 0.92 + t * 0.16,
            child: Container(
              width: widget.size + 10,
              height: widget.size + 10,
              decoration: BoxDecoration(
                color: p.accent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.35 + t * 0.4), blurRadius: 8 + t * 14)],
              ),
              child: Icon(Icons.bolt_rounded, size: widget.size, color: p.from),
            ),
          );
        },
      );
}

/// FLASH SALE, set heavy and leaning forward.
class FlashWordmark extends StatelessWidget {
  final double size;
  const FlashWordmark({super.key, this.size = 22});
  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(
            text: 'FLASH',
            style: TextStyle(
                color: FlashPaletteScope.of(context).ink,
                fontSize: size,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.5,
                height: 1),
          ),
          TextSpan(
            text: ' SALE',
            style: TextStyle(
                color: FlashPaletteScope.of(context).accent,
                fontSize: size,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.5,
                height: 1),
          ),
        ]),
        style: TextStyle(
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.25), offset: const Offset(1, 2), blurRadius: 0)]),
      );
}

// ── countdown ────────────────────────────────────────────────────────────────

/// Flip-style tiles that tick every second. When the clock runs out it calls
/// [onDone] once (the band re-fetches so an ended deal leaves on time).
class FlashCountdown extends StatefulWidget {
  final DateTime target;
  final VoidCallback? onDone;
  final double tile;
  const FlashCountdown({super.key, required this.target, this.onDone, this.tile = 26});
  @override
  State<FlashCountdown> createState() => _FlashCountdownState();
}

class _FlashCountdownState extends State<FlashCountdown> {
  late Timer _timer;
  DateTime _now = DateTime.now();
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      if (!_fired && !_now.isBefore(widget.target)) {
        _fired = true;
        widget.onDone?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = countdownParts(widget.target, _now);
    final colon = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(':',
          style: TextStyle(
              color: FlashPaletteScope.of(context).ink, fontWeight: FontWeight.w900, fontSize: widget.tile * 0.62)),
    );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (p.days > 0) ...[
        _FlipTile(text: '${p.days}d', size: widget.tile, wide: true),
        const SizedBox(width: 4),
      ],
      _FlipTile(text: p.hh, size: widget.tile),
      colon,
      _FlipTile(text: p.mm, size: widget.tile),
      colon,
      _FlipTile(text: p.ss, size: widget.tile),
    ]);
  }
}

class _FlipTile extends StatelessWidget {
  final String text;
  final double size;
  final bool wide;
  const _FlipTile({required this.text, required this.size, this.wide = false});

  @override
  Widget build(BuildContext context) => Container(
        height: size,
        constraints: BoxConstraints(minWidth: size * (wide ? 1.15 : 0.98)),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A0A04), kFlashInk],
            stops: [0.5, 0.5],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        alignment: Alignment.center,
        child: ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween(begin: const Offset(0, -0.6), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              text,
              key: ValueKey(text),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.56,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1,
              ),
            ),
          ),
        ),
      );
}

// ── live band ────────────────────────────────────────────────────────────────

class _LiveBand extends ConsumerWidget {
  final FlashSale sale;
  final int moreSales;
  const _LiveBand({required this.sale, required this.moreSales});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FlashBackdrop(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(children: [
              const PulsingBolt(size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const FlashWordmark(size: 21),
                  const SizedBox(height: 3),
                  Text(
                    sale.title.toUpperCase() == 'FLASH SALE' ? 'Ends in' : '${sale.title} · ends in',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: FlashPaletteScope.of(context).ink.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ]),
              ),
              FlashCountdown(target: sale.endsAt, tile: 25, onDone: () => ref.invalidate(flashSaleFeedProvider)),
            ]),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 186,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 12),
              itemCount: sale.items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => i == sale.items.length
                  ? _SeeAllCard(count: sale.items.length + 0, more: moreSales)
                  : FlashDealCard(
                      item: sale.items[i],
                      onTap: () => context.push('/product/${sale.items[i].productId}'),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SeeAllCard extends StatelessWidget {
  final int count;
  final int more;
  const _SeeAllCard({required this.count, required this.more});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.push('/flash-sale'),
        child: Container(
          width: 80,
          decoration: BoxDecoration(
            color: FlashPaletteScope.of(context).ink.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FlashPaletteScope.of(context).ink.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: FlashPaletteScope.of(context).accent, shape: BoxShape.circle),
              child: Icon(Icons.arrow_forward_rounded, color: FlashPaletteScope.of(context).from),
            ),
            const SizedBox(height: 8),
            Text('See all',
                style: TextStyle(color: FlashPaletteScope.of(context).ink, fontWeight: FontWeight.w900, fontSize: 13)),
            Text(more > 0 ? '+$more more sale${more == 1 ? '' : 's'}' : '$count deals',
                textAlign: TextAlign.center,
                style: TextStyle(color: FlashPaletteScope.of(context).ink.withValues(alpha: 0.85), fontSize: 10.5)),
          ]),
        ),
      );
}

// ── one deal ─────────────────────────────────────────────────────────────────

class FlashDealCard extends StatelessWidget {
  final FlashItem item;
  final VoidCallback onTap;
  final double width;
  const FlashDealCard({super.key, required this.item, required this.onTap, this.width = 108});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF1A1D23) : Colors.white;
    final ink = dark ? Colors.white : const Color(0xFF111827);
    final soldOut = item.soldOut;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        // The card always sits in a bounded box (the band's strip, a grid cell), so the
        // photo takes whatever height the text leaves — no dead space under the bar.
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              ColorFiltered(
                colorFilter: soldOut
                    ? const ColorFilter.matrix(
                        [0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0, 0, 0, 1, 0])
                    : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                child: item.image == null
                    ? Container(
                        color: FlashPaletteScope.of(context).tint, child: Icon(Icons.bolt, color: FlashPaletteScope.of(context).from, size: 30))
                    : Image.network(item.image!,
                        fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: FlashPaletteScope.of(context).tint)),
              ),
              if (item.discountPercent > 0)
                Positioned(left: -4, top: 8, child: DiscountTag(percent: item.discountPercent, scale: 0.8)),
              if (item.isOfficial)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.verified_rounded, size: 14, color: Color(0xFFD4AF37)),
                  ),
                ),
              if (soldOut)
                Center(
                  child: Transform.rotate(
                    angle: -math.pi / 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('SOLD OUT',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13)),
                    ),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 5, 7, 7),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: ink.withValues(alpha: 0.85))),
              const SizedBox(height: 2),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Flexible(
                  child: Text(flashPeso(item.flashPrice),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: FlashPaletteScope.of(context).price,
                          letterSpacing: -0.4)),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(flashPeso(item.regularPrice),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 9, decoration: TextDecoration.lineThrough, color: ink.withValues(alpha: 0.4))),
                ),
              ]),
              const SizedBox(height: 5),
              SoldBar(item: item, height: 13),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A skewed volt-yellow price tag.
class DiscountTag extends StatelessWidget {
  final int percent;
  final double scale;
  const DiscountTag({super.key, required this.percent, this.scale = 1});
  @override
  Widget build(BuildContext context) => Transform(
        transform: Matrix4.skewX(-0.18),
        child: Container(
          padding: EdgeInsets.fromLTRB(10 * scale, 3 * scale, 8 * scale, 3 * scale),
          decoration: BoxDecoration(
            color: FlashPaletteScope.of(context).accent,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(1, 2))
            ],
          ),
          child: Text('−$percent%',
              style: TextStyle(
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w900,
                  color: FlashPaletteScope.of(context).from,
                  fontStyle: FontStyle.italic,
                  height: 1.1)),
        ),
      );
}

/// The sold bar: a red-to-amber fill with a moving shine, and an honest label.
class SoldBar extends StatefulWidget {
  final FlashItem item;
  final double height;
  const SoldBar({super.key, required this.item, this.height = 15});
  @override
  State<SoldBar> createState() => _SoldBarState();
}

class _SoldBarState extends State<SoldBar> with SingleTickerProviderStateMixin {
  // Created in initState, never lazily: a sold-out bar never reads it, and a lazy
  // controller first created inside dispose() asserts (deactivated ancestor lookup).
  late final AnimationController _shine;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    if (!widget.item.soldOut) _shine.repeat();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final urgency = urgencyFor(soldPercent: it.soldPercent, stockLeft: it.stockLeft);
    final label = soldLabel(soldPercent: it.soldPercent, stockLeft: it.stockLeft, soldCount: it.soldCount);
    final fill = soldBarFill(it.soldPercent);
    final palette = FlashPaletteScope.of(context);
    final colors = switch (urgency) {
      FlashUrgency.soldOut => const [Color(0xFF9CA3AF), Color(0xFF6B7280)],
      FlashUrgency.almostGone => [Color.lerp(palette.from, Colors.black, 0.25)!, palette.from],
      _ => [palette.from, palette.to],
    };
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: palette.tint,
          borderRadius: BorderRadius.circular(widget.height),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fill),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Container(
              width: w * v,
              decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
            ),
          ),
          if (urgency != FlashUrgency.soldOut)
            AnimatedBuilder(
              animation: _shine,
              builder: (_, __) => Positioned(
                left: -40 + (w * fill + 40) * _shine.value,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 26,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.45),
                      Colors.white.withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
            ),
          Center(
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: widget.height * 0.62,
                fontWeight: FontWeight.w800,
                color: fill > 0.45 || urgency == FlashUrgency.soldOut ? Colors.white : palette.price,
                height: 1,
              ),
            ),
          ),
        ]),
      );
    });
  }
}

// ── nothing live, one coming ─────────────────────────────────────────────────

class _UpcomingBand extends ConsumerWidget {
  final FlashSale sale;
  const _UpcomingBand({required this.sale});
  @override
  Widget build(BuildContext context, WidgetRef ref) => FlashBackdrop(
        dim: true,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const PulsingBolt(size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const FlashWordmark(size: 18),
                const SizedBox(height: 3),
                Text('${sale.title} starts in',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: FlashPaletteScope.of(context).ink.withValues(alpha: 0.85),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            FlashCountdown(target: sale.startsAt, tile: 24, onDone: () => ref.invalidate(flashSaleFeedProvider)),
          ]),
        ),
      );
}

// ── product detail ───────────────────────────────────────────────────────────

/// The strip on a product page while the product is on a live flash sale:
/// the bolt, the countdown, how many are left, and the sold bar.
class FlashDealStrip extends StatelessWidget {
  final FlashSale sale;
  final FlashItem item;
  final VoidCallback? onEnded;
  const FlashDealStrip({super.key, required this.sale, required this.item, this.onEnded});

  @override
  Widget build(BuildContext context) => FlashPaletteScope(
        palette: sale.palette,
        child: Builder(builder: (context) => _strip(context, sale.palette.ink)),
      );

  Widget _strip(BuildContext context, Color ink) => FlashBackdrop(
        radius: const BorderRadius.all(Radius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const PulsingBolt(size: 16),
              const SizedBox(width: 8),
              const Expanded(child: FlashWordmark(size: 17)),
              Text('ENDS IN ',
                  style: TextStyle(
                      color: ink.withValues(alpha: 0.9), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              FlashCountdown(target: sale.endsAt, tile: 22, onDone: onEnded),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Text(flashPeso(item.flashPrice),
                  style: TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(width: 8),
              Text(flashPeso(item.regularPrice),
                  style: TextStyle(
                      color: ink.withValues(alpha: 0.7),
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: ink)),
              const SizedBox(width: 8),
              DiscountTag(percent: item.discountPercent, scale: 0.85),
              const Spacer(),
              Text(
                item.soldOut ? 'Sold out' : '${item.stockLeft} left',
                style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ]),
            const SizedBox(height: 8),
            SoldBar(item: item, height: 16),
            if (item.perCustomerLimit > 0 || item.seller.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                [
                  if (item.perCustomerLimit > 0) 'Limit ${item.perCustomerLimit} per customer',
                  if (!item.isOfficial && item.seller.isNotEmpty)
                    'Sold by ${item.seller}${item.sellerArea.isEmpty ? '' : ' · ${item.sellerArea}'}',
                  'Checked out on its own',
                ].join('  ·  '),
                style: TextStyle(color: ink.withValues(alpha: 0.9), fontSize: 10.5, fontWeight: FontWeight.w600),
              ),
            ],
          ]),
        ),
      );
}
