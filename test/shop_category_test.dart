// The Shop tab's category buttons and the category pages they open: stores in
// the category, an Official ad slot under them, then the products with chips.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/core/widgets/frontend_official_ad_slot.dart';
import 'package:trenda_frontend/features/home/presentation/shop_category_page.dart';
import 'package:trenda_frontend/features/home/providers/shop_category_provider.dart';
import 'package:trenda_frontend/features/home/providers/stores_provider.dart';
import 'package:trenda_frontend/features/home/utils/shop_category_filters.dart';
import 'package:trenda_frontend/features/home/utils/shop_category_lanes.dart';
import 'package:trenda_shared/models/ad_placement.dart';
import 'package:trenda_shared/models/product_model.dart';

StoreData _store(String id, String name, {String? group, List<String> subs = const []}) =>
    StoreData.fromJson({
      'id': id,
      'name': name,
      'category': '',
      'rating': 4.5,
      'reviewCount': 3,
      'productCount': 20,
      'isFeatured': false,
      'municipality': 'Tuguegarao City',
      'storeStatus': {'isOpen': true},
      if (group != null) 'storeCategory': {'group': group, 'subcategories': subs},
    });

ProductModel _p(String id, String name, {String sub = 'Vitamins', double? was}) =>
    ProductModel(
      id: id,
      name: name,
      slug: id,
      vendorId: 'v1',
      basePrice: 100,
      compareAtPrice: was,
      totalStock: 10,
      category: 'Health',
      subcategory: sub,
    );

void main() {
  group('Shop tab buttons', () {
    test('the five lanes, then one per category page, in tree order', () {
      final lanes = shopLanes();
      expect(lanes, hasLength(5 + kShopCategoryPages.length));
      expect(lanes.take(5).map((l) => l.label),
          ['All items', 'On sale', 'Shops', 'Palengke', 'Services']);
      expect(lanes.skip(5).map((l) => l.route),
          kShopCategoryPages.map((p) => '/shop-category/${p.key}'));
    });

    test('every category has its own label, icon and colour', () {
      final labels = shopLanes().skip(5).map((l) => l.label).toSet();
      expect(labels, hasLength(kShopCategoryPages.length));
    });
  });

  group('storesInCategory', () {
    test('primary group or a secondary subcategory in it; each store once', () {
      final pharm = _store('a', 'Mercury Drug', group: 'pharmacy-health');
      final mixed = _store('b', 'Mixed', group: 'home-living', subs: ['pharmacy-health.vitamins']);
      final other = _store('c', 'Wilcon', group: 'hardware-construction');
      final stores = storesInCategory({
        'featured': [pharm],
        'open': [pharm, mixed, other],
        'closed': [],
      }, 'pharmacy-health');
      expect(stores.map((s) => s.name), ['Mercury Drug', 'Mixed']);
    });
  });

  group('category chips', () {
    final products = [
      _p('1', 'A', sub: 'Vitamins', was: 150),
      _p('2', 'B', sub: 'Vitamins'),
      _p('3', 'C', sub: 'Medical supplies'),
    ];
    test('All, On sale, then subcategories by count', () {
      expect(categoryChips(products), ['All', 'On sale', 'Vitamins', 'Medical supplies']);
    });
    test('no On sale chip when nothing is on sale', () {
      expect(categoryChips([_p('2', 'B')]), ['All', 'Vitamins']);
    });
    test('each chip shows its products', () {
      expect(filterByCategoryChip(products, 'On sale').map((p) => p.id), ['1']);
      expect(filterByCategoryChip(products, 'Medical supplies').map((p) => p.id), ['3']);
      expect(filterByCategoryChip(products, 'All'), hasLength(3));
    });
  });

  group('ShopCategoryPage', () {
    Future<void> pump(WidgetTester tester, {List<ProductModel>? products}) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          publicStoresProvider.overrideWith((ref) async => {
                'featured': <StoreData>[],
                'open': [
                  _store('a', 'Mercury Drug', group: 'pharmacy-health'),
                  _store('c', 'Wilcon Depot', group: 'hardware-construction'),
                ],
                'closed': <StoreData>[],
              }),
          shopCategoryProductsProvider.overrideWith((ref, group) async =>
              products ??
              [
                _p('1', 'Enervon', was: 300),
                _p('2', 'Thermometer', sub: 'Medical supplies'),
              ]),
        ],
        child: const MaterialApp(
          home: ShopCategoryPage(groupKey: 'pharmacy-health'),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('stores on top, the Official ad under them, then products',
        (tester) async {
      await pump(tester);
      expect(find.text('Pharmacy & Health'), findsOneWidget);
      expect(find.text('Mercury Drug'), findsOneWidget);
      expect(find.text('Wilcon Depot'), findsNothing);

      final slot = find.byWidgetPredicate(
          (w) =>
              w is FrontendOfficialAdSlot &&
              w.slotId == 'frontend.shop_category.pharmacy-health',
          skipOffstage: false);
      expect(slot, findsOneWidget);
      expect(adSlotById('frontend.shop_category.pharmacy-health'), isNotNull);

      final storesY = tester.getTopLeft(find.text('Stores')).dy;
      final adY = tester.getTopLeft(slot).dy;
      final productsY = tester.getTopLeft(find.text('Products')).dy;
      expect(adY, greaterThan(storesY));
      expect(productsY, greaterThan(adY));
      expect(find.text('Enervon'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the On sale chip narrows the grid', (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'On sale'));
      await tester.pump();
      expect(find.text('Enervon'), findsOneWidget);
      expect(find.text('Thermometer'), findsNothing);
    });

    testWidgets('an empty category says so', (tester) async {
      await pump(tester, products: const []);
      expect(find.text('No Pharmacy & Health products yet.'), findsOneWidget);
    });
  });
}
