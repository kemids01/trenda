import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/utils/store_grouping.dart';
import 'package:trenda_frontend/features/cart/models/cart_model.dart';

CartItem _i(String id) => CartItem(id: id, onModel: 'Product', quantity: 1, price: 10);

void main() {
  test('groupItemsByStore groups by store, null fallback, preserves order', () {
    final groups = groupItemsByStore([_i('a'), _i('b')]);
    expect(groups.length, 1);
    expect(groups.first.storeName, 'Store');
    expect(groups.first.items.map((e) => e.id).toList(), ['a', 'b']);
  });

  test('empty cart -> empty groups', () {
    expect(groupItemsByStore([]), isEmpty);
  });
}
