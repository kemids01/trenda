// lib/features/home/presentation/widgets/profile_parts.dart
// Visual building blocks for the Profile tab. They hold no state and fetch
// nothing — ProfileTab owns every provider read and passes values in, so these
// stay dumb and the page's behaviour lives in one place.
//
// The layout follows the vendor dashboard's idiom — panels with an icon-tile
// header, tinted metric tiles and a four-column tool grid — at a tighter
// density, since a customer profile is a place to pass through, not work in.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The brand colours, the same set the app-bar brand mark uses, so the hero
/// reads as part of the Trenda identity rather than a new theme.
const Color kProfileInk = Color(0xFF0B1B4D);
const Color kProfileBlue = Color(0xFF2563EB);
const Color kProfileSky = Color(0xFF3B82F6);
const Color kProfileGold = Color(0xFFD4AF37);

/// Lane accents shared with the Shop tab's quick lanes.
const Color kLaneRed = Color(0xFFDC2626);
const Color kLaneTeal = Color(0xFF0F766E);
const Color kLaneBlue = Color(0xFF1E4FA3);
const Color kLaneGold = Color(0xFFB4831F);
const Color kLanePlum = Color(0xFF6B3A6E);

/// An accent lifted toward white in dark mode so it keeps its contrast.
Color _tint(BuildContext context, Color accent) =>
    Theme.of(context).brightness == Brightness.dark
        ? Color.lerp(accent, Colors.white, 0.35)!
        : accent;

/// The dark brand panel at the top of the page. Full-bleed, it runs under the
/// status bar and carries faint contour lines — a map motif, since every order
/// on Trenda belongs to a town.
class ProfileHero extends StatelessWidget {
  final Widget child;

  /// Extra space at the bottom for a card that overlaps the hero's edge.
  final double overlap;

  const ProfileHero({super.key, required this.child, this.overlap = 0});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kProfileInk, Color(0xFF14307F), kProfileBlue],
            stops: [0, 0.6, 1],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomPaint(
          painter: _ContourPainter(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 12,
              16,
              16 + overlap,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ContourPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.06);
    // Rings centred off the top-right corner, each slightly wobbled so they
    // read as terrain contours instead of a target.
    final centre = Offset(size.width * 0.92, size.height * 0.05);
    for (var i = 1; i <= 9; i++) {
      final r = 30.0 * i;
      final path = Path();
      for (var a = 0; a <= 72; a++) {
        final t = a / 72 * 2 * math.pi;
        final wobble = 1 + 0.06 * math.sin(t * 3 + i * 0.9);
        final p = centre +
            Offset(math.cos(t) * r * 1.25 * wobble, math.sin(t) * r * wobble);
        a == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path..close(), line);
    }
    // A single gold glint along the bottom-left, echoing the brand mark.
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        kProfileGold.withValues(alpha: 0.18),
        kProfileGold.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(
          center: Offset(0, size.height), radius: size.width * 0.55));
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Avatar wrapped in a ring that fills with profile completion. At 100% the
/// ring turns a quiet solid gold; below it, the unfilled part stays visible so
/// the gap reads at a glance.
class ProfileAvatarRing extends StatelessWidget {
  final String? photoUrl;
  final String monogram;
  final int percent;
  final bool loading;
  final VoidCallback onTap;
  final double size;

