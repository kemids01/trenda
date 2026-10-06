// The ordering and filtering behind "All items" and "On sale".
//
// The rules worth pinning: the shuffle is STABLE for a given seed (otherwise
// the grid deals itself again every time a shopper taps a chip), out-of-stock
// products never reach either grid, and "on sale" has exactly one definition.
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/products/utils/catalogue_browse.dart';
import 'package:trenda_shared/models/product_model.dart';

ProductModel _p({
  required String id,
  String name = 'Item',
  String category = 'Groceries',
  double price = 100,
  double? compareAt,
  int stock = 5,
  int reviews = 0,
  double rating = 0,
  DateTime? createdAt,
}) =>
    ProductModel.fromJson({
      '_id': id,
      'id': id,
      'name': name,
      'category': category,
      'basePrice': price,
      if (compareAt != null) 'compareAtPrice': compareAt,
      'totalStock': stock,
      'totalReviews': reviews,
      'averageRating': rating,
      'status': 'active',
      'createdAt': (createdAt ?? DateTime(2026, 1, 1)).toIso8601String(),
    });

void main() {
  group('palengkeProducts', () {
    test('fresh produce and meat & seafood only, in stock only', () {
      final list = [
        _p(id: 'veg', category: 'Fresh Produce'),
        _p(id: 'fish', category: 'Meat & Seafood'),
        _p(id: 'gone', category: 'Fresh Produce', stock: 0),
        _p(id: 'rice', category: 'Food & Beverages'),
        _p(id: 'adobo', category: 'Restaurant Food'),
      ];
      expect(palengkeProducts(list).map((p) => p.id), ['veg', 'fish']);
    });

    test('category spelling is matched loosely (case, spaces)', () {
      final list = [
        _p(id: 'a', category: ' fresh produce '),
        _p(id: 'b', category: 'MEAT & SEAFOOD'),
      ];
      expect(palengkeProducts(list).map((p) => p.id), ['a', 'b']);
    });
  });

  group('browsableProducts', () {
    test('drops out-of-stock items — a card nobody can buy is a dead end', () {
      final products = [
        _p(id: 'a'),
        _p(id: 'b', stock: 0),
        _p(id: 'c'),
      ];
      expect(
        browsableProducts(products).map((p) => p.id),
        ['a', 'c'],
      );
    });
  });

  group('onSaleProducts', () {
    test('a product is on sale only when compareAtPrice is ABOVE the price', () {
      final products = [
        _p(id: 'cut', price: 80, compareAt: 100),
        _p(id: 'no-compare', price: 80),
        // compareAt at or below the price is not a markdown; it is a data
        // entry mistake, and showing it would put a "0% off" card on the page.
        _p(id: 'equal', price: 100, compareAt: 100),
        _p(id: 'lower', price: 100, compareAt: 80),
      ];
      expect(onSaleProducts(products).map((p) => p.id), ['cut']);
    });

    test('an out-of-stock markdown does not reach the sale page either', () {
      final products = [_p(id: 'gone', price: 50, compareAt: 100, stock: 0)];
      expect(onSaleProducts(products), isEmpty);
    });
  });

  group('browseCategories', () {
    test('derives categories from the catalogue, most stocked first', () {
      final products = [
        _p(id: '1', category: 'Fashion'),
        _p(id: '2', category: 'Groceries'),
        _p(id: '3', category: 'Groceries'),
        _p(id: '4', category: 'Groceries'),
        _p(id: '5', category: 'Fashion'),
        _p(id: '6', category: 'Beauty'),
      ];
      expect(
        browseCategories(products),
        [kAllCategories, 'Groceries', 'Fashion', 'Beauty'],
      );
    });

    test('an empty catalogue still offers All, and nothing else', () {
      expect(browseCategories(const []), [kAllCategories]);
    });

    test('blank categories are not offered as a filter', () {
      final products = [_p(id: '1', category: '  '), _p(id: '2', category: 'Toys')];
      expect(browseCategories(products), [kAllCategories, 'Toys']);
    });
  });

  group('filterByCategory', () {
    final products = [
      _p(id: '1', category: 'Groceries'),
      _p(id: '2', category: 'Fashion'),
    ];

    test('All clears the filter', () {
      expect(filterByCategory(products, kAllCategories), hasLength(2));
      expect(filterByCategory(products, null), hasLength(2));
    });

    test('matches case-insensitively — categories are free text on the way in', () {
      expect(filterByCategory(products, 'groceries').map((p) => p.id), ['1']);
    });
  });

  group('sortForBrowse', () {
    final products = [
      _p(id: 'a', price: 300, reviews: 1, createdAt: DateTime(2026, 3, 1)),
      _p(id: 'b', price: 100, reviews: 9, createdAt: DateTime(2026, 1, 1)),
      _p(id: 'c', price: 200, reviews: 5, createdAt: DateTime(2026, 2, 1)),
    ];

    test('the SAME seed always deals the same order', () {
      // This is what stops the grid re-ordering under the shopper's thumb when
      // they tap a category chip or the keyboard opens.
      final first = sortForBrowse(products, BrowseSort.shuffle, seed: 42);
      final again = sortForBrowse(products, BrowseSort.shuffle, seed: 42);
      expect(first.map((p) => p.id), again.map((p) => p.id));
    });

    test('a different seed can deal a different order', () {
      // Over a handful of seeds at least one must differ, or "random" is not.
      final base =
          sortForBrowse(products, BrowseSort.shuffle, seed: 1).map((p) => p.id).toList();
      final differs = [2, 3, 4, 5, 6, 7].any((s) {
        final other =
            sortForBrowse(products, BrowseSort.shuffle, seed: s).map((p) => p.id).toList();
        return !const ListEquality().equals(base, other);
      });
      expect(differs, isTrue);
    });

    test('shuffle keeps every product — it re-orders, it does not sample', () {
      final out = sortForBrowse(products, BrowseSort.shuffle, seed: 7);
      expect(out.map((p) => p.id).toSet(), {'a', 'b', 'c'});
    });

    test('price sorts run both ways', () {
      expect(
        sortForBrowse(products, BrowseSort.priceLow, seed: 0).map((p) => p.id),
        ['b', 'c', 'a'],
      );
      expect(
        sortForBrowse(products, BrowseSort.priceHigh, seed: 0).map((p) => p.id),
        ['a', 'c', 'b'],
      );
    });

    test('newest first', () {
      expect(
        sortForBrowse(products, BrowseSort.newest, seed: 0).map((p) => p.id),
        ['a', 'c', 'b'],
      );
    });

    test('most reviewed first', () {
      expect(
        sortForBrowse(products, BrowseSort.popular, seed: 0).map((p) => p.id),
        ['b', 'c', 'a'],
      );
    });

    test('biggest discount first', () {
      final deals = [
        _p(id: 'small', price: 90, compareAt: 100),
        _p(id: 'big', price: 50, compareAt: 100),
        _p(id: 'mid', price: 75, compareAt: 100),
      ];
      expect(
        sortForBrowse(deals, BrowseSort.biggestDiscount, seed: 0).map((p) => p.id),
        ['big', 'mid', 'small'],
      );
    });

    test('ties break on id, so an unrelated rebuild cannot swap two rows', () {
      // Dart's sort is not stable; without the tie-break two equally priced
      // products change places for no reason the shopper can see.
      final tied = [
        _p(id: 'z', price: 100),
        _p(id: 'a', price: 100),
        _p(id: 'm', price: 100),
      ];
      expect(
        sortForBrowse(tied, BrowseSort.priceLow, seed: 0).map((p) => p.id),
        ['a', 'm', 'z'],
      );
    });

    test('does not mutate the caller\'s list', () {
      final source = [...products];
      sortForBrowse(source, BrowseSort.priceHigh, seed: 0);
      expect(source.map((p) => p.id), ['a', 'b', 'c']);
    });
  });

  group('browseGrid', () {
    test('filters before it sorts, and keeps the seed stable', () {
      final products = [
        _p(id: 'g1', category: 'Groceries', price: 300),
        _p(id: 'f1', category: 'Fashion', price: 100),
        _p(id: 'g2', category: 'Groceries', price: 100),
      ];
      expect(
        browseGrid(products, category: 'Groceries', sort: BrowseSort.priceLow, seed: 0)
            .map((p) => p.id),
        ['g2', 'g1'],
      );
    });
  });
}

/// Minimal list comparison — the package's ListEquality is not a dependency of
/// this app, and one call does not justify adding it.
class ListEquality {
  const ListEquality();
  bool equals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
