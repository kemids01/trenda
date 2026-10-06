// The Food tab's "All restaurant food" grid: which products, in what order,
// and the subcategory chips built from what vendors listed.
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/utils/food_catalogue.dart';
import 'package:trenda_shared/models/product_model.dart';

ProductModel _p(
  String id, {
  String name = 'Item',
  String category = 'Restaurant Food',
  String? sub,
  int stock = 5,
}) =>
    ProductModel.fromJson({
      '_id': id,
      'id': id,
      'name': name,
      'category': category,
      if (sub != null) 'subcategory': sub,
      'basePrice': 100,
      'totalStock': stock,
      'status': 'active',
    });

void main() {
  test('only in-stock Restaurant Food, by name', () {
    final out = restaurantFood([
      _p('1', name: 'Pancit'),
      _p('2', name: 'Adobo'),
      _p('3', name: 'Rice 5kg', category: 'Food & Beverages'),
      _p('4', name: 'Sold out halo-halo', stock: 0),
      _p('5', name: 'Burger', category: 'restaurant food'),
    ]);
    expect(out.map((p) => p.name), ['Adobo', 'Burger', 'Pancit']);
  });

  test('chips come from what vendors listed, most items first', () {
    final food = [
      _p('1', sub: 'Drinks'),
      _p('2', sub: 'Meals'),
      _p('3', sub: 'meals'),
      _p('4'),
    ];
    expect(foodSubcategories(food), ['Meals', 'Drinks']);
  });

  test('a chip filters case-insensitively; none shows everything', () {
    final food = [_p('1', sub: 'Meals'), _p('2', sub: 'meals'), _p('3')];
    expect(filterFoodBySubcategory(food, 'MEALS').map((p) => p.id), ['1', '2']);
    expect(filterFoodBySubcategory(food, null), hasLength(3));
  });
}
