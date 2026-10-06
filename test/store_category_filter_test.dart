import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/store_category_chips.dart';
import 'package:trenda_frontend/features/home/providers/stores_provider.dart';

StoreData _store(String id, Map<String, dynamic>? category) => StoreData.fromJson({
      'id': id,
      'name': id,
      'storeStatus': {'isOpen': true},
      if (category != null) 'storeCategory': category,
    });

void main() {
  final deck = [
    _store('mart', {
      'group': 'grocery-convenience',
      'groupName': 'Grocery & Convenience',
      'subcategories': [
        {'key': 'food-beverage.bakeries', 'name': 'Bakeries'},
      ],
    }),
    _store('cafe', {
      'group': 'food-beverage',
      'groupName': 'Food & Beverage',
      'subcategories': [
        {'key': 'food-beverage.cafes', 'name': 'Cafes'},
      ],
    }),
    _store('unsorted', null),
  ];

  List<String> ids(StoreCategoryFilter f) => filterStoresByCategory(deck, f).map((s) => s.id).toList();

  test('the card parses its category', () {
    expect(deck.first.storeCategory!.groupName, 'Grocery & Convenience');
    expect(deck.first.category, '');
    expect(deck.last.storeCategory, isNull);
  });

  test('All keeps every store, uncategorized included', () {
    expect(ids(const StoreCategoryFilter()), ['mart', 'cafe', 'unsorted']);
  });

  test('a group matches the primary OR a secondary in it', () {
    expect(ids(const StoreCategoryFilter(group: 'food-beverage')), ['mart', 'cafe']);
    expect(ids(const StoreCategoryFilter(group: 'grocery-convenience')), ['mart']);
    expect(ids(const StoreCategoryFilter(group: 'pets')), isEmpty);
  });

  test('a subcategory matches only stores that ticked it', () {
    expect(ids(const StoreCategoryFilter(group: 'food-beverage', sub: 'food-beverage.cafes')),
        ['cafe']);
  });
}
