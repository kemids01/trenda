import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_shared/trenda_shared.dart';
import 'package:trenda_frontend/features/products/utils/product_specs.dart';

void main() {
  group('specRows', () {
    final vehicles = resolveTemplate('Vehicles'); // specFields: model, year, features

    test('returns populated spec fields in template order with labels', () {
      final rows = specRows(vehicles, {
        'model': 'XYZ-500', 'year': '2026', 'features': '60km range',
      });
      expect(rows.map((r) => r.key).toList(),
          ['Model / Variant', 'Year', 'Key Features']);
      expect(rows.map((r) => r.value).toList(),
          ['XYZ-500', '2026', '60km range']);
    });

    test('skips missing and blank values', () {
      final rows = specRows(vehicles, {'model': '  ', 'year': '2026'});
      expect(rows.length, 1);
      expect(rows.first.key, 'Year');
      expect(rows.first.value, '2026');
    });

    test('empty attributes -> no rows', () {
      expect(specRows(vehicles, {}), isEmpty);
    });

    test('template without spec fields -> no rows', () {
      final electronics = resolveTemplate('Electronics'); // no specFields
      expect(specRows(electronics, {'anything': 'x'}), isEmpty);
    });
  });
}
