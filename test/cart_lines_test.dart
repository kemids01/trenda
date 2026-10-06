// test/cart_lines_test.dart
// What the basket says is wrong with a line, and what checkout will refuse.
// Stock falls and shops close between adding an item and opening the cart —
// the cart used to show none of it and let checkout do the refusing.

import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/cart/models/cart_model.dart';
import 'package:trenda_frontend/features/cart/utils/cart_lines.dart';
import 'package:trenda_frontend/features/checkout/utils/store_grouping.dart';
import 'package:trenda_shared/models/product_model.dart';

CartItem _item({
  String id = 'line-1',
  String name = 'Pandesal',
  int quantity = 1,
  double price = 50,
  int stock = 10,
  String vendorId = 'vendor-1',
  String? storeName = 'Dubets Store',
  bool? isOpen,
  bool? canOrder,
}) {
  return CartItem(
    id: id,
    quantity: quantity,
    price: price,
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

void main() {
  group('cartLineStatus', () {
    test('a normal line is fine', () {
      final s = cartLineStatus(_item(quantity: 2, stock: 10));
      expect(s.issue, CartLineIssue.none);
      expect(s.isFine, isTrue);
      expect(s.blocksCheckout, isFalse);
    });

    test('no stock left blocks checkout', () {
      final s = cartLineStatus(_item(stock: 0));
      expect(s.issue, CartLineIssue.outOfStock);
      expect(s.blocksCheckout, isTrue);
    });

    test('more in the basket than the shop has blocks checkout, and reports '
        'what is available', () {
      final s = cartLineStatus(_item(quantity: 5, stock: 2));
      expect(s.issue, CartLineIssue.notEnoughStock);
      expect(s.available, 2);
      expect(s.blocksCheckout, isTrue);
    });

    test('exactly the last units is fine', () {
      expect(cartLineStatus(_item(quantity: 3, stock: 3)).isFine, isTrue);
    });

    test('a closed shop that refuses orders blocks checkout', () {
      final s = cartLineStatus(_item(isOpen: false, canOrder: false));
      expect(s.issue, CartLineIssue.storeClosed);
      expect(s.blocksCheckout, isTrue);
    });

    test('a closed shop taking advance orders WARNS but does not block', () {
      final s = cartLineStatus(_item(isOpen: false, canOrder: true));
      expect(s.issue, CartLineIssue.advanceOrder);
      expect(s.blocksCheckout, isFalse);
      expect(s.isFine, isFalse);
    });

    test('an unknown store status is treated as open', () {
      expect(cartLineStatus(_item()).isFine, isTrue);
    });

    test('stock problems outrank shop hours', () {
      // A closed shop can reopen; an item it does not have cannot be ordered
      // whatever the hours say — so the customer is told the useful thing.
      final s = cartLineStatus(
        _item(stock: 0, isOpen: false, canOrder: false),
      );
      expect(s.issue, CartLineIssue.outOfStock);
    });
  });

  group('blockedLines / cartBlockerSummary', () {
    test('picks out only the lines checkout will refuse', () {
      final items = [
        _item(id: 'ok'),
        _item(id: 'gone', stock: 0),
        _item(id: 'advance', isOpen: false, canOrder: true),
        _item(id: 'short', quantity: 9, stock: 1),
      ];

      expect(blockedLines(items).map((i) => i.id), ['gone', 'short']);
    });

    test('summary is null when the basket is good to go', () {
      expect(cartBlockerSummary([_item(), _item(id: 'b')]), isNull);
      expect(cartBlockerSummary(const []), isNull);
      // An advance order is not a blocker.
      expect(
        cartBlockerSummary([_item(isOpen: false, canOrder: true)]),
        isNull,
      );
    });

    test('summary counts and pluralises', () {
      expect(
        cartBlockerSummary([_item(stock: 0)]),
        '1 item needs your attention before checkout',
      );
      expect(
        cartBlockerSummary([_item(id: 'a', stock: 0), _item(id: 'b', stock: 0)]),
        '2 items need your attention before checkout',
      );
    });
  });

  group('cartLineMessage', () {
    test('out of stock offers removal', () {
      final m = cartLineMessage(const CartLineStatus(CartLineIssue.outOfStock));
      expect(m.label, 'Out of stock');
      expect(m.action, 'Remove');
    });

    test('short stock names the number and offers an update', () {
      final m = cartLineMessage(
        const CartLineStatus(CartLineIssue.notEnoughStock, available: 3),
      );
      expect(m.label, 'Only 3 left');
      expect(m.action, 'Update');
    });

    test('one left reads naturally', () {
      final m = cartLineMessage(
        const CartLineStatus(CartLineIssue.notEnoughStock, available: 1),
      );
      expect(m.label, 'Only 1 left');
    });

    test('closed-shop lines explain, with nothing to press', () {
      expect(
        cartLineMessage(const CartLineStatus(CartLineIssue.storeClosed)).action,
        isNull,
      );
      final advance =
          cartLineMessage(const CartLineStatus(CartLineIssue.advanceOrder));
      expect(advance.label, contains('reopens'));
      expect(advance.action, isNull);
    });
  });

  group('StoreGroup totals', () {
    test('sums a shop\'s own lines and units', () {
      final groups = groupItemsByStore([
        _item(id: 'a', price: 50, quantity: 2),
        _item(id: 'b', price: 25, quantity: 1),
        _item(id: 'c', storeName: 'Other Shop', price: 10, quantity: 3),
      ]);

      expect(groups.length, 2);
      expect(groups.first.subtotal, 125);
      expect(groups.first.itemCount, 3);
      expect(groups.last.subtotal, 30);
      expect(groups.last.itemCount, 3);
    });

    test('exposes the vendor id that seeds the shop colour', () {
      final groups = groupItemsByStore([_item(vendorId: 'vendor-42')]);
      expect(groups.single.vendorId, 'vendor-42');
    });

    test('survives items with no vendor id', () {
      final groups = groupItemsByStore([_item(vendorId: '')]);
      expect(groups.single.vendorId, '');
      expect(groups.single.subtotal, 50);
    });
  });
}
