import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/utils/delivery_gating.dart';

void main() {
  _pasabayCapTests();
  group('deliverySelectionReason', () {
    test('no force at or below the threshold', () {
      expect(deliverySelectionReason(totalWeight: 5), isNull);
      expect(deliverySelectionReason(totalWeight: 20), isNull); // not > 20
    });

    test('forces heavy_express above the default threshold', () {
      final f = deliverySelectionReason(totalWeight: 25);
      expect(f, isNotNull);
      expect(f!.type, 'heavy_express');
      expect(f.reason, contains('Heavy Express'));
    });

    test('honors a custom (admin-set) threshold', () {
      expect(deliverySelectionReason(totalWeight: 30, heavyThreshold: 50), isNull);
      final f = deliverySelectionReason(totalWeight: 60, heavyThreshold: 50);
      expect(f, isNotNull);
      expect(f!.type, 'heavy_express');
      expect(f.reason, contains('50 kg'));
    });

    test('never returns bulk, even for very heavy carts', () {
      final f = deliverySelectionReason(totalWeight: 100);
      expect(f, isNotNull);
      expect(f!.type, 'heavy_express');
    });
  });

  group('availableDeliveryTypes', () {
    test('locked type returns only that type', () {
      expect(
        availableDeliveryTypes(const ['express', 'pasabay', 'heavy_express'],
            gpsOnly: false, lockedType: 'heavy_express'),
        ['heavy_express'],
      );
    });

    test('gps-only drops pasabay when not locked', () {
      expect(
        availableDeliveryTypes(const ['express', 'pasabay', 'heavy_express'],
            gpsOnly: true, lockedType: null),
        ['express', 'heavy_express'],
      );
    });
  });
}

// ── Pasabay weight cap: the server rejects pasabay at/above pasabayMaxWeightKg, so checkout must
//    stop OFFERING it there (otherwise the customer only finds out at submit).
void _pasabayCapTests() {
  group('availableDeliveryTypes — pasabay weight cap', () {
    const all = ['express', 'pasabay', 'heavy_express'];

    test('pasabay offered below the cap', () {
      expect(
        availableDeliveryTypes(all,
            gpsOnly: false, totalWeight: 10, pasabayMaxWeightKg: 50),
        all,
      );
    });

    test('pasabay dropped at the cap and above', () {
      expect(
        availableDeliveryTypes(all,
            gpsOnly: false, totalWeight: 50, pasabayMaxWeightKg: 50),
        ['express', 'heavy_express'],
      );
      expect(
        availableDeliveryTypes(all,
            gpsOnly: false, totalWeight: 80, pasabayMaxWeightKg: 50),
        ['express', 'heavy_express'],
      );
    });

    test('honours an admin-lowered cap', () {
      expect(
        availableDeliveryTypes(all,
            gpsOnly: false, totalWeight: 30, pasabayMaxWeightKg: 25),
        ['express', 'heavy_express'],
      );
    });

    test('a locked type still wins over the cap', () {
      expect(
        availableDeliveryTypes(all,
            gpsOnly: false,
            lockedType: 'heavy_express',
            totalWeight: 80,
            pasabayMaxWeightKg: 50),
        ['heavy_express'],
      );
    });

    test('defaults keep the old behaviour when the caller passes no weight', () {
      expect(availableDeliveryTypes(all, gpsOnly: false), all);
    });
  });
}
