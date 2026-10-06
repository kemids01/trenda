// Searching the Official Store tab from the dock: the results must be what is
// on screen. The hero, the top ad and the collection carousels are not
// filtered by the query, so while a search is active they step aside and the
// matching products sit at the top.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trenda_frontend/features/home/presentation/trenda_hub_tab.dart';
import 'package:trenda_frontend/features/home/providers/official_collections_provider.dart';
import 'package:trenda_frontend/features/home/providers/official_store_provider.dart';
import 'package:trenda_shared/models/product_model.dart';

ProductModel _p(String id, String name, {String category = 'Groceries'}) =>
    ProductModel(
      id: id,
      name: name,
      slug: id,
      vendorId: 'official-trenda-store',
      basePrice: 100,
      totalStock: 10,
      category: category,
    );

final _products = [
  _p('1', 'Jasmine Rice 5kg'),
  _p('2', 'Coca-Cola 1.5L', category: 'Beverages'),
  _p('3', 'Dove Soap Bar', category: 'Personal Care'),
];

Future<ProviderContainer> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    officialStoreProductsProvider.overrideWith((ref) async => _products),
    officialStoreCollectionsProvider.overrideWith((ref) async => [
          StoreCollection(
              id: 'c1', title: 'Best Sellers', type: 'manual', products: _products),
          StoreCollection(
              id: 'c2', title: 'New Arrivals', type: 'manual', products: _products),
        ]),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: Scaffold(body: TrendaHubTab())),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}

Future<void> _search(
    WidgetTester tester, ProviderContainer c, String query) async {
  c.read(officialHubSearchProvider.notifier).state = query;
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('a search shows only the matches, on screen', (tester) async {
    final c = await _pump(tester);
    expect(find.text('Best Sellers'), findsOneWidget);

    await _search(tester, c, 'rice');

    expect(find.text('Jasmine Rice 5kg'), findsOneWidget);
    expect(find.text('Coca-Cola 1.5L'), findsNothing);
    expect(find.text('Dove Soap Bar'), findsNothing);
    // The unfiltered carousels step aside while searching.
    expect(find.text('Best Sellers', skipOffstage: false), findsNothing);
    expect(find.text('1 product'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no match says so on screen', (tester) async {
    final c = await _pump(tester);
    await _search(tester, c, 'laptop');
    expect(find.text('Jasmine Rice 5kg'), findsNothing);
    expect(find.text('0 products'), findsOneWidget);
  });

  testWidgets('clearing the search brings the collections back',
      (tester) async {
    final c = await _pump(tester);
    await _search(tester, c, 'rice');
    await _search(tester, c, '');
    expect(find.text('Best Sellers'), findsOneWidget);
  });

  testWidgets('a search from a scrolled page lands on the results',
      (tester) async {
    final c = await _pump(tester);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 300));
    await _search(tester, c, 'soap');
    expect(find.text('Dove Soap Bar'), findsOneWidget);
  });
}
