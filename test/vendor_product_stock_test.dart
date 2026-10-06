import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/vendors/providers/vendor_follow_provider.dart';

void main() {
  group('VendorProduct stock (store page SOLD OUT badge)', () {
    test('reads totalStock — the field /api/stores/:id/products sends', () {
      final p = VendorProduct.fromJson(
          {'_id': 'a', 'name': 'Rice', 'basePrice': 50, 'totalStock': 60});
      expect(p.stock, 60);
      expect(p.inStock, isTrue);
    });

    test('sums variants when the product has them', () {
      final p = VendorProduct.fromJson({
        '_id': 'b',
        'name': 'Shirt',
        'basePrice': 200,
        'totalStock': 0,
        'hasVariants': true,
        'variants': [
          {'stock': 3},
          {'stock': 4},
        ],
      });
      expect(p.stock, 7);
      expect(p.inStock, isTrue);
    });

    test('a genuine zero is still sold out', () {
      final p = VendorProduct.fromJson(
          {'_id': 'c', 'name': 'Rib Eye', 'basePrice': 400, 'totalStock': 0});
      expect(p.stock, 0);
      expect(p.inStock, isFalse);
    });

    test('legacy stock/quantity fields still work', () {
      expect(
          VendorProduct.fromJson({'_id': 'd', 'name': 'x', 'stock': 5}).stock,
          5);
      expect(
          VendorProduct.fromJson({'_id': 'e', 'name': 'y', 'quantity': 2})
              .stock,
          2);
    });
  });
}
