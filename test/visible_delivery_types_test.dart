import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/utils/visible_delivery_types.dart';

void main() {
  group('visibleDeliveryTypes', () {
    const all = ['standard', 'express', 'pasabay', 'heavy_express', 'bulk'];
    test('returns all when everything enabled', () {
      expect(visibleDeliveryTypes(all, all), all);
    });
    test('filters out disabled types, preserving order', () {
      expect(visibleDeliveryTypes(all, const ['bulk', 'express']), ['express', 'bulk']);
    });
    test('empty enabled list falls back to all (never zero options)', () {
      expect(visibleDeliveryTypes(all, const []), all);
    });
  });
}
