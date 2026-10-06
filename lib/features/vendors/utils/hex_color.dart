import 'package:flutter/material.dart';

/// Parses a `#RRGGBB` (or `RRGGBB`) hex string to a [Color].
/// Returns [fallback] for null/empty/invalid input.
Color colorFromHex(String? hex, {required Color fallback}) {
  if (hex == null) return fallback;
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(h)) return fallback;
  return Color(int.parse(h, radix: 16) + 0xFF000000);
}
