import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trenda_frontend/features/cart/data/cart_repository.dart';
import 'package:trenda_frontend/features/cart/models/cart_model.dart';
import 'package:trenda_frontend/features/cart/providers/cart_provider.dart';
import 'package:trenda_frontend/features/core/router/app_router.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/shop_dock.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/shop_product_card.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/shop_store_card.dart';
import 'package:trenda_frontend/features/search/presentation/search_page.dart';
import 'package:trenda_frontend/features/search/providers/search_everything_provider.dart';

final _result = SearchEverythingResult.fromJson({
  'products': {
    'items': [
      {'_id': 'p1', 'name': 'Rice Cooker', 'basePrice': 900, 'totalStock': 3, 'images': []},
      {'_id': 'p2', 'name': 'Brown Rice 5kg', 'basePrice': 300, 'totalStock': 9, 'images': []},
    ],
    'total': 2,
  },
  'stores': {
    'items': [
      {'id': 's1', 'name': 'Rice Hub', 'category': 'Grocery'},
    ],
    'total': 1,
  },
  'ads': {
    'vendor': [
      {'_id': 'a1', 'title': 'Rice Promo', 'businessName': 'Rice Hub', 'photos': []},
    ],
    'official': [
      {'id': 'o1', 'title': 'Trenda Rice Week', 'image': '', 'badgeText': 'Trenda Official'},
    ],
    'total': 2,
  },
});

class _CartRepo implements CartRepository {
  @override
  Future<CartModel> getCart() async => CartModel.empty();
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

Future<List<SearchRequest>> _pumpPage(
  WidgetTester t, {
  SearchScope scope = SearchScope.all,
  SearchEverythingResult Function(SearchRequest)? answer,
}) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
  final requests = <SearchRequest>[];
  await t.pumpWidget(ProviderScope(
    overrides: [
      searchEverythingProvider.overrideWith((ref, req) async {
        requests.add(req);
        return (answer ?? (_) => _result)(req);
      }),
    ],
    child: MaterialApp(home: SearchPage(initialScope: scope)),
  ));
  await t.pump();
  return requests;
}

Future<void> _type(WidgetTester t, String text) async {
  await t.enterText(find.byKey(const ValueKey('search-field')), text);
  await t.pump(const Duration(milliseconds: 350)); // past the debounce
  await t.pump(const Duration(milliseconds: 600)); // the reveal animations
}

void main() {
  testWidgets('before typing: the market aisles; nothing is searched', (t) async {
    final requests = await _pumpPage(t);
    expect(find.text('Browse the market'), findsOneWidget);
    expect(find.text('Electronics'), findsOneWidget);
    expect(requests.where((r) => r.isSearchable), isEmpty);
  });

  testWidgets('results show stores, products (new card) and ads with counts', (t) async {
    await _pumpPage(t);
    await _type(t, 'rice');
    expect(find.byType(ShopStoreCard), findsOneWidget);
    expect(find.byType(ShopProductCard), findsNWidgets(2));
    expect(find.text('Rice Promo'), findsOneWidget);
    expect(find.byKey(const ValueKey('search-tab-products')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('search-tab-products')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('search-products')), findsOneWidget);
    expect(find.byType(ShopStoreCard), findsNothing);
  });

  testWidgets('one search per pause in typing, not per keystroke', (t) async {
    final requests = await _pumpPage(t);
    await t.enterText(find.byKey(const ValueKey('search-field')), 'ri');
    await t.pump(const Duration(milliseconds: 100));
    await t.enterText(find.byKey(const ValueKey('search-field')), 'ric');
    await t.pump(const Duration(milliseconds: 100));
    await _type(t, 'rice');
    expect(requests.where((r) => r.isSearchable).map((r) => r.query).toSet(), {'rice'});
  });

  testWidgets('Trenda opens on Official: scope sent, Official Store tile shown', (t) async {
    final requests = await _pumpPage(t, scope: SearchScope.official);
    await _type(t, 'rice');
    expect(requests.last.scope, SearchScope.official);
    expect(find.text('Official Trenda Store'), findsOneWidget);
  });

  testWidgets('nothing in a narrowed scope offers the whole market', (t) async {
    final requests = await _pumpPage(t,
        scope: SearchScope.food,
        answer: (r) => r.scope == SearchScope.food ? SearchEverythingResult.empty : _result);
    await _type(t, 'rice');
    expect(find.text('Search everything'), findsOneWidget);
    await t.tap(find.text('Search everything'));
    await t.pump(); // the request goes out
    await t.pump(const Duration(milliseconds: 600)); // its answer is drawn
    expect(requests.last.scope, SearchScope.all);
    expect(find.byType(ShopProductCard), findsNWidgets(2));
  });

  test('price sort breaks ties on id; relevance keeps server order', () {
    final p = _result.products;
    expect(sortSearchProducts(p, SearchProductSort.priceLow).map((e) => e.id), ['p2', 'p1']);
    expect(sortSearchProducts(p, SearchProductSort.priceHigh).map((e) => e.id), ['p1', 'p2']);
    expect(sortSearchProducts(p, SearchProductSort.relevance).map((e) => e.id), ['p1', 'p2']);
  });

  for (final (mode, scope) in [
    (ShopDockMode.shop, SearchScope.all),
    (ShopDockMode.trenda, SearchScope.official),
    (ShopDockMode.food, SearchScope.food),
  ]) {
    testWidgets('the ${mode.name} dock opens search in the ${scope.param} scope', (t) async {
      SharedPreferences.setMockInitialValues({});
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => Scaffold(bottomNavigationBar: ShopDock(mode: mode))),
        GoRoute(
          path: Routes.search,
          builder: (_, state) => SearchPage(
            initialScope: SearchScope.fromParam((state.extra as Map?)?['scope']),
          ),
        ),
      ]);
      await t.pumpWidget(ProviderScope(
        overrides: [cartProvider.overrideWith((ref) => CartNotifier(_CartRepo()))],
        child: MaterialApp.router(routerConfig: router),
      ));
      await t.pump();
      await t.tap(find.text(mode.hint));
      await t.pumpAndSettle();
      final page = t.widget<SearchPage>(find.byType(SearchPage));
      expect(page.initialScope, scope);
    });
  }
}
