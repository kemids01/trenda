import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/models/checkout_model.dart';

void main() {
  group('CheckoutRequest.toJson', () {
    final items = [CheckoutItem(productId: 'p1', quantity: 2)];

    test('includes coupon when set', () {
      final json = CheckoutRequest(
        shippingAddress: const {'city': 'X'},
        paymentMethod: PaymentMethod.cod,
        items: items,
        coupon: 'SAVE10',
      ).toJson();
      expect(json['coupon'], 'SAVE10');
    });

    test('omits coupon when null', () {
      final json = CheckoutRequest(
        shippingAddress: const {'city': 'X'},
        paymentMethod: PaymentMethod.cod,
        items: items,
      ).toJson();
      expect(json.containsKey('coupon'), false);
    });
  });

  group('CheckoutItem.toJson', () {
    test('includes variantId when set', () {
      final json =
          CheckoutItem(productId: 'p1', quantity: 1, variantId: 'v9').toJson();
      expect(json['variantId'], 'v9');
    });

    test('omits variantId when null', () {
      final json = CheckoutItem(productId: 'p1', quantity: 1).toJson();
      expect(json.containsKey('variantId'), false);
    });
  });
}
