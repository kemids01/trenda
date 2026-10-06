// The Official Store card and the Search / Products tab card after their
// polish pass: real ratings only, a sold-out state, price at the foot, and
// nothing hardcoded white that breaks dark mode.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trenda_frontend/features/home/presentation/products_tab.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/official_product_card.dart';
import 'package:trenda_frontend/features/wishlist/providers/wishlist_provider.dart';
import 'package:trenda_shared/models/product_model.dart';

ProductModel _p({
  String name = 'Pandesal 10pcs',
  double price = 120,
  double? compareAt,
  int stock = 10,
  double rating = 0,
  int reviews = 0,
  int sales = 0,
  bool freeDelivery = false,
}) =>
    ProductModel(
      id: 'p1',
      name: name,
      slug: 'p1',
      vendorId: 'vendor-1',
      basePrice: price,
      compareAtPrice: compareAt,
      totalStock: stock,
      lowStockThreshold: 5,
      category: 'Bakery',
      sales: sales,
      averageRating: rating,
      totalReviews: reviews,
      freeDelivery: freeDelivery,
    );

Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  Brightness brightness = Brightness.light,
  Size cell = const Size(170, 290),
}) async {
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
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(size: cell, child: card),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('OfficialProductCard', () {
    testWidgets('an unrated product says New, never 0.0 (0)', (tester) async {
      await _pump(tester, OfficialProductCard(product: _p()));
      expect(find.text('New'), findsOneWidget);
      expect(find.text('0.0'), findsNothing);
      expect(find.textContaining('(0)'), findsNothing);
      expect(find.text('OFFICIAL'), findsOneWidget);
    });

    testWidgets('a rated product shows its rating and units sold',
        (tester) async {
      await _pump(
          tester,
          OfficialProductCard(
              product: _p(rating: 4.6, reviews: 12, sales: 30)));
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('30 sold'), findsOneWidget);
      expect(find.text('New'), findsNothing);
    });

    testWidgets('the discount shows once, with the old price struck through',
        (tester) async {
      await _pump(
          tester, OfficialProductCard(product: _p(price: 75, compareAt: 100)));
      expect(find.text('-25%'), findsOneWidget);
      expect(find.textContaining('100'), findsOneWidget);
    });

    testWidgets('price sits below the name', (tester) async {
      await _pump(tester, OfficialProductCard(product: _p()));
      expect(
        tester.getTopLeft(find.textContaining('₱120')).dy,
        greaterThan(tester.getTopLeft(find.text('Pandesal 10pcs')).dy),
      );
    });

    testWidgets('sold out is stated over the photo', (tester) async {
      await _pump(tester, OfficialProductCard(product: _p(stock: 0)));
      expect(find.text('SOLD OUT'), findsOneWidget);
      expect(find.textContaining('left'), findsNothing);
    });

    // Real host sizes: the 0.62 grids (Hub, Official Store, collection) on a
    // narrow 320px phone, and the 170x280 rails (Hub carousels, related).
    for (final cell in const [Size(142, 229), Size(170, 280)]) {
      testWidgets('long content with every chip fits a ${cell.width}x'
          '${cell.height} cell, in dark mode', (tester) async {
        await _pump(
          tester,
          OfficialProductCard(
            product: _p(
              name: 'Santissima Trinidad Premium Whole Wheat Pandesal Family',
              price: 1234567,
              compareAt: 2345678,
              stock: 3,
              rating: 4.85,
              reviews: 1284,
              freeDelivery: true,
            ),
          ),
          brightness: Brightness.dark,
          cell: cell,
        );
        expect(find.text('FREE DELIVERY'), findsOneWidget);
        expect(find.text('Only 3 left'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  // The Trenda tab carousels show three compact cards per screen: width
  // (screen − 2×14 − 2×10) / 3, height width + kOfficialCompactDetailsHeight.
  group('OfficialProductCard compact (three per screen)', () {
    for (final screen in const [320.0, 360.0, 390.0, 412.0]) {
      final w = (screen - 28 - 20) / 3;
      testWidgets('worst-case content fits on a ${screen.toInt()}dp phone '
          '(${w.toStringAsFixed(0)}px card)', (tester) async {
        await _pump(
          tester,
          OfficialProductCard(
            compact: true,
            product: _p(
              name: 'Santissima Trinidad Premium Whole Wheat Pandesal Family',
              price: 1234567,
              compareAt: 2345678,
              stock: 3,
              rating: 4.85,
              reviews: 1284,
              freeDelivery: true,
            ),
          ),
          brightness: Brightness.dark,
          cell: Size(w, w + kOfficialCompactDetailsHeight),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the Official pill shrinks to its tick, clear of the discount badge',
        (tester) async {
      await _pump(
        tester,
        OfficialProductCard(compact: true, product: _p(price: 75, compareAt: 100)),
        cell: const Size(114, 206),
      );
      expect(find.text('OFFICIAL'), findsNothing);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(find.text('-25%'), findsOneWidget);
      final tick = tester.getRect(find.byIcon(Icons.verified_rounded));
      final badge = tester.getRect(find.text('-25%'));
      // The discount stacks under the tick (top-right is the store name).
      expect(badge.top, greaterThanOrEqualTo(tick.bottom));
      expect(tick.overlaps(badge), isFalse);
    });
  });

  group('ProductCard', () {
    testWidgets('an unrated product says New, never 0.0 (0)',
        (tester) async {
      await _pump(tester, ProductCard(product: _p()));
      expect(find.text('New'), findsOneWidget);
      expect(find.text('0 sold'), findsOneWidget);
      expect(find.text('0.0'), findsNothing);
      expect(find.textContaining('(0)'), findsNothing);
    });

    testWidgets('an unrated product that sold shows the sales',
        (tester) async {
      await _pump(tester, ProductCard(product: _p(sales: 7)));
      expect(find.text('7 sold'), findsOneWidget);
    });

    testWidgets('a rated product shows its rating and units sold',
        (tester) async {
      await _pump(
          tester, ProductCard(product: _p(rating: 4.2, reviews: 9, sales: 5)));
      expect(find.text('4.2'), findsOneWidget);
      expect(find.text('5 sold'), findsOneWidget);
    });

    testWidgets('no dead add-to-cart icon', (tester) async {
      await _pump(tester, ProductCard(product: _p()));
      expect(find.byIcon(Icons.add_shopping_cart), findsNothing);
    });

    testWidgets('struck-through old price only with a real discount',
        (tester) async {
      await _pump(tester, ProductCard(product: _p(price: 75, compareAt: 100)));
      expect(find.text('-25%'), findsOneWidget);
      expect(find.text('₱100.00'), findsOneWidget);
    });

    testWidgets('sold out is stated over the photo', (tester) async {
      await _pump(tester, ProductCard(product: _p(stock: 0)));
      expect(find.text('SOLD OUT'), findsOneWidget);
    });

    testWidgets('long content fits a search-grid cell, in dark mode',
        (tester) async {
      await _pump(
        tester,
        ProductCard(
          product: _p(
            name: 'Santissima Trinidad Premium Whole Wheat Pandesal Family',
            price: 1234567,
            compareAt: 2345678,
            rating: 4.85,
            reviews: 1284,
          ),
        ),
        brightness: Brightness.dark,
        // Search grid: 2 columns at 0.7 on a 360px phone.
        cell: const Size(162, 231),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
