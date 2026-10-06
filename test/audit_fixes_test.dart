// test/audit_fixes_test.dart
// Regressions for the 2026-09-28 customer-app audit. Each group names the bug it
// pins; the comments at the fix sites explain the mechanism.

import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/cart/data/cart_repository.dart';
import 'package:trenda_frontend/features/cart/models/cart_model.dart';
import 'package:trenda_frontend/features/cart/providers/cart_provider.dart';
import 'package:trenda_frontend/features/checkout/data/checkout_repository.dart';
import 'package:trenda_frontend/features/checkout/data/pasabay_repository.dart';
import 'package:trenda_frontend/features/checkout/logic/pasabay_tiers.dart';
import 'package:trenda_frontend/features/orders/data/orders_repository.dart';
import 'package:trenda_frontend/features/orders/utils/order_presentation.dart';
import 'package:trenda_shared/models/product_model.dart';

/// A cart repository whose writes the "server" refuses.
class _RefusingCartRepository extends CartRepository {
  _RefusingCartRepository() : super(baseUrl: 'http://test');

  int getCartCalls = 0;

  @override
  Future<CartModel> getCart() async {
    getCartCalls++;
    return CartModel.empty();
  }

  @override
  Future<void> addToCart({
    required String productId,
    required int quantity,
    String? variantId,
  }) async {
    throw const CartException('Insufficient stock. Available: 2',
        statusCode: 400);
  }
}

void main() {
  group('My Returns reads the paginated body (was always empty)', () {
    test('ApiResponse.paginated puts the ARRAY in data', () {
      final rows = returnsFromResponse({
        'success': true,
        'data': [
          {'_id': 'r1'},
          {'_id': 'r2'},
        ],
        'pagination': {'page': 1},
      });
      expect(rows, hasLength(2));
    });

    test('still accepts data.returns and a top-level returns', () {
      expect(
          returnsFromResponse({
            'data': {
              'returns': [
                {'_id': 'r1'}
              ]
            }
          }),
          hasLength(1));
      expect(
          returnsFromResponse({
            'returns': [
              {'_id': 'r1'}
            ]
          }),
          hasLength(1));
    });

    test('anything else is empty, never a crash', () {
      expect(returnsFromResponse({}), isEmpty);
      expect(returnsFromResponse({'data': 'oops'}), isEmpty);
    });
  });

  group('every order lands in a tab (Pasabay orders vanished)', () {
    test('the statuses that fell out of every tab are Active', () {
      for (final s in [
        'assigned_to_rider',
        'waiting_for_batch',
        'batch_ready',
        'delivery_failed',
        'delivery_refused',
        'pending_address_verification',
        'rescheduled',
        'returning_to_vendor',
        'return_to_vendor',
        'awaiting_replacement',
      ]) {
        expect(orderBucket(s), OrderBucket.active, reason: s);
        expect(isTerminalOrder(s), isFalse, reason: s);
      }
    });

    test('a status this build has never seen is Active, not lost', () {
      expect(orderBucket('some_future_status'), OrderBucket.active);
    });

    test('terminal statuses', () {
      expect(orderBucket('delivered'), OrderBucket.done);
      expect(orderBucket('completed'), OrderBucket.done);
      for (final s in ['cancelled', 'refunded', 'failed', 'returned']) {
        expect(orderBucket(s), OrderBucket.cancelled, reason: s);
      }
    });

    test('case and whitespace do not move an order', () {
      expect(orderBucket(' Delivered '), OrderBucket.done);
    });

    test('exception statuses read as plain words, not tokens', () {
      expect(orderStatusView('pending_address_verification').label,
          'Checking your address');
      expect(orderStatusView('returning_to_vendor').label, 'Returning to shop');
    });
  });

  group('cart refusals are reported, and the cart is kept', () {
    test('a refused add returns false with the server message', () async {
      final repo = _RefusingCartRepository();
      final cart = CartNotifier(repo);
      await Future<void>.delayed(Duration.zero); // initial load
      final before = cart.state;

      final ok = await cart.addToCart(ProductModel.fromJson(const {
        '_id': 'p1',
        'name': 'Rice',
        'basePrice': 50,
      }));

      expect(ok, isFalse);
      expect(cart.lastError, 'Insufficient stock. Available: 2');
      // Not replaced by an error state — the basket stays on screen.
      expect(cart.state, same(before));
      expect(cart.state.hasValue, isTrue);
      cart.dispose();
    });

    test('CartException prints only its message', () {
      expect(const CartException('Out of stock').toString(), 'Out of stock');
    });
  });

  group('checkout idempotency key (duplicate orders)', () {
    var n = 0;
    String gen() => 'checkout-key-${n++}-padding';

    test('a retry of the SAME unanswered order reuses the key', () {
      final ledger = IdempotencyKeyLedger();
      final a = ledger.keyFor('{"items":[1]}', gen);
      final b = ledger.keyFor('{"items":[1]}', gen);
      expect(b, a);
    });

    test('a different order gets a new key', () {
      final ledger = IdempotencyKeyLedger();
      final a = ledger.keyFor('{"items":[1]}', gen);
      final b = ledger.keyFor('{"items":[2]}', gen);
      expect(b, isNot(a));
    });

    test('after a definitive answer the same order gets a new key', () {
      // The server caches the first answer for 24 h, errors included — reusing
      // the key after "Insufficient stock" would replay that refusal all day.
      final ledger = IdempotencyKeyLedger();
      final a = ledger.keyFor('{"items":[1]}', gen);
      ledger.settle();
      final b = ledger.keyFor('{"items":[1]}', gen);
      expect(b, isNot(a));
    });

    test('CheckoutException carries a shopper-facing message', () {
      expect(const CheckoutException('Please wait').toString(), 'Please wait');
    });
  });

  group('Pasabay tiers come from the server, not a literal', () {
    PasabayBatchTypeInfo tier(String name, int target,
            {int? timeout, bool active = true}) =>
        PasabayBatchTypeInfo(
          id: name,
          name: name,
          code: name.toUpperCase(),
          targetOrders: target,
          timeoutMinutes: timeout,
          active: active,
        );

    test('a switched-off tier is not offered', () {
      final previews = activePreviews([
        PasabayFeePreview(batchType: tier('Saver 5', 5)),
        PasabayFeePreview(batchType: tier('Super Saver 10', 10, active: false)),
      ]);
      expect(previews.map((p) => p.batchType!.name), ['Saver 5']);
    });

    test('active is read from the payload; absent means active', () {
      expect(
          PasabayBatchTypeInfo.fromJson(const {'_id': 'a', 'active': false})
              .active,
          isFalse);
      expect(PasabayBatchTypeInfo.fromJson(const {'_id': 'a'}).active, isTrue);
    });

    test('the guide names each offered tier with its real wait', () {
      final lines = pasabayGuideLines([tier('Saver 5', 5, timeout: 180)]);
      expect(lines, contains('Saver 5: dispatches once 5 orders join. Waits up to 3 hours.'));
      expect(lines.join(), isNot(contains('Super Saver')));
    });

    test('waitLabel', () {
      expect(waitLabel(60), '1 hour');
      expect(waitLabel(1440), '24 hours');
      expect(waitLabel(90), '90 minutes');
    });
  });
}
