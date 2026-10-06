// test/vendor_store_scroll_test.dart
// The store page is ONE scroll: dragging on the products collapses the
// shopfront, the grid builds lazily, and a tab change starts the new tab at
// its top. It used to nest a second scroll view inside each tab, so the
// products scrolled on their own while the header stayed put.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/vendors/providers/vendor_category_provider.dart';
import 'package:trenda_frontend/features/vendors/providers/vendor_follow_provider.dart';
import 'package:trenda_frontend/features/vendors/screens/vendor_store_screen.dart';
import 'package:trenda_frontend/features/vendors/services/vendor_follow_service.dart';

class _FakeFollow implements VendorFollowService {
  @override
  Future<bool> isFollowing(String vendorId) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(false);
}

final _profile = VendorProfile(
  id: 'v1',
  storeName: 'Dubets Store',
  storeDescription: 'Fresh bread every morning. ' * 200,
  rating: 4.6,
  reviewCount: 12,
  productCount: 40,
  followerCount: 30,
  municipality: 'Tuguegarao City',
  address: 'Rizal St, Centro 10',
  category: 'Bakery',
);

final _products = List.generate(
  40,
  (i) => VendorProduct(
      id: 'p$i', name: 'Item $i', basePrice: 100 + i.toDouble(), stock: 5),
);

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      vendorProfileProvider('v1').overrideWith((ref) async => _profile),
      vendorProductsProvider('v1').overrideWith((ref) async => _products),
      vendorCategoriesProvider('v1').overrideWith((ref) async => const []),
      vendorFollowServiceProvider.overrideWithValue(_FakeFollow()),
    ],
    child: const MaterialApp(home: VendorStoreScreen(vendorId: 'v1')),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Iterable<ScrollableState> _verticalScrollables(WidgetTester tester) => tester
    .stateList<ScrollableState>(find.byType(Scrollable))
    .where((s) => s.axisDirection == AxisDirection.down);

// Only the Reviews tab says this ('4.6' is also on the stats card above).
final _reviewsSummary = find.textContaining('reviews across this shop');

void main() {
  testWidgets('one vertical scroll, and dragging the products moves the page',
      (tester) async {
    await _open(tester);
    expect(_verticalScrollables(tester), hasLength(1));

    final page = _verticalScrollables(tester).single.position;
    expect(page.pixels, 0);
    await tester.drag(find.text('Item 0'), const Offset(0, -300));
    await tester.pump();
    expect(page.pixels, greaterThan(250),
        reason: 'dragging the products must scroll the page (and so '
            'collapse the shopfront), not a separate inner list');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the product grid builds lazily', (tester) async {
    await _open(tester);
    expect(find.text('Item 0'), findsOneWidget);
    expect(find.text('Item 39', skipOffstage: false), findsNothing);

    await tester.scrollUntilVisible(find.text('Item 39'), 400,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Item 39'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tab change while deep in the shelves starts at its top',
      (tester) async {
    await _open(tester);
    await tester.drag(find.text('Item 0'), const Offset(0, -3000));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ABOUT'));
    await tester.pumpAndSettle();

    // About is long here (a long description), so without the scroll-back
    // the shopper would land deep inside it at the shelves' old depth. Its
    // heading must sit right under the pinned tab bar.
    final tabBottom = tester.getBottomLeft(find.text('ABOUT')).dy;
    final headingTop = tester.getTopLeft(find.text('ABOUT THIS SHOP')).dy;
    expect(headingTop, greaterThan(tabBottom));
    expect(headingTop, lessThan(tabBottom + 60));
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping left moves to the next tab', (tester) async {
    await _open(tester);
    await tester.fling(find.text('Item 0'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(_reviewsSummary, findsOneWidget);
    expect(find.text('Item 0'), findsNothing);
  });
}
