// test/cart_page_test.dart
// The basket screen: grouped by shop, variants visible, line totals, and a
// checkout button that refuses to send a basket checkout would reject.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/cart/models/cart_model.dart';
import 'package:trenda_frontend/features/cart/presentation/cart_page.dart';
import 'package:trenda_shared/models/product_model.dart';

CartItem _item({
  String id = 'line-1',
  String name = 'Pandesal',
  int quantity = 1,
  double price = 50,
  int stock = 10,
  String vendorId = 'vendor-1',
  String? storeName = 'Dubets Store',
  String? variantName,
  bool? isOpen,
  bool? canOrder,
}) {
  return CartItem(
    id: id,
    quantity: quantity,
    price: price,
    variantName: variantName,
    product: ProductModel(
      id: 'p-$id',
      name: name,
      slug: 'p-$id',
      vendorId: vendorId,
      storeName: storeName,
      basePrice: price,
      totalStock: stock,
      category: 'Bakery',
      storeStatus: isOpen == null && canOrder == null
          ? null
          : ProductStoreStatus(
              isOpen: isOpen ?? true,
              canOrder: canOrder ?? true,
            ),
    ),
  );
}

CartModel _cart(List<CartItem> items) => CartModel(
      items: items,
      subtotal: items.fold<double>(0, (s, i) => s + i.subtotal),
      itemCount: items.length,
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
}

/// Lines and the summary are pumped separately: with a one-item basket the
/// line total and the basket total are the same string, so a combined tree
/// cannot tell which widget a match came from.
Future<void> _pumpLines(WidgetTester tester, List<CartItem> items) => _pump(
      tester,
      ListView(children: [for (final i in items) CartItemCard(item: i)]),
    );

Future<void> _pumpSummary(WidgetTester tester, CartModel cart) => _pump(tester,
    Align(alignment: Alignment.bottomCenter, child: CartSummary(cart: cart)));

void main() {
  group('CartItemCard', () {
    testWidgets('shows the line total, and the unit price only when it differs',
        (tester) async {
      await _pumpLines(tester, ([_item(price: 50, quantity: 3)]));

      expect(find.text('₱150.00'), findsOneWidget);
      expect(find.text('₱50.00 each'), findsOneWidget);
    });

    testWidgets('a single unit does not repeat the price', (tester) async {
      await _pumpLines(tester, ([_item(price: 50, quantity: 1)]));

      expect(find.text('₱50.00'), findsWidgets);
      expect(find.textContaining('each'), findsNothing);
    });

    testWidgets(
        'shows the chosen variant — two sizes of one product were '
        'indistinguishable before', (tester) async {
      await _pumpLines(
        tester,
        ([_item(variantName: 'Large / Wheat')]),
      );

      expect(find.text('Large / Wheat'), findsOneWidget);
    });

    testWidgets('out of stock is flagged with a way to fix it', (tester) async {
      await _pumpLines(tester, ([_item(stock: 0)]));

      expect(find.text('Out of stock'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('short stock names the number and offers an update',
        (tester) async {
      await _pumpLines(tester, ([_item(quantity: 8, stock: 2)]));

      expect(find.text('Only 2 left'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
    });

    testWidgets('a closed shop is surfaced in the basket, not at checkout',
        (tester) async {
      await _pumpLines(
        tester,
        ([_item(isOpen: false, canOrder: false)]),
      );

      expect(find.text('Shop closed — not taking orders'), findsOneWidget);
    });

    testWidgets('an advance-order shop reads as a note, not an error',
        (tester) async {
      await _pumpLines(
        tester,
        ([_item(isOpen: false, canOrder: true)]),
      );

      expect(
        find.text('Shop closed — delivered when it reopens'),
        findsOneWidget,
      );
    });

    testWidgets('a healthy line shows no warning strip', (tester) async {
      await _pumpLines(tester, ([_item()]));

      expect(find.textContaining('Out of stock'), findsNothing);
      expect(find.textContaining('Only'), findsNothing);
      expect(find.textContaining('closed'), findsNothing);
    });

    testWidgets('a long product name does not overflow', (tester) async {
      await _pumpLines(
        tester,
        ([
          _item(
            name:
                'Santissima Trinidad Premium Whole Wheat Pandesal Family Pack',
            variantName: 'Extra Large Family Size / Whole Wheat',
            price: 123456,
            quantity: 12,
          ),
        ]),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('CartSummary', () {
    testWidgets('counts units, not lines', (tester) async {
      await _pumpSummary(
        tester,
        _cart([
          _item(id: 'a', quantity: 2),
          _item(id: 'b', quantity: 3),
        ]),
      );

      expect(find.text('5 items'), findsOneWidget);
    });

    testWidgets('names how many shops when the basket spans several',
        (tester) async {
      await _pumpSummary(
        tester,
        _cart([
          _item(id: 'a', storeName: 'Dubets Store'),
          _item(id: 'b', storeName: 'Aling Nena'),
        ]),
      );

      expect(find.text('2 items from 2 shops'), findsOneWidget);
    });

    testWidgets('single shop basket does not mention shop count',
        (tester) async {
      await _pumpSummary(tester, _cart([_item()]));

      expect(find.text('1 item'), findsOneWidget);
      expect(find.textContaining('shops'), findsNothing);
    });

    testWidgets('checkout is live for a healthy basket', (tester) async {
      await _pumpSummary(tester, _cart([_item()]));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
      expect(find.textContaining('flagged'), findsNothing);
    });

    testWidgets('checkout is blocked, and says why, when a line is unbuyable',
        (tester) async {
      await _pumpSummary(
        tester,
        _cart([_item(id: 'a'), _item(id: 'b', stock: 0)]),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(
          find.text('Sort out the flagged items to continue'), findsOneWidget);
    });

    testWidgets('an advance-order line does NOT block checkout',
        (tester) async {
      await _pumpSummary(
        tester,
        _cart([_item(isOpen: false, canOrder: true)]),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('always states that delivery is settled at checkout',
        (tester) async {
      await _pumpSummary(tester, _cart([_item()]));

      expect(find.text('Delivery calculated at checkout'), findsOneWidget);
    });
  });
}
