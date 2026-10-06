// The Food tab, top to bottom: the Official ads slot, the admin's Food
// carousels, then every in-stock Restaurant Food product with subcategory chips.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_shared/models/product_model.dart';
import 'package:trenda_frontend/features/core/widgets/frontend_official_ad_slot.dart';
import 'package:trenda_frontend/features/home/presentation/food_tab.dart';
import 'package:trenda_frontend/features/home/providers/shop_sections_provider.dart';
import 'package:trenda_frontend/features/products/providers/products_provider.dart';

ProductModel _p(String id, String name,
        {String category = 'Restaurant Food', String? sub}) =>
    ProductModel.fromJson({
      '_id': id,
      'id': id,
      'name': name,
      'category': category,
      if (sub != null) 'subcategory': sub,
      'basePrice': 120,
      'totalStock': 5,
      'status': 'active',
    });

Future<void> _pump(WidgetTester tester, List<ProductModel> products,
    {List<ShopSection> bands = const []}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      categoryProductsProvider.overrideWith((ref, categories) async => products),
      shopSectionsForPlacementProvider
          .overrideWith((ref, placement) async => bands),
    ],
    child: const MaterialApp(home: Scaffold(body: FoodTab())),
  ));
  // pump, not pumpAndSettle: the ad slot keeps a timer alive.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('shows the Food ad slot, the bands and only restaurant food',
      (tester) async {
    await _pump(
      tester,
      [
        _p('1', 'Chicken Adobo', sub: 'Meals'),
        _p('2', 'Iced Coffee', sub: 'Drinks'),
        _p('3', 'Rice 5kg', category: 'Food & Beverages'),
      ],
      bands: const [
        ShopSection(id: 'b', title: 'Restaurants near you', products: []),
      ],
    );

    expect(
      // skipOffstage: false — the slot is flush (no padding), so it must be
      // found whatever height its empty state has.
      find.byWidgetPredicate(
          (w) => w is FrontendOfficialAdSlot && w.slotId == 'frontend.food.top',
          skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Restaurants near you'), findsOneWidget);
    expect(find.text('All restaurant food'), findsOneWidget);
    expect(find.text('Chicken Adobo'), findsOneWidget);
    expect(find.text('Iced Coffee'), findsOneWidget);
    expect(find.text('Rice 5kg'), findsNothing);
  });

  testWidgets('with no ad showing, the greeting keeps its gap', (tester) async {
    await _pump(tester, [_p('1', 'Chicken Adobo')]);
    final slot = find.byWidgetPredicate(
        (w) => w is FrontendOfficialAdSlot && w.slotId == kFoodTabAdSlotId);
    // Widget tests block HTTP, so the slot has no ad: it draws the spacer,
    // directly under the greeting.
    expect(tester.getSize(slot).height, kFoodGreetingGap);
    expect(
      tester.getTopLeft(slot).dy,
      tester.getBottomLeft(find.byType(Row).first).dy,
    );
  });

  testWidgets('a subcategory chip narrows the grid', (tester) async {
    await _pump(tester, [
      _p('1', 'Chicken Adobo', sub: 'Meals'),
      _p('2', 'Iced Coffee', sub: 'Drinks'),
    ]);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Drinks'));
    await tester.pump();

    expect(find.text('Iced Coffee'), findsOneWidget);
    expect(find.text('Chicken Adobo'), findsNothing);
  });

  testWidgets('no restaurant food yet says so', (tester) async {
    await _pump(tester, [_p('3', 'Rice 5kg', category: 'Food & Beverages')]);
    expect(find.text('No restaurant food here yet'), findsOneWidget);
  });
}
