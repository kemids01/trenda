// test/home_rails_test.dart
// The home shelves are derived from the real catalogue. These replaced two
// wireframe boxes ("TOP 10 / NON FEATURED ADS / CAROUSEL") that shipped to
// customers, so the rules behind them are worth pinning.

import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/utils/home_rails.dart';
import 'package:trenda_shared/models/product_model.dart';

ProductModel _p({
  required String id,
  String name = 'Item',
  double price = 100,
  double? compareAt,
  int stock = 10,
  int sales = 0,
  double rating = 0,
  bool featured = false,
  String category = 'Grocery',
  DateTime? createdAt,
}) {
  return ProductModel(
    id: id,
    name: name,
    slug: 'item-$id',
    vendorId: 'vendor-$id',
    basePrice: price,
    compareAtPrice: compareAt,
    totalStock: stock,
    category: category,
    featured: featured,
    sales: sales,
    averageRating: rating,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

void main() {
  group('topDeals', () {
    test('keeps only discounted items, deepest cut first', () {
      final deals = topDeals([
        _p(id: 'a', price: 90, compareAt: 100), // 10%
        _p(id: 'b', price: 100), // none
        _p(id: 'c', price: 50, compareAt: 100), // 50%
        _p(id: 'd', price: 80, compareAt: 100), // 20%
      ]);

      expect(deals.map((p) => p.id), ['c', 'd', 'a']);
    });

    test('excludes sold-out items — a deal you cannot buy is not a deal', () {
      final deals = topDeals([
        _p(id: 'gone', price: 10, compareAt: 100, stock: 0),
        _p(id: 'here', price: 90, compareAt: 100),
      ]);

      expect(deals.map((p) => p.id), ['here']);
    });

    test('is empty when nothing is on sale, so the shelf can hide', () {
      expect(topDeals([_p(id: 'a'), _p(id: 'b')]), isEmpty);
    });

    test('respects the limit', () {
      final many = List.generate(
        20,
        (i) => _p(id: '$i', price: 50, compareAt: 100),
      );
      expect(topDeals(many).length, 10);
      expect(topDeals(many, limit: 3).length, 3);
    });

    test('ties break on price, so the order is stable', () {
      final deals = topDeals([
        _p(id: 'pricey', price: 500, compareAt: 1000),
        _p(id: 'cheap', price: 50, compareAt: 100),
      ]);
      expect(deals.map((p) => p.id), ['cheap', 'pricey']);
    });
  });

  group('bestSellers', () {
    test('orders by units sold and drops items nobody bought', () {
      final sellers = bestSellers([
        _p(id: 'a', sales: 3),
        _p(id: 'b', sales: 0),
        _p(id: 'c', sales: 11),
      ]);

      expect(sellers.map((p) => p.id), ['c', 'a']);
    });

    test('ties break on rating', () {
      final sellers = bestSellers([
        _p(id: 'low', sales: 5, rating: 3.0),
        _p(id: 'high', sales: 5, rating: 4.8),
      ]);
      expect(sellers.first.id, 'high');
    });

    test('excludes sold-out items', () {
      expect(bestSellers([_p(id: 'a', sales: 99, stock: 0)]), isEmpty);
    });
  });

  group('freshArrivals', () {
    test('newest first', () {
      final fresh = freshArrivals([
        _p(id: 'old', createdAt: DateTime(2025, 1, 1)),
        _p(id: 'new', createdAt: DateTime(2026, 9, 1)),
        _p(id: 'mid', createdAt: DateTime(2026, 3, 1)),
      ]);

      expect(fresh.map((p) => p.id), ['new', 'mid', 'old']);
    });

    test('excludes sold-out items', () {
      final fresh = freshArrivals([
        _p(id: 'gone', stock: 0, createdAt: DateTime(2026, 9, 1)),
        _p(id: 'here', createdAt: DateTime(2025, 1, 1)),
      ]);
      expect(fresh.map((p) => p.id), ['here']);
    });
  });

  group('featuredShelf', () {
    test('prefers featured products', () {
      final shelf = featuredShelf([
        _p(id: 'plain'),
        _p(id: 'star', featured: true),
      ], limit: 1);

      expect(shelf.map((p) => p.id), ['star']);
    });

    test('tops up with the newest so the shelf is never half empty', () {
      final shelf = featuredShelf([
        _p(id: 'star', featured: true),
        _p(id: 'new', createdAt: DateTime(2026, 9, 1)),
        _p(id: 'old', createdAt: DateTime(2025, 1, 1)),
      ], limit: 3);

      expect(shelf.map((p) => p.id), ['star', 'new', 'old']);
    });

    test('never repeats a product that is both featured and new', () {
      final shelf = featuredShelf([
        _p(id: 'star', featured: true, createdAt: DateTime(2026, 9, 1)),
        _p(id: 'other', createdAt: DateTime(2025, 1, 1)),
      ], limit: 4);

      expect(shelf.map((p) => p.id).toList(), ['star', 'other']);
      expect(shelf.map((p) => p.id).toSet().length, shelf.length);
    });

    test('empty catalogue yields an empty shelf', () {
      expect(featuredShelf(const []), isEmpty);
    });
  });

  group('catalogueCategories', () {
    test('orders by how much stock backs each category', () {
      final categories = catalogueCategories([
        _p(id: '1', category: 'Snacks'),
        _p(id: '2', category: 'Grocery'),
        _p(id: '3', category: 'Grocery'),
        _p(id: '4', category: 'Grocery'),
        _p(id: '5', category: 'Snacks'),
        _p(id: '6', category: 'Hardware'),
      ]);

      expect(categories, ['Grocery', 'Snacks', 'Hardware']);
    });

    test('ignores blank categories', () {
      final categories = catalogueCategories([
        _p(id: '1', category: '   '),
        _p(id: '2', category: 'Grocery'),
      ]);
      expect(categories, ['Grocery']);
    });

    test('caps the strip', () {
      final many = List.generate(
        20,
        (i) => _p(id: '$i', category: 'Cat$i'),
      );
      expect(catalogueCategories(many).length, 8);
      expect(catalogueCategories(many, limit: 3).length, 3);
    });

    test('empty catalogue yields no categories', () {
      expect(catalogueCategories(const []), isEmpty);
    });
  });

  group('shelfPrice', () {
    test('groups thousands and drops the centavos', () {
      expect(shelfPrice(1299), '₱1,299');
      expect(shelfPrice(999), '₱999');
      expect(shelfPrice(1234567), '₱1,234,567');
      expect(shelfPrice(0), '₱0');
    });

    test('rounds rather than truncating', () {
      expect(shelfPrice(99.5), '₱100');
      expect(shelfPrice(99.4), '₱99');
    });
  });
}
