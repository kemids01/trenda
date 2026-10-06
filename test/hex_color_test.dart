import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/vendors/utils/hex_color.dart';

void main() {
  const fb = Color(0xFF1A237E);
  test('parses #RRGGBB and RRGGBB', () {
    expect(colorFromHex('#1A237E', fallback: fb), const Color(0xFF1A237E));
    expect(colorFromHex('00897B', fallback: fb), const Color(0xFF00897B));
  });
  test('null/empty/invalid -> fallback', () {
    expect(colorFromHex(null, fallback: fb), fb);
    expect(colorFromHex('', fallback: fb), fb);
    expect(colorFromHex('red', fallback: fb), fb);
    expect(colorFromHex('#12345', fallback: fb), fb);
  });
}
