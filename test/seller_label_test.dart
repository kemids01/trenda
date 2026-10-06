// test/seller_label_test.dart
// Who the product page says is selling, and what it promises about delivery.

import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/products/utils/seller_label.dart';

void main() {
  group('sellerRoleLabel', () {
    test('an ordinary vendor is NOT called an Official Store', () {
      // The page used to print "Official Store" under every non-resold seller,
      // colliding with the real first-party Official Trenda Store.
      final label = sellerRoleLabel();
      expect(label, 'Local vendor');
      expect(label.toLowerCase(), isNot(contains('official')));
    });

    test('only a genuine official product carries the Official name', () {
      expect(sellerRoleLabel(isOfficial: true), 'Official Trenda Store');
    });

    test('a resold listing names the reseller', () {
      expect(sellerRoleLabel(isResale: true), 'Reseller');
    });

    test('official wins over resale if both are somehow set', () {
      expect(
        sellerRoleLabel(isOfficial: true, isResale: true),
        'Official Trenda Store',
      );
    });
  });

  group('deliveryPromises', () {
    test('never quotes a shipping window', () {
      // "Estimated delivery: 3-5 days" was hardcoded on every product, on a
      // same-municipality platform where nothing produces that number.
      final joined = deliveryPromises().map((p) => p.text).join(' ').toLowerCase();
      expect(joined, isNot(contains('day')));
      expect(joined, isNot(contains('3-5')));
    });

    test('says the fee is settled at checkout, and names the city', () {
      final lines = deliveryPromises(municipality: 'Tuguegarao City');
      expect(lines.first.text, contains('calculated at checkout'));
      expect(lines.first.text, contains('Tuguegarao City'));
      // A "depends on" note is not a guarantee.
      expect(lines.first.assured, isFalse);
    });

    test('omits the city cleanly when none is selected', () {
      for (final muni in [null, '', '   ']) {
        final first = deliveryPromises(municipality: muni).first.text;
        expect(first, contains('calculated at checkout'));
        expect(first, isNot(contains('  ')));
        expect(first.trim(), endsWith('address'));
      }
    });

    test('free delivery is stated as a guarantee', () {
      final first = deliveryPromises(freeShipping: true).first;
      expect(first.text, 'Free delivery on this item');
      expect(first.assured, isTrue);
    });

    test('always tells the buyer COD is how they pay', () {
      // Online payment is scaffolding only; COD is the working method.
      final joined = deliveryPromises().map((p) => p.text).join(' ');
      expect(joined, contains('Cash on delivery'));
    });

    test('mentions a Trenda rider, not an anonymous courier', () {
      final joined = deliveryPromises().map((p) => p.text).join(' ');
      expect(joined, contains('Trenda rider'));
    });
  });
}
