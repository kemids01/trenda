import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/utils/delivery_gating.dart';

void main() {
  group('deliverySelectionReason', () {
    // `bulk` was removed as a customer-selectable delivery type on 2026-08-21 (spec 3a) —
    // heavy_express already absorbs weight-triggered orders, and the very-heavy tier is an
    // ops-only queue. Weight above the threshold forces heavy_express at every weight.
    test('well above the threshold -> still heavy_express, not a separate bulk type', () {
      final r = deliverySelectionReason(totalWeight: 60);
      expect(r!.type, 'heavy_express');
      expect(r.reason, contains('60'));
    });
    test('>20kg -> heavy_express', () {
      expect(deliverySelectionReason(totalWeight: 24)!.type, 'heavy_express');
    });
    test('<=20kg -> null', () {
      expect(deliverySelectionReason(totalWeight: 20), isNull);
    });
  });

  group('availableDeliveryTypes', () {
    const all = ['standard', 'express', 'pasabay', 'heavy_express'];
    test('lockedType -> only that type', () {
      expect(availableDeliveryTypes(all, gpsOnly: false, lockedType: 'heavy_express'), ['heavy_express']);
    });
    test('gpsOnly drops pasabay', () {
      expect(availableDeliveryTypes(all, gpsOnly: true, lockedType: null),
          ['standard', 'express', 'heavy_express']);
    });
    test('normal passthrough', () {
      expect(availableDeliveryTypes(all, gpsOnly: false, lockedType: null), all);
    });
  });
}
