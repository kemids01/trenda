// The band reserves a fixed height under each card's photo. It was shrunk to
// fit the compact product card, so the tallest cards must still fit with no
// overflow, on a narrow and a wide phone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/shop_card_grid.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/shop_feature_band.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/shop_product_card.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/shop_store_card.dart';
import 'package:trenda_frontend/features/home/providers/shop_sections_provider.dart';

Map<String, dynamic> _product(String id) => {
      'id': id,
      'name': 'Santissima Trinidad Premium Whole Wheat Pandesal Family Pack',
      'slug': id,
      'vendorId': 'vendor-1',
      'storeName': 'Santissima Trinidad General Merchandise',
      'basePrice': 1234567,
      'compareAtPrice': 2345678,
      'totalStock': 3,
      'lowStockThreshold': 5,
      'category': 'Bakery',
      'sales': 99999,
      'averageRating': 4.85,
      'totalReviews': 1284,
      'freeDelivery': true,
    };

Map<String, dynamic> _store(String id) => {
      'id': id,
      'name': 'Santissima Trinidad General Merchandise and Hardware',
      'category': 'Food & Beverage',
      'rating': 4.5,
      'reviewCount': 20,
      'productCount': 33,
      'isFeatured': true,
      'municipality': 'Tuguegarao City',
      'storeStatus': {'isOpen': false},
    };

Future<void> _pump(WidgetTester tester, ShopSection section, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: ShopFeatureBand(section: section)),
    ),
  ));
  await tester.pump();
}

Future<void> _pumpGrid(
  WidgetTester tester,
  double width,
  ShopCardGridDelegate delegate,
  Widget Function(int) card,
) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid(
            gridDelegate: delegate,
            delegate: SliverChildBuilderDelegate(
              (_, i) => card(i),
              childCount: 4,
            ),
          ),
        ),
      ]),
    ),
  ));
  await tester.pump();
}

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('grid cells are photo width + the details block at $width',
        (tester) async {
      final product = ShopSection.fromJson({
        'title': 'x',
        'products': [_product('a')],
      }).products.first;
      await _pumpGrid(
        tester,
        width,
        const ShopCardGridDelegate(),
        (_) => ShopProductCard(product: product, onTap: () {}),
      );
      final cell = tester.getSize(find.byType(ShopProductCard).first);
      expect(cell.height, cell.width + kShopProductCardDetailsHeight);
      expect(tester.takeException(), isNull);
    });

    testWidgets('store grid cells fit the tallest store card at $width',
        (tester) async {
      final store = ShopSection.fromJson({
        'title': 'x',
        'contentType': 'stores',
        'products': [],
        'stores': [_store('a')],
      }).stores.first;
      await _pumpGrid(
        tester,
        width,
        const ShopCardGridDelegate(detailsHeight: kShopStoreCardDetailsHeight),
        (_) => ShopStoreCard(store: store, onTap: () {}),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tallest product cards fit the band at $width', (tester) async {
      final section = ShopSection.fromJson({
        'title': 'Store of the week!',
        'products': [_product('a'), _product('b'), _product('c')],
      });
      await _pump(tester, section, width);
      expect(find.byType(ShopProductCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tallest store cards fit the band at $width', (tester) async {
      final section = ShopSection.fromJson({
        'title': 'Top Shops',
        'contentType': 'stores',
        'products': [],
        'stores': [_store('a'), _store('b'), _store('c')],
      });
      await _pump(tester, section, width);
      expect(find.byType(ShopStoreCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