  const ProfileAvatarRing({
    super.key,
    required this.photoUrl,
    required this.monogram,
    required this.percent,
    required this.onTap,
    this.loading = false,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    final inner = size - 10;
    return Semantics(
      button: true,
      label: 'Change profile photo',
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: percent / 100),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) =>
                      CustomPaint(painter: _RingPainter(progress: v)),
                ),
              ),
              Center(
                child: Container(
                  width: inner,
                  height: inner,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: Text(
                          monogram,
                          style: TextStyle(
                            fontSize: inner * 0.36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (photoUrl != null)
                        Image.network(
                          photoUrl!,
                          fit: BoxFit.cover,
                          // A broken URL falls back to the monogram beneath.
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      if (loading)
                        const ColoredBox(
                          color: Color(0x88000000),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -1,
                child: Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    color: kProfileGold,
                    shape: BoxShape.circle,
                    border: Border.all(color: kProfileInk, width: 2),
                  ),
                  child: const Icon(Icons.photo_camera_rounded,
                      size: 10, color: kProfileInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.8;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.16),
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          colors: [Color(0xFFF3D77A), kProfileGold, Color(0xFFF3D77A)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

/// A translucent pill used on the hero (city, completion nudge).
class HeroPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? accent;
  final VoidCallback? onTap;

  const HeroPill({
    super.key,
    required this.icon,
    required this.text,
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colour = accent ?? Colors.white;
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: colour),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: colour,
                    letterSpacing: 0.1,
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

/// The page's one card style: surface, rounded, hairline border, a soft
/// shadow only in light mode (shadows vanish on a dark canvas anyway).
class ProfileCard extends StatelessWidget {
  final Widget child;
  final bool raised;

  const ProfileCard({super.key, required this.child, this.raised = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: kProfileInk.withValues(alpha: raised ? 0.12 : 0.04),
                  blurRadius: raised ? 20 : 10,
                  offset: Offset(0, raised ? 8 : 3),
                ),
              ],
      ),
      // Plain white, no outline: the soft shadow alone lifts it off the grey
      // canvas. Material 3's `surface` carries a tint, so white is explicit.
      child: Material(
        color: dark ? const Color(0xFF171B22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// A card with the vendor dashboard's header: a gradient icon tile, a title
/// with an optional subtitle, and an optional trailing action.
class ProfilePanel extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool raised;
  final Widget child;

  const ProfilePanel({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.child,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.raised = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ProfileCard(
      raised: raised,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: Colors.white),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.2,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (actionLabel != null)
                  InkWell(
                    onTap: onAction,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 0, 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(actionLabel!,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary)),
                          Icon(Icons.chevron_right_rounded,
                              size: 16, color: scheme.primary),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// One order stage: a tinted tile with the icon and count side by side and
/// the label beneath — the vendor dashboard's compact metric, sized for three
/// across a narrow phone.
class OrderStageCell extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String label;
  final int? count;
  final VoidCallback? onTap;

  const OrderStageCell({
    super.key,
    required this.icon,
    required this.accent,
    required this.label,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = (count ?? 0) > 0;
    final tint = _tint(context, accent);
    return Expanded(
      child: Material(
        color: dark
            ? Colors.white.withValues(alpha: 0.04)
            : accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 8, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: active ? 0.16 : 0.08),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(icon,
                          size: 14,
                          color: tint.withValues(alpha: active ? 1 : 0.6)),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      count == null ? '–' : '$count',
                      style: TextStyle(
                        fontSize: 17,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: scheme.onSurface
                            .withValues(alpha: active ? 1 : 0.45),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                        color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One entry in a [ProfileToolGrid]: a bordered, tinted icon tile with an
/// optional count badge and a one-line label.
class ProfileTool {
  final IconData icon;
  final Color accent;
  final String label;
  final int badge;
  final VoidCallback onTap;

  const ProfileTool({
    required this.icon,
    required this.accent,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });
}

/// Tools laid out four to a row, as on the vendor dashboard. A short last row
/// keeps its columns aligned with the rows above.
class ProfileToolGrid extends StatelessWidget {
  final List<ProfileTool> tools;
  static const int columns = 4;

  const ProfileToolGrid({super.key, required this.tools});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tools.length; i += columns) {
      final slice = tools.skip(i).take(columns).toList();
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < columns; c++)
            Expanded(
              child: c < slice.length
                  ? _ToolTile(tool: slice[c])
                  : const SizedBox.shrink(),
            ),
        ],
      ));
    }
    return Column(children: rows);
  }
}

class _ToolTile extends StatelessWidget {
  final ProfileTool tool;
  const _ToolTile({required this.tool});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = tool.accent;
    return InkWell(
      onTap: tool.onTap,
      borderRadius: BorderRadius.circular(10),
      splashColor: accent.withValues(alpha: 0.1),
      highlightColor: accent.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: dark ? 0.26 : 0.13),
                        accent.withValues(alpha: dark ? 0.14 : 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child:
                      Icon(tool.icon, size: 19, color: _tint(context, accent)),
                ),
                if (tool.badge > 0)
                  Positioned(
                    top: -5,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: kLaneRed,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                dark ? const Color(0xFF171B22) : Colors.white,
                            width: 1.5),
                      ),
                      child: Text(
                        tool.badge > 99 ? '99+' : '${tool.badge}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              tool.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A settings card: a header (coloured icon tile, title, optional subtitle)
/// and its rows, all on one white card. No outlines or divider lines — rows
/// are separated by spacing and their own coloured icons.
class ProfileGroup extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final List<Widget> rows;

  const ProfileGroup({
    super.key,
    required this.title,
    required this.rows,
    this.subtitle,
    this.icon = Icons.tune_rounded,
    this.accent = kProfileBlue,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ProfileCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 15, color: Colors.white),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.2,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ...rows,
            ],
          ),
        ),
      ),
    );
  }
}

/// One settings row: a solid colour icon tile · title (+ optional subtitle) ·
/// value · chevron. A value still to be filled in shows as an "Add" pill; a
/// [locked] row shows a lock and does nothing on tap.
class ProfileRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final bool valueIsPrompt;
  final int badge;
  final Widget? trailing;
  final bool locked;
  final Color? accent;
  final VoidCallback? onTap;

  const ProfileRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.valueIsPrompt = false,
    this.badge = 0,
    this.trailing,
    this.locked = false,
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.3);
    final colour = accent ?? const Color(0xFF64748B);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 5, trailing != null ? 2 : 8, 5),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colour, Color.lerp(colour, Colors.white, 0.25)!],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: colour.withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Row(
                  children: [
                    // Label takes what it needs; the value gets the rest and
                    // truncates, so neither can push the row past its edge.
                    Flexible(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.25,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: value == null
                            ? const SizedBox.shrink()
                            : valueIsPrompt
                                ? _AddPill(text: value!)
                                : Text(
                                    value!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                      ),
                    ),
                  ],
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: kLaneRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              if (trailing != null)
                // Switches default to a 48px tap target; scaled down they
                // keep rows at the compact height.
                Transform.scale(scale: 0.82, child: trailing!)
              else if (locked) ...[
                const SizedBox(width: 6),
                Icon(Icons.lock_outline_rounded, size: 14, color: muted),
              ] else if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 18, color: muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Add" call to action on a row whose value is still missing.
class _AddPill extends StatelessWidget {
  final String text;
  const _AddPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, size: 13, color: primary),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades and lifts its child in once, [index] steps after the page appears —
/// one staggered entrance instead of scattered effects.
class ProfileReveal extends StatelessWidget {
  final int index;
  final Widget child;

  const ProfileReveal({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final start = math.min(index * 0.09, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: c),
      ),
    );
  }
}
