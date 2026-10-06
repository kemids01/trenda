// Palengke — the Shop tab's fresh-market lane: vegetables, fruit, meat and
// fish, drawn from the existing Fresh Produce and Meat & Seafood categories.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/core/widgets/frontend_official_ad_slot.dart';
import 'package:trenda_frontend/features/home/providers/shop_category_provider.dart';
import 'package:trenda_frontend/features/home/providers/shop_sections_provider.dart';
import 'package:trenda_frontend/features/home/providers/stores_provider.dart';
import 'package:trenda_frontend/features/products/presentation/product_browse_page.dart';
import 'package:trenda_frontend/features/products/providers/products_provider.dart';
import 'package:trenda_shared/models/product_model.dart';

ProductModel _p(String id, String name, String category,
        {int stock = 5, String vendor = 'v-market'}) =>
    ProductModel.fromJson({
      '_id': id,
      'id': id,
      'vendor': vendor,
      'name': name,
      'category': category,
      'basePrice': 80,
      'totalStock': stock,
      'status': 'active',
      'createdAt': DateTime(2026, 9, 1).toIso8601String(),
    });

StoreData _store(String id, String name) => StoreData.fromJson({
      'id': id,
      'name': name,
      'category': '',
      'rating': 4.5,
      'reviewCount': 3,
      'productCount': 10,
      'isFeatured': false,
      'municipality': 'Tuguegarao City',
      'storeStatus': {'isOpen': true},
    });

/// Placements the page asked the server for.
final List<String> _asked = [];

/// Category lists the page asked the server for.
final List<String> _categoriesAsked = [];

Future<void> _pump(WidgetTester tester, List<ProductModel> products,
    {List<ShopSection> bands = const []}) async {
  _asked.clear();
  _categoriesAsked.clear();
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      categoryProductsProvider.overrideWith((ref, categories) async {
        _categoriesAsked.add(categories);
        return products;
      }),
      publicStoresProvider.overrideWith((ref) async => {
            'featured': <StoreData>[],
            'open': [
              _store('v-market', 'Mariton Fresh'),
              _store('v-hardware', 'Wilcon Depot'),
            ],
            'closed': <StoreData>[],
          }),
      shopSectionsForPlacementProvider.overrideWith((ref, placement) async {
        _asked.add(placement);
        return bands;
      }),
    ],
    child: const MaterialApp(
      home: ProductBrowsePage(mode: BrowseMode.palengke),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('lists only in-stock vegetables, fruit, meat and fish',
      (tester) async {
    await _pump(tester, [
      _p('1', 'Pechay Bundle', 'Fresh Produce'),
      _p('2', 'Bangus 1kg', 'Meat & Seafood'),
      _p('3', 'Kangkong', 'Fresh Produce', stock: 0),
      _p('4', 'Rice 5kg', 'Food & Beverages'),
      _p('5', 'Chicken Adobo', 'Restaurant Food'),
      _p('6', 'Phone Case', 'Electronics'),
    ]);

    expect(find.text('Palengke'), findsOneWidget);
    expect(find.text('Pechay Bundle'), findsOneWidget);
    expect(find.text('Bangus 1kg'), findsOneWidget);
    expect(find.text('Kangkong'), findsNothing);
    expect(find.text('Rice 5kg'), findsNothing);
    expect(find.text('Chicken Adobo'), findsNothing);
    expect(find.text('Phone Case'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing fresh listed says so plainly', (tester) async {
    await _pump(tester, [_p('4', 'Rice 5kg', 'Food & Beverages')]);
    expect(find.text('No fresh market items yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the admin-curated Palengke carousel above the grid',
      (tester) async {
    await _pump(
      tester,
      [_p('1', 'Pechay Bundle', 'Fresh Produce')],
      bands: const [
        ShopSection(id: 'b', title: 'Fresh today', products: []),
      ],
    );
    expect(_asked, contains(ShopSectionPlacement.palengke));
    expect(_asked, isNot(contains(ShopSectionPlacement.allItems)));
    expect(find.text('Fresh today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('asks the server for its two categories, not the capped page',
      (tester) async {
    await _pump(tester, [_p('1', 'Pechay Bundle', 'Fresh Produce')]);
    expect(_categoriesAsked, ['Fresh Produce,Meat & Seafood']);
  });

  testWidgets('stores selling fresh items on top, then the Palengke ad, then products',
      (tester) async {
    await _pump(tester, [_p('1', 'Pechay Bundle', 'Fresh Produce')]);
    expect(find.text('Stores'), findsOneWidget);
    expect(find.text('Mariton Fresh'), findsOneWidget);
    // A store with no fresh-market products is not a Palengke store.
    expect(find.text('Wilcon Depot'), findsNothing);
    final slot = find.byWidgetPredicate(
        (w) => w is FrontendOfficialAdSlot && w.slotId == 'frontend.palengke.top',
        skipOffstage: false);
    expect(slot, findsOneWidget);
    expect(tester.getTopLeft(slot).dy,
        greaterThan(tester.getTopLeft(find.text('Stores')).dy));
    expect(tester.getTopLeft(find.text('Pechay Bundle')).dy,
        greaterThan(tester.getTopLeft(slot).dy));
  });

  test('storesSelling keeps stores with at least one of the products, in order', () {
    final stores = {
      'featured': [_store('b', 'B')],
      'open': [_store('a', 'A'), _store('c', 'C')],
      'closed': <StoreData>[],
    };
    final products = [
      _p('1', 'x', 'Fresh Produce', vendor: 'a'),
      _p('2', 'y', 'Fresh Produce', vendor: 'b'),
    ];
    expect(storesSelling(stores, products).map((s) => s.id), ['b', 'a']);
  });
}
