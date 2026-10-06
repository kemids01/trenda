import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/products/utils/price_display.dart';

void main() {
  group('pricingUnitSuffix', () {
    test('fresh units get a compact per-unit suffix', () {
      expect(pricingUnitSuffix('kg'), ' / kg');
      expect(pricingUnitSuffix('bundle'), ' / bundle');
      expect(pricingUnitSuffix('piece'), ' / piece');
    });

    test('service units get a suffix', () {
      expect(pricingUnitSuffix('per_service'), ' / service');
      expect(pricingUnitSuffix('hourly'), ' / hr');
    });

    test('each / quote / unknown get no suffix', () {
      expect(pricingUnitSuffix('each'), '');
      expect(pricingUnitSuffix('quote'), '');
      expect(pricingUnitSuffix('nonsense'), '');
      expect(pricingUnitSuffix(''), '');
    });
  });
}
