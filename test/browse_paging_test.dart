// "All items" / "On sale" page from the server (GET /api/products/browse):
// scrolling loads the next page, a chip / sort / shuffle starts a new query,
// and the footer says when everything is in.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/providers/shop_sections_provider.dart';
import 'package:trenda_frontend/features/products/presentation/product_browse_page.dart';
import 'package:trenda_frontend/features/products/providers/browse_paging_provider.dart';
import 'package:trenda_frontend/features/products/providers/products_provider.dart';
import 'package:trenda_frontend/features/products/utils/catalogue_browse.dart';
import 'package:trenda_shared/data/products_repository.dart';
import 'package:trenda_shared/models/product_model.dart';

class _Call {
  _Call(this.page, this.onSale, this.category, this.sort, this.seed);
  final int page;
  final bool onSale;
  final String? category;
  final String sort;
  final int seed;
}

/// 90 products, served [limit] at a time like the endpoint.
class _FakeRepo extends ProductsRepository {
  _FakeRepo() : super(baseUrl: 'http://test');
  final calls = <_Call>[];

  @override
  Future<BrowsePageResult> fetchBrowseProducts({
    int page = 1,
    int limit = 40,
    String? municipality,
    bool onSale = false,
    String? category,
    String sort = 'shuffle',
    int seed = 0,
  }) async {
    calls.add(_Call(page, onSale, category, sort, seed));
    const total = 90;
    final start = (page - 1) * limit;
    final end = (start + limit).clamp(0, total);
    return BrowsePageResult(
      products: [
        for (var i = start; i < end; i++)
          ProductModel.fromJson({
            '_id': 'p$i',
            'id': 'p$i',
            'name': 'Item $i',
            'basePrice': 100,
            'totalStock': 5,
            'category': 'Fashion',
          }),
      ],
      total: total,
      page: page,
      totalPages: (total / limit).ceil(),
      categories: page == 1
          ? const [BrowseCategoryCount('Fashion', 60), BrowseCategoryCount('Electronics', 30)]
          : const [],
    );
  }
}

Future<_FakeRepo> _pump(WidgetTester tester, BrowseMode mode) async {
  final repo = _FakeRepo();
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      productsRepositoryProvider.overrideWithValue(repo),
      shopSectionsForPlacementProvider.overrideWith((ref, placement) async => const []),
    ],
    child: MaterialApp(home: ProductBrowsePage(mode: mode)),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return repo;
}

Future<void> _scrollToEnd(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('All items: page 1 first, the rest as you scroll, then the end',
      (tester) async {
    final repo = await _pump(tester, BrowseMode.allItems);
    expect(repo.calls.map((c) => c.page), [1]);
    expect(repo.calls.first.onSale, isFalse);
    expect(repo.calls.first.sort, 'shuffle');
    expect(find.text('90 items'), findsOneWidget); // the server total, not page size

    await _scrollToEnd(tester);
    expect(repo.calls.map((c) => c.page), [1, 2, 3]);
    expect(find.text("That's all 90 items"), findsOneWidget);
  });

  testWidgets('chips come from the server; a chip asks for that category',
      (tester) async {
    final repo = await _pump(tester, BrowseMode.allItems);
    expect(find.widgetWithText(ChoiceChip, 'Electronics'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Electronics'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(repo.calls.last.category, 'Electronics');
    expect(repo.calls.last.page, 1);
    // The chip row stays while the new category loads and after.
    expect(find.widgetWithText(ChoiceChip, 'Fashion'), findsOneWidget);
  });

  testWidgets('On sale asks for sale items, biggest discount first', (tester) async {
    final repo = await _pump(tester, BrowseMode.onSale);
    expect(repo.calls.first.onSale, isTrue);
    expect(repo.calls.first.sort, 'discount');
  });

  testWidgets('Shuffle starts again with a new seed', (tester) async {
    final repo = await _pump(tester, BrowseMode.allItems);
    final firstSeed = repo.calls.first.seed;
    await tester.tap(find.byTooltip('Shuffle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(repo.calls.last.page, 1);
    expect(repo.calls.last.seed, isNot(firstSeed));
  });

  test('every BrowseSort has a server key', () {
    expect(BrowseSort.values.map(browseSortParam).toSet(),
        {'shuffle', 'newest', 'priceLow', 'priceHigh', 'popular', 'discount'});
  });
}
