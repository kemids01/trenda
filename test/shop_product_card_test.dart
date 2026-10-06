// test/shop_product_card_test.dart
// The card every home shelf is built from.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/shop_product_card.dart';
import 'package:trenda_shared/models/product_model.dart';

ProductModel _p({
  String name = 'Pandesal 10pcs',
  double price = 120,
  double? compareAt,
  int stock = 10,
  int lowStockThreshold = 5,
  int sales = 0,
  double rating = 0,
  int reviews = 0,
  String? storeName = 'Dubets Store',
  bool freeDelivery = false,
}) {
  return ProductModel(
    id: 'p1',
    name: name,
    slug: 'p1',
    vendorId: 'vendor-1',
    storeName: storeName,
    basePrice: price,
    compareAtPrice: compareAt,
    totalStock: stock,
    lowStockThreshold: lowStockThreshold,
    category: 'Bakery',
    sales: sales,
    averageRating: rating,
    totalReviews: reviews,
    freeDelivery: freeDelivery,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  Size size = const Size(360, 800),
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 158, child: card),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ShopProductCard', () {
    testWidgets('shows name, shelf price and the shop', (tester) async {
      await _pump(tester, ShopProductCard(product: _p(), onTap: () {}));

      expect(find.text('Pandesal 10pcs'), findsOneWidget);
      expect(find.textContaining('₱120'), findsOneWidget);
      expect(find.text('Dubets Store'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a discount shows the cut and what it was', (tester) async {
      await _pump(
        tester,
        ShopProductCard(
          product: _p(price: 75, compareAt: 100),
          onTap: () {},
        ),
      );

      expect(find.text('-25%'), findsOneWidget);
      expect(find.textContaining('₱100'), findsOneWidget);
    });

    testWidgets('no discount badge at full price', (tester) async {
      await _pump(tester, ShopProductCard(product: _p(), onTap: () {}));
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('sold out is stated over the photo', (tester) async {
      await _pump(
        tester,
        ShopProductCard(product: _p(stock: 0), onTap: () {}),
      );

      expect(find.text('SOLD OUT'), findsOneWidget);
      expect(find.textContaining('ONLY'), findsNothing);
    });

    testWidgets('low stock warns with the real count', (tester) async {
      await _pump(
        tester,
        ShopProductCard(product: _p(stock: 3), onTap: () {}),
      );

      expect(find.text('ONLY 3 LEFT'), findsOneWidget);
      expect(find.text('SOLD OUT'), findsNothing);
    });

    testWidgets('an unrated product says New listing, not a fake score',
        (tester) async {
      await _pump(tester, ShopProductCard(product: _p(), onTap: () {}));

      expect(find.text('New listing'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('a rated product shows its rating and units sold',
        (tester) async {
      await _pump(
        tester,
        ShopProductCard(
          product: _p(rating: 4.6, reviews: 12, sales: 30),
          onTap: () {},
        ),
      );

      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('30 sold'), findsOneWidget);
    });

    testWidgets('an unrated product that has sold shows the sales instead',
        (tester) async {
      await _pump(
        tester,
        ShopProductCard(product: _p(sales: 7), onTap: () {}),
      );

      expect(find.text('7 sold'), findsOneWidget);
      expect(find.text('New listing'), findsNothing);
    });

    testWidgets('free delivery is flagged', (tester) async {
      await _pump(
        tester,
        ShopProductCard(product: _p(freeDelivery: true), onTap: () {}),
      );

      expect(find.text('FREE DELIVERY'), findsOneWidget);
    });

    testWidgets('no shop row when the product carries no store name',
        (tester) async {
      await _pump(
        tester,
        ShopProductCard(product: _p(storeName: '  '), onTap: () {}),
      );

      expect(find.text('Dubets Store'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping opens the product', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        ShopProductCard(product: _p(), onTap: () => taps++),
      );

      await tester.tap(find.text('Pandesal 10pcs'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a long name, big price and long shop do not overflow',
        (tester) async {
      await _pump(
        tester,
        ShopProductCard(
          product: _p(
            name: 'Santissima Trinidad Premium Whole Wheat Pandesal Family Pack',
            price: 1234567,
            compareAt: 2345678,
            storeName: 'Santissima Trinidad General Merchandise and Hardware',
            rating: 4.85,
            reviews: 1284,
            sales: 99999,
          ),
          onTap: () {},
        ),
        size: const Size(320, 900),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('price under the name; rating and sold count under the price',
        (tester) async {
      await _pump(
        tester,
        ShopProductCard(
          product: _p(rating: 4.6, reviews: 12, sales: 30),
          onTap: () {},
        ),
      );

      final price = tester.getTopLeft(find.textContaining('₱120')).dy;
      expect(price, greaterThan(tester.getTopLeft(find.text('Pandesal 10pcs')).dy));
      expect(tester.getTopLeft(find.text('30 sold')).dy, greaterThan(price));
      expect(tester.getTopLeft(find.text('4.6')).dy, greaterThan(price));
    });

    testWidgets('store name sits on the photo, top-right', (tester) async {
      await _pump(tester, ShopProductCard(product: _p(), onTap: () {}));

      final card = tester.getRect(find.byType(ShopProductCard));
      final store = tester.getRect(find.text('Dubets Store'));
      // Inside the square photo (card width tall), in its upper-right half.
      expect(store.bottom, lessThan(card.top + card.width / 2));
      expect(store.right, greaterThan(card.left + card.width / 2));
    });

    testWidgets('New listing is a banner on the photo, lower-left',
        (tester) async {
      await _pump(tester, ShopProductCard(product: _p(), onTap: () {}));

      final card = tester.getRect(find.byType(ShopProductCard));
      final banner = tester.getRect(find.text('New listing'));
      expect(banner.top, greaterThan(card.top + card.width / 2));
      expect(banner.bottom, lessThan(card.top + card.width));
      expect(banner.left, lessThan(card.left + card.width / 2));
    });

    testWidgets('renders in dark mode', (tester) async {
      await _pump(
        tester,
        ShopProductCard(product: _p(), onTap: () {}),
        brightness: Brightness.dark,
      );

      expect(find.text('Pandesal 10pcs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
