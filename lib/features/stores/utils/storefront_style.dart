// lib/features/stores/utils/storefront_style.dart
// Pure helpers behind the "Main Street" storefront cards: each shop gets its own
// awning colour (stable per store), a readable signboard monogram, and a human
// reopening line. Kept widget-free so it can be unit-tested.

import 'package:flutter/material.dart';

/// The canvas colours a shop awning is striped with.
@immutable
class AwningPalette {
  /// The saturated stripe — the shop's "house colour".
  final Color stripe;

  /// The pale stripe woven between the coloured ones.
  final Color canvas;

  /// Darker edge used for the scalloped valance trim.
  final Color trim;

  const AwningPalette({
    required this.stripe,
    required this.canvas,
    required this.trim,
  });
}

/// Deep, sun-bleached canvas colours you actually see on market awnings.
const List<Color> kAwningStripes = <Color>[
  Color(0xFFC2402F), // tomato
  Color(0xFF0F766E), // deep teal
  Color(0xFFB4831F), // mustard
  Color(0xFF2F6B3C), // grocer green
  Color(0xFF1E4FA3), // cobalt
  Color(0xFFA85A2E), // terracotta
  Color(0xFF6B3A6E), // plum
  Color(0xFF2A6F97), // harbour blue
];

/// Stable index into [kAwningStripes] for a given seed (store id or name).
///
/// Deterministic on purpose: a shop keeps the same awning between refreshes,
/// so regulars recognise the storefront before they read the sign.
int awningIndexFor(String seed) {
  if (seed.isEmpty) return 0;
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash % kAwningStripes.length;
}

/// The awning palette for a store, adapted to the current [brightness].
AwningPalette awningPaletteFor(String seed, {Brightness brightness = Brightness.light}) {
  final stripe = kAwningStripes[awningIndexFor(seed)];
  final dark = brightness == Brightness.dark;
  return AwningPalette(
    stripe: dark ? Color.lerp(stripe, Colors.black, 0.18)! : stripe,
    canvas: dark ? const Color(0xFFE0D7C7) : const Color(0xFFF8F1E4),
    trim: Color.lerp(stripe, Colors.black, 0.28)!,
  );
}

/// A closed shop's awning is drawn in weathered greys, not its house colour.
AwningPalette shutteredPalette({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  return AwningPalette(
    stripe: dark ? const Color(0xFF4B5563) : const Color(0xFF9AA1AB),
    canvas: dark ? const Color(0xFF6B7280) : const Color(0xFFD7DBE0),
    trim: dark ? const Color(0xFF374151) : const Color(0xFF7C848F),
  );
}

/// Up to two letters for the hanging signboard when a shop has no logo.
String storeMonogram(String name) {
  final words = name
      .trim()
      .split(RegExp(r'[\s\-_]+'))
      .where((w) => w.isNotEmpty && RegExp(r'[A-Za-z0-9]').hasMatch(w))
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final w = words.first;
    return (w.length == 1 ? w : w.substring(0, 2)).toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}

/// '08:00' -> '8:00 AM'. Returns the input untouched if it isn't HH:mm.
String formatClockTime(String raw) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
  if (m == null) return raw.trim();
  final h24 = int.tryParse(m.group(1)!);
  if (h24 == null || h24 > 23) return raw.trim();
  final suffix = h24 >= 12 ? 'PM' : 'AM';
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  return '$h12:${m.group(2)} $suffix';
}

const List<String> _kShortDays = <String>[
  'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat',
];

/// 'saturday' -> 'Sat'. Unknown values are title-cased and truncated.
String shortDay(String day) {
  final d = day.trim().toLowerCase();
  for (final s in _kShortDays) {
    if (d.startsWith(s.toLowerCase())) return s;
  }
  if (d.isEmpty) return '';
  final take = d.length < 3 ? d.length : 3;
  return d[0].toUpperCase() + d.substring(1, take);
}

/// The line a shuttered storefront shows: 'Opens Sat · 8:00 AM'.
///
/// Returns null when the backend could not work out a reopening slot (a shop
/// closed indefinitely), so the caller can fall back to a plain 'Closed'.
String? formatReopening({String? day, String? time}) {
  final d = (day ?? '').trim();
  final t = (time ?? '').trim();
  if (d.isEmpty && t.isEmpty) return null;
  if (t.isEmpty) return 'Opens ${shortDay(d)}';
  if (d.isEmpty) return 'Opens ${formatClockTime(t)}';
  return 'Opens ${shortDay(d)} · ${formatClockTime(t)}';
}

/// 'Sari-sari Store · Tuguegarao City' — drops the blanks instead of leaving
/// dangling separators.
String joinMeta(List<String?> parts) => parts
    .map((p) => p?.trim() ?? '')
    .where((p) => p.isNotEmpty)
    .join(' · ');
