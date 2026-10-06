// test/storefront_card_test.dart
// Renders the storefront cards at real phone widths to catch overflow and to
// pin what each state actually shows the customer.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/providers/stores_provider.dart';
import 'package:trenda_frontend/features/stores/widgets/storefront_card.dart';

StoreData _store({
  String name = 'Dubets Store',
  String category = 'Bakery',
  String municipality = 'Tuguegarao City',
  String? address = '12 Rizal St, Centro',
  String? logo,
  String? coverImage,
  double rating = 4.6,
  int reviewCount = 23,
  int productCount = 14,
  bool isOpen = true,
  String? nextOpenDay,
  String? nextOpenAt,
}) {
  return StoreData(
    id: 'vendor-1',
    name: name,
    description: 'Fresh pandesal every morning',
    logo: logo,
    coverImage: coverImage,
    category: category,
    rating: rating,
    reviewCount: reviewCount,
    productCount: productCount,
    isFeatured: false,
    municipality: municipality,
    address: address,
    storeStatus: StoreStatus(
      isOpen: isOpen,
      nextOpenDay: nextOpenDay,
      nextOpenAt: nextOpenAt,
    ),
  );
}

Future<void> _pumpCard(
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: card,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('open storefront shows its sign, stats and entry cue',
      (tester) async {
    await _pumpCard(
      tester,
      StorefrontCard(store: _store(), onTap: () {}),
    );

    expect(find.text('DUBETS STORE'), findsOneWidget);
    expect(find.text('OPEN'), findsOneWidget);
    expect(find.text('Bakery · Tuguegarao City'), findsOneWidget);
    expect(find.text('12 Rizal St, Centro'), findsOneWidget);
    expect(find.text('4.6'), findsOneWidget);
    expect(find.text('(23)'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('items'), findsOneWidget);
    expect(find.text('Step inside'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closed storefront hangs a CLOSED sign and a reopening time',
      (tester) async {
    await _pumpCard(
      tester,
      StorefrontCard(
        store: _store(
          isOpen: false,
          nextOpenDay: 'saturday',
          nextOpenAt: '08:00',
        ),
        isClosed: true,
        onTap: () {},
      ),
    );

    expect(find.text('CLOSED'), findsOneWidget);
    expect(find.text('OPEN'), findsNothing);
    expect(find.text('Opens Sat · 8:00 AM'), findsOneWidget);
    expect(find.text('Step inside'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closed with no schedule falls back to a browse hint',
      (tester) async {
    await _pumpCard(
      tester,
      StorefrontCard(
        store: _store(isOpen: false),
        isClosed: true,
        onTap: () {},
      ),
    );

    expect(find.text('Browse the shelves'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('featured storefront gets the brass plaque', (tester) async {
    await _pumpCard(
      tester,
      StorefrontCard(store: _store(), isFeatured: true, onTap: () {}),
    );

    expect(find.text('FEATURED SHOP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a store with no logo falls back to a painted monogram',
      (tester) async {
    await _pumpCard(
      tester,
      StorefrontCard(store: _store(name: 'Mang Juan Hardware'), onTap: () {}),
    );

    expect(find.text('MJ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the storefront opens the shop', (tester) async {
    var taps = 0;
    await _pumpCard(
      tester,
      StorefrontCard(store: _store(), onTap: () => taps++),
    );

    await tester.tap(find.text('DUBETS STORE'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('a long shop name on a narrow phone does not overflow',
      (tester) async {
    await _pumpCard(
      tester,
      StorefrontCard(
        store: _store(
          name: 'Santissima Trinidad General Merchandise and Hardware Supply',
          category: 'General Merchandise and Construction Supplies',
          address: 'Block 12 Lot 44, Barangay Ugac Sur, Tuguegarao City, '
              'Cagayan Valley, Region II',
          rating: 4.85,
          reviewCount: 1284,
          productCount: 1999,
        ),
        isFeatured: true,
        onTap: () {},
      ),
      size: const Size(320, 800),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('closed long-name card on a narrow phone does not overflow',
      (tester) async {
    await _pumpCard(
      tester,
      StorefrontCard(
        store: _store(
          name: 'Santissima Trinidad General Merchandise and Hardware Supply',
          isOpen: false,
          nextOpenDay: 'wednesday',
          nextOpenAt: '07:30',
        ),
        isClosed: true,
        onTap: () {},
      ),
      size: const Size(320, 800),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a store with no address, rating or reviews still renders',
      (tester) async {
    await _pumpCard(
      tester,
      StorefrontCard(
        store: _store(
          address: null,
          rating: 0,
          reviewCount: 0,
          productCount: 1,
        ),
        onTap: () {},
      ),
    );

    expect(find.text('New'), findsOneWidget);
    expect(find.text('item'), findsOneWidget);
    // Falls back to the shop's own blurb when there is no street address.
    expect(find.text('Fresh pandesal every morning'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders in dark mode', (tester) async {
    await _pumpCard(
      tester,
      StorefrontCard(store: _store(), onTap: () {}),
      brightness: Brightness.dark,
    );

    expect(find.text('DUBETS STORE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
