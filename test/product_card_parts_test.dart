// Every product card shows its price in one green and, under the price, the
// star rating and units sold (product_card_parts.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trenda_frontend/features/home/presentation/products_tab.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/official_product_card.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/shop_product_card.dart';
import 'package:trenda_frontend/features/products/widgets/product_card_parts.dart';
import 'package:trenda_frontend/features/wishlist/providers/wishlist_provider.dart';
import 'package:trenda_shared/models/product_model.dart';

ProductModel _p({double rating = 0, int reviews = 0, int sales = 0}) =>
    ProductModel(
      id: 'p1',
      name: 'Pandesal 10pcs',
      slug: 'p1',
      vendorId: 'vendor-1',
      basePrice: 120,
      totalStock: 10,
      category: 'Bakery',
      averageRating: rating,
      totalReviews: reviews,
      sales: sales,
    );

Future<void> _pump(WidgetTester tester, Widget child,
    {Brightness brightness = Brightness.light}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(ProviderScope(
    overrides: [
      isProductInWishlistProvider.overrideWith((ref, id) => false),
    ],
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 170, height: 300, child: child),
        ),
      ),
    ),
  ));
  await tester.pump();
}

/// The colour the price text is drawn in (plain Text or the Text.rich span).
Color? _priceColor(WidgetTester tester) {
  final w = tester.widget(find.textContaining('₱120').first);
  if (w is RichText) return w.text.style?.color;
  if (w is Text) return w.style?.color ?? w.textSpan?.style?.color;
  return null;
}

void main() {
  group('RatingSoldRow', () {
    testWidgets('a rated product shows its score and sold count',
        (tester) async {
      await _pump(tester,
          const RatingSoldRow(rating: 4.62, reviews: 12, sold: 30));
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('30 sold'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('an unrated product says New with an empty star, never 0.0',
        (tester) async {
      await _pump(tester, const RatingSoldRow(rating: 0, reviews: 0, sold: 0));
      expect(find.text('New'), findsOneWidget);
      expect(find.text('0 sold'), findsOneWidget);
      expect(find.text('0.0'), findsNothing);
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    });
  });

  group('price is green, rating and sold sit under it', () {
    final cards = <String, Widget Function(ProductModel)>{
      'ShopProductCard': (p) => ShopProductCard(product: p, onTap: () {}),
      'OfficialProductCard': (p) => OfficialProductCard(product: p),
      'ProductCard': (p) => ProductCard(product: p),
    };

    for (final entry in cards.entries) {
      for (final b in Brightness.values) {
        testWidgets('${entry.key} (${b.name})', (tester) async {
          await _pump(tester,
              entry.value(_p(rating: 4.5, reviews: 3, sales: 8)),
              brightness: b);
          expect(_priceColor(tester),
              b == Brightness.dark ? kPriceGreenDark : kPriceGreen);
          final priceY = tester.getTopLeft(find.textContaining('₱120').first).dy;
          expect(tester.getTopLeft(find.text('8 sold')).dy, greaterThan(priceY));
          expect(tester.getTopLeft(find.text('4.5')).dy, greaterThan(priceY));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
