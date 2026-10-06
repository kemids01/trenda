// Every product card names its store over the top-right corner of the photo
// (the shared StoreNameCorner), the way the Shop tab card always did.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trenda_frontend/features/home/presentation/products_tab.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/official_product_card.dart';
import 'package:trenda_frontend/features/products/widgets/product_card_parts.dart';
import 'package:trenda_frontend/features/wishlist/providers/wishlist_provider.dart';
import 'package:trenda_shared/models/product_model.dart';

ProductModel _p({String? storeName = 'Dubets Store', int discountFrom = 0}) =>
    ProductModel(
      id: 'p1',
      name: 'Pandesal 10pcs',
      slug: 'p1',
      vendorId: 'vendor-1',
      basePrice: 120,
      compareAtPrice: discountFrom > 0 ? discountFrom.toDouble() : null,
      totalStock: 10,
      lowStockThreshold: 5,
      category: 'Bakery',
      storeName: storeName,
    );

Future<void> _pump(WidgetTester tester, Widget card) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isProductInWishlistProvider.overrideWith((ref, id) => false),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 170, height: 290, child: card),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The name sits on the photo (upper half of the card) and in its right half.
void _expectTopRight(WidgetTester tester, Finder card, String name) {
  final c = tester.getRect(card);
  final store = tester.getRect(find.text(name));
  expect(store.bottom, lessThan(c.top + c.height / 2));
  expect(store.right, greaterThan(c.left + c.width / 2));
}

void main() {
  testWidgets('StoreNameCorner draws nothing for a blank name', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SizedBox(
        width: 100,
        height: 100,
        child: Stack(children: [StoreNameCorner(storeName: '  ', house: Colors.red)]),
      ),
    ));
    expect(find.byType(StoreNameChip), findsNothing);
  });

  testWidgets('Search / Products card names the store top-right',
      (tester) async {
    await _pump(tester, ProductCard(product: _p()));
    _expectTopRight(tester, find.byType(ProductCard), 'Dubets Store');
  });

  testWidgets('Search / Products card keeps the wishlist heart, at the bottom',
      (tester) async {
    await _pump(tester, ProductCard(product: _p()));
    final heart = tester.getRect(find.byType(WishlistButton));
    final store = tester.getRect(find.text('Dubets Store'));
    expect(heart.top, greaterThan(store.bottom));
  });

  testWidgets('Official card names the store top-right, discount moves left',
      (tester) async {
    await _pump(
        tester, OfficialProductCard(product: _p(discountFrom: 150)));
    _expectTopRight(tester, find.byType(OfficialProductCard), 'Dubets Store');
    final card = tester.getRect(find.byType(OfficialProductCard));
    expect(tester.getRect(find.text('-20%')).left,
        lessThan(card.left + card.width / 2));
  });

  testWidgets('Official card with no store name says Official Trenda Store',
      (tester) async {
    await _pump(tester, OfficialProductCard(product: _p(storeName: null)));
    _expectTopRight(
        tester, find.byType(OfficialProductCard), 'Official Trenda Store');
  });
}
