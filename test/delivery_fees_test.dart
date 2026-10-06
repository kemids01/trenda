import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/data/checkout_repository.dart';

const _fees = DeliveryFees(
  express: 80, pasabay: 20, heavyExpress: 100,
  base: 50, baseDistance: 1, perKm: 10,
);

void main() {
  group('enabledDeliveryTypes', () {
    test('defaults to all when absent', () {
      expect(DeliveryFees.defaults().enabledDeliveryTypes, contains('pasabay'));
      // express + pasabay + heavy_express. `standard` and `bulk` were both retired as
      // customer-selectable types (2026-08-20 / 2026-08-21).
      expect(DeliveryFees.fromJson({}).enabledDeliveryTypes.length, 3);
    });
    test('parses the provided list', () {
      final f = DeliveryFees.fromJson({'enabledDeliveryTypes': ['express', 'heavy_express']});
      expect(f.enabledDeliveryTypes, ['express', 'heavy_express']);
    });
  });

  group('getFeeForType', () {
    test('maps each type', () {
      expect(_fees.getFeeForType('standard'), 50);
      expect(_fees.getFeeForType('express'), 80);
      expect(_fees.getFeeForType('pasabay'), 20);
      expect(_fees.getFeeForType('heavy_express'), 100);
      expect(_fees.getFeeForType('heavy_express'), 100);
      expect(_fees.getFeeForType('mystery'), 50);
    });
  });

  group('calculateDistanceBasedFee', () {
    test('flat types are distance-independent', () {
      expect(_fees.calculateDistanceBasedFee(0.5, 'pasabay'), 20);
      expect(_fees.calculateDistanceBasedFee(99, 'pasabay'), 20);
      expect(_fees.calculateDistanceBasedFee(0.5, 'pasabay'), 20);
      expect(_fees.calculateDistanceBasedFee(99, 'pasabay'), 20);
    });
    test('distance types add extra-km * perKm + surcharge', () {
      expect(_fees.calculateDistanceBasedFee(1, 'standard'), 50);
      expect(_fees.calculateDistanceBasedFee(3, 'standard'), 70);
      expect(_fees.calculateDistanceBasedFee(3, 'express'), 100);
      expect(_fees.calculateDistanceBasedFee(3, 'heavy_express'), 120);
      expect(_fees.calculateDistanceBasedFee(3, 'mystery'), 70);
    });
  });
}
