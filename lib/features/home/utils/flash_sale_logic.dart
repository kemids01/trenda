// lib/features/home/utils/flash_sale_logic.dart
// Pure display rules for the ⚡ Flash Sale band, its See-all page and the
// product-detail strip. No widgets, no IO — test/flash_sale_test.dart.
import 'dart:ui' show Color;

/// The digits on the flip tiles. Past a day the first tile is DAYS, so a
/// week-long sale reads "6d 23:59:59"-style instead of an absurd "167:59:59".
typedef CountdownParts = ({int days, String hh, String mm, String ss, bool done});

CountdownParts countdownParts(DateTime target, DateTime now) {
  var d = target.difference(now);
  final done = d.inSeconds <= 0;
  if (done) d = Duration.zero;
  String two(int n) => n.toString().padLeft(2, '0');
  return (
    days: d.inDays,
    hh: two(d.inHours.remainder(24)),
    mm: two(d.inMinutes.remainder(60)),
    ss: two(d.inSeconds.remainder(60)),
    done: done,
  );
}

/// How urgent a deal reads — drives the sold bar colour and the pulse.
enum FlashUrgency { calm, hot, almostGone, soldOut }

FlashUrgency urgencyFor({required int soldPercent, required int stockLeft}) {
  if (stockLeft <= 0) return FlashUrgency.soldOut;
  if (soldPercent >= 80 || stockLeft <= 3) return FlashUrgency.almostGone;
  if (soldPercent >= 40) return FlashUrgency.hot;
  return FlashUrgency.calm;
}

/// The line under the sold bar. Honest: it only ever states what the server
/// counted — never an invented "selling fast" on a deal nobody has bought.
String soldLabel({required int soldPercent, required int stockLeft, required int soldCount}) {
  switch (urgencyFor(soldPercent: soldPercent, stockLeft: stockLeft)) {
    case FlashUrgency.soldOut:
      return 'Sold out';
    case FlashUrgency.almostGone:
      return stockLeft <= 3 ? 'Only $stockLeft left!' : 'Almost gone!';
    case FlashUrgency.hot:
      return '🔥 $soldPercent% sold';
    case FlashUrgency.calm:
      return soldCount > 0 ? '$soldCount sold' : 'Just started';
  }
}

/// ₱1,290 / ₱47.50 — centavos only when there are any.
String flashPeso(double v) {
  final whole = v == v.truncateToDouble();
  final s = whole ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  final parts = s.split('.');
  final digits = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '₱$buf${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// The fill the sold bar shows. A deal nobody has bought yet still shows a
/// sliver, so the bar reads as a bar rather than an empty frame.
double soldBarFill(int soldPercent) => soldPercent <= 0 ? 0.04 : (soldPercent.clamp(0, 100) / 100.0);

// ── band colours (admin ▸ Flash Sales ▸ campaign form) ──────────────────────

/// The colours a campaign paints its band with. Mirrors trenda_backend DEFAULT_THEME.
class FlashPalette {
  final Color from;
  final Color to;
  final Color accent;
  const FlashPalette({required this.from, required this.to, required this.accent});

  static const fallback =
      FlashPalette(from: Color(0xFFE5170B), to: Color(0xFFFFA000), accent: Color(0xFFFFE600));

  /// A pale wash of the band (sold-bar track, photo placeholder).
  Color get tint => Color.lerp(to, const Color(0xFFFFFFFF), 0.8)!;

  /// The middle stop of the band's 3-stop gradient.
  Color get mid => Color.lerp(from, to, 0.45)!;

  /// The quieter "starts in" version: the same hues, sunk toward black.
  FlashPalette get dimmed => FlashPalette(
        from: Color.lerp(from, const Color(0xFF000000), 0.72)!,
        to: Color.lerp(to, const Color(0xFF000000), 0.6)!,
        accent: accent,
      );

  /// Text on the gradient: white, unless the admin picked a light band.
  Color get ink => Color.lerp(from, to, 0.5)!.computeLuminance() > 0.55
      ? const Color(0xFF1A0500)
      : const Color(0xFFFFFFFF);

  /// The flash price on a white card: the band's start colour, unless it is too pale to read.
  Color get price => from.computeLuminance() > 0.45 ? const Color(0xFFE5170B) : from;

  /// `{from,to,accent}` hex map → palette; a missing or malformed key keeps the default.
  factory FlashPalette.fromJson(dynamic json) {
    final m = json is Map ? json : const {};
    Color pick(String k, Color d) => hexColor(m[k]?.toString()) ?? d;
    return FlashPalette(
      from: pick('from', fallback.from),
      to: pick('to', fallback.to),
      accent: pick('accent', fallback.accent),
    );
  }
}

/// '#RRGGBB' → Color, null when malformed.
Color? hexColor(String? v) {
  final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch((v ?? '').trim());
  return m == null ? null : Color(int.parse('FF${m.group(1)}', radix: 16));
}
