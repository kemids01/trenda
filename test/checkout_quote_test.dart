import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/models/checkout_quote.dart';
import 'package:trenda_frontend/features/checkout/presentation/order_confirmation_page.dart';

// One delivery fee per store (POST /api/checkout/quote): a cart from two stores is two orders, two
// riders, two fees — and the delivery total shown is their sum.
void main() {
  Map<String, dynamic> body({double? feeB = 120}) => {
        'checkoutGroupSize': 2,
        'deliveryTotal': feeB == null ? null : 80 + feeB,
        'groups': [
          {'key': 'vendor:a', 'kind': 'store', 'label': 'Jollibee', 'itemCount': 2, 'subtotal': 300, 'deliveryType': 'express', 'fee': 80},
          {'key': 'official:w1', 'kind': 'official', 'label': 'Official Trenda · Centro', 'itemCount': 1, 'subtotal': 114, 'deliveryType': 'express', 'fee': feeB},
        ],
      };

  test('per-store fees add up to the delivery total', () {
    final q = CheckoutQuote.fromJson(body());
    expect(q.isSplit, isTrue);
    expect(q.showsPerStoreFees, isTrue);
    expect(q.groups.map((g) => g.fee), [80, 120]);
    expect(q.deliveryTotal, q.groups.fold<double>(0, (s, g) => s + g.fee!));
    expect(q.groups.last.isOfficial, isTrue);
    expect(q.splitCaption, '2 stores · 2 riders');
  });

  test('a store the server could not price hides the per-store fees (never shows ₱0)', () {
    final q = CheckoutQuote.fromJson(body(feeB: null));
    expect(q.deliveryTotal, isNull);
    expect(q.showsPerStoreFees, isFalse);
  });

  test('one store is not a split', () {
    final q = CheckoutQuote.fromJson({
      'deliveryTotal': 80,
      'groups': [
        {'key': 'vendor:a', 'label': 'Jollibee', 'itemCount': 1, 'fee': 80},
      ],
    });
    expect(q.isSplit, isFalse);
    expect(q.showsPerStoreFees, isFalse);
  });

  test('the cart key ignores line order', () {
    final a = checkoutQuoteCartKey([
      (productId: 'p2', variantId: null, quantity: 1),
      (productId: 'p1', variantId: 'v', quantity: 3),
    ]);
    final b = checkoutQuoteCartKey([
      (productId: 'p1', variantId: 'v', quantity: 3),
      (productId: 'p2', variantId: null, quantity: 1),
    ]);
    expect(a, b);
    expect(a, 'p1:v:3,p2::1');
  });

  test('the confirmation names the split', () {
    expect(splitCheckoutMessage(2), contains('2 orders'));
    expect(splitCheckoutMessage(2), contains('its own rider'));
  });
}
