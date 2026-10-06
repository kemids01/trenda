// A closed store that still takes orders: the shopper is told, before and
// after ordering, that the store accepts the order when it opens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/cart/models/cart_model.dart';
import 'package:trenda_frontend/features/stores/utils/advance_order_notice.dart';
import 'package:trenda_frontend/features/stores/widgets/advance_order_notice.dart';
import 'package:trenda_shared/models/order_model.dart';
import 'package:trenda_shared/models/product_model.dart';

CartItem _item(String id, String store,
        {bool open = true, bool canOrder = true, String? day, String? at}) =>
    CartItem(
      id: id,
      product: ProductModel.fromJson({
        '_id': id,
        'id': id,
        'name': 'Item $id',
        'category': 'Bakery',
        'basePrice': 50,
        'totalStock': 10,
        'status': 'active',
        'storeName': store,
        'storeStatus': {
          'isOpen': open,
          'canOrder': canOrder,
          if (day != null || at != null)
            'nextOpenTime': {'day': day, 'open': at},
        },
      }),
      quantity: 1,
      price: 50,
    );

OrderModel _order({String status = 'pending', Map<String, dynamic>? advance}) =>
    OrderModel.fromJson({
      '_id': 'o1',
      'orderNumber': 'ORD-1',
      'customer': 'c1',
      'items': [],
      'subtotal': 50,
      'shippingFee': 0,
      'tax': 0,
      'total': 50,
      'paymentMethod': {'type': 'cod'},
      'paymentStatus': 'pending',
      'status': status,
      if (advance != null) 'advanceOrder': advance,
    });

void main() {
  group('checkout notice', () {
    test('names the closed store and when it opens', () {
      final stores = advanceOrderStores([
        _item('1', 'Aling Nena', open: false, day: 'monday', at: '08:00'),
        _item('2', 'Bakeshop'),
      ]);
      expect(stores.map((s) => s.name), ['Aling Nena']);
      final msg = advanceOrderMessage(stores)!;
      expect(msg, contains('Aling Nena is closed right now'));
      expect(msg, contains('accept and process your order when it opens'));
      expect(msg, contains('Opens Mon · 8:00 AM'));
    });

    test('nothing to say when every store is open', () {
      expect(advanceOrderMessage(advanceOrderStores([_item('1', 'Open shop')])),
          isNull);
    });

    test('a store NOT taking orders is not an advance order (checkout blocks it)', () {
      expect(
          advanceOrderStores(
              [_item('1', 'Shut', open: false, canOrder: false)]),
          isEmpty);
    });

    test('several closed stores are summarised, each listed once', () {
      final stores = advanceOrderStores([
        _item('1', 'A', open: false),
        _item('2', 'A', open: false),
        _item('3', 'B', open: false),
      ]);
      expect(stores, hasLength(2));
      expect(advanceOrderMessage(stores), startsWith('2 stores in your order'));
    });
  });

  group('order screens', () {
    test('show the note while the order waits, not after it is accepted', () {
      final advance = {
        'placedWhileClosed': true,
        'nextOpenTime': {'day': 'saturday', 'open': '09:00'},
      };
      expect(isAwaitingStoreOpening(_order(advance: advance)), isTrue);
      expect(isAwaitingStoreOpening(_order(status: 'confirmed', advance: advance)),
          isFalse);
      expect(isAwaitingStoreOpening(_order()), isFalse);
      expect(awaitingStoreMessage(_order(advance: advance).advanceOrder!),
          contains('Opens Sat · 9:00 AM'));
    });
  });

  testWidgets('the banner renders its title and message', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AdvanceOrderNotice(message: 'Opens Mon')),
    ));
    expect(find.text('Store is closed right now'), findsOneWidget);
    expect(find.text('Opens Mon'), findsOneWidget);
  });
}
