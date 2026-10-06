import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_shared/models/product_model.dart';
import 'package:trenda_frontend/features/home/utils/official_store_filters.dart';

ProductModel p({
  String id = '1',
  String name = 'Item',
  String category = 'Electronics',
  num basePrice = 100,
  num? compareAt,
  bool freeDelivery = false,
  String vendor = kOfficialStoreVendorId,
}) =>
    ProductModel.fromJson({
      '_id': id,
      'name': name,
      'slug': name.toLowerCase(),
      'category': category,
      'basePrice': basePrice,
      if (compareAt != null) 'compareAtPrice': compareAt,
      'freeDelivery': freeDelivery,
      'vendor': vendor,
    });

void main() {
  group('isOfficialProduct', () {
    test('true for the official store vendor', () {
      expect(isOfficialProduct(p(vendor: kOfficialStoreVendorId)), true);
      expect(isOfficialProduct(p(vendor: 'some-other-vendor')), false);
    });
  });

  group('officialCategories', () {
    test('distinct categories, All first, sorted', () {
      final cats = officialCategories([
        p(category: 'Electronics'),
        p(category: 'Beauty'),
        p(category: 'Electronics'),
      ]);
      expect(cats.first, 'All');
      expect(cats, ['All', 'Beauty', 'Electronics']);
    });
  });

  group('filter', () {
    final items = [
      p(id: '1', name: 'Phone', category: 'Electronics'),
      p(id: '2', name: 'Lipstick', category: 'Beauty'),
    ];
    test('category narrows', () {
      expect(filterOfficial(items, category: 'Beauty').map((e) => e.id), ['2']);
    });
    test('query matches name/category', () {
      expect(filterOfficial(items, query: 'phone').map((e) => e.id), ['1']);
      expect(filterOfficial(items, query: 'beauty').map((e) => e.id), ['2']);
    });
    test('every word must match, in any order', () {
      final list = [
        p(id: '1', name: 'Dove Soap Bar', category: 'Personal Care'),
        p(id: '2', name: 'Safeguard Soap', category: 'Personal Care'),
      ];
      expect(filterOfficial(list, query: 'soap dove').map((e) => e.id), ['1']);
      expect(filterOfficial(list, query: '  SOAP  ').map((e) => e.id),
          ['1', '2']);
      expect(filterOfficial(list, query: 'soap lotion'), isEmpty);
    });
    test('query also searches description, brand, subcategory and tags', () {
      final list = [
        ProductModel.fromJson({
          '_id': '9',
          'name': 'Bar 90g',
          'slug': 'bar',
          'category': 'Personal Care',
          'subcategory': 'Bath Soap',
          'brand': 'Dove',
          'tags': ['moisturizing'],
          'description': 'Gentle beauty bar',
          'basePrice': 50,
          'vendor': kOfficialStoreVendorId,
        }),
      ];
      for (final q in ['beauty', 'dove', 'bath', 'moisturizing']) {
        expect(filterOfficial(list, query: q).map((e) => e.id), ['9'],
            reason: q);
      }
    });
    test('onSaleOnly keeps only discounted', () {
      final list = [p(id: '1', basePrice: 100), p(id: '2', basePrice: 100, compareAt: 150)];
      expect(filterOfficial(list, onSaleOnly: true).map((e) => e.id), ['2']);
    });
    test('freeDeliveryOnly keeps only free-delivery', () {
      final list = [p(id: '1'), p(id: '2', freeDelivery: true)];
      expect(filterOfficial(list, freeDeliveryOnly: true).map((e) => e.id), ['2']);
    });
    test('savedOnly keeps only saved ids', () {
      final list = [p(id: '1'), p(id: '2')];
      expect(filterOfficial(list, savedOnly: true, savedIds: {'2'}).map((e) => e.id), ['2']);
    });
  });

  group('sort', () {
    final items = [
      p(id: 'a', basePrice: 300, compareAt: 400), // 25% off
      p(id: 'b', basePrice: 100),
      p(id: 'c', basePrice: 200, compareAt: 250), // 20% off
    ];
    test('price asc/desc', () {
      expect(sortOfficial(items, 'price_asc').map((e) => e.id), ['b', 'c', 'a']);
      expect(sortOfficial(items, 'price_desc').map((e) => e.id), ['a', 'c', 'b']);
    });
    test('discount biggest first', () {
      expect(sortOfficial(items, 'discount').first.id, 'a');
    });
    test('newest keeps order', () {
      expect(sortOfficial(items, 'newest').map((e) => e.id), ['a', 'b', 'c']);
    });
  });
}
