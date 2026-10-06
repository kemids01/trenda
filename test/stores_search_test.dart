// test/stores_search_test.dart
// The Stores page bottom bar: search narrows the carousel, and the QR button
// opens a scanner that only follows STORE codes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/presentation/stores_tab.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/official_qr_scan.dart';
import 'package:trenda_frontend/features/home/providers/stores_provider.dart';
import 'package:trenda_frontend/features/stores/utils/store_carousel.dart';

StoreData _store(String name, {String category = 'Bakery', String? address}) =>
    StoreData(
      id: 'id-$name',
      name: name,
      category: category,
      rating: 0,
      reviewCount: 0,
      productCount: 1,
      isFeatured: false,
      municipality: 'Tuguegarao City',
      address: address,
      storeStatus: StoreStatus(isOpen: true),
    );

Future<void> _pump(WidgetTester tester, List<StoreData> open,
    {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      publicStoresProvider.overrideWith((ref) async => {'open': open}),
    ],
    child: MaterialApp(
      home: Scaffold(
          appBar: AppBar(title: const Text('Stores')), body: const StoresTab()),
    ),
  ));
  await tester.pump();
}

void main() {
  group('searchStores', () {
    final deck = [
      _store('Aling Nena Bakery'),
      _store('Kuya Ben Hardware', category: 'Hardware', address: 'Rizal St.'),
      _store('Rizal Sari-sari', category: 'Grocery'),
    ];

    test('blank query keeps the whole deck', () {
      expect(searchStores(deck, '   '), deck);
    });

    test('matches name, category or address, case-insensitive', () {
      expect(
          searchStores(deck, 'nena').map((s) => s.name), ['Aling Nena Bakery']);
      expect(searchStores(deck, 'HARDWARE').length, 1);
      expect(searchStores(deck, 'rizal').map((s) => s.name),
          ['Kuya Ben Hardware', 'Rizal Sari-sari']);
    });

    test('every word must match', () {
      expect(searchStores(deck, 'rizal grocery').map((s) => s.name),
          ['Rizal Sari-sari']);
      expect(searchStores(deck, 'nena hardware'), isEmpty);
    });
  });

  group('resolveStoreScan (store QR only)', () {
    test('a store code opens that store', () {
      final r = resolveStoreScan('trenda://store/abc123');
      expect(r.storeId, 'abc123');
      expect(r.message, isNull);
    });

    test('product, wholesale and supplier codes are refused', () {
      for (final raw in [
        'trenda://product/p1',
        'trenda://wholesale/w1',
        'trenda://supplier/s1',
        '0123456789abcdef01234567', // bare id = product shelf barcode
      ]) {
        final r = resolveStoreScan(raw);
        expect(r.storeId, isNull, reason: raw);
        expect(r.message, contains('not a store QR'), reason: raw);
      }
    });

    test('a foreign code is not a Trenda code', () {
      final r = resolveStoreScan('WIFI:S:home;T:WPA;P:secret;;');
      expect(r.storeId, isNull);
      expect(r.message, 'That is not a Trenda code');
    });
  });

  group('bottom bar', () {
    testWidgets('search + QR sit below the carousel', (tester) async {
      await _pump(tester, [_store('Nena Bakery')]);
      final search = find.widgetWithText(TextField, 'Search shops');
      expect(search, findsOneWidget);
      expect(find.byTooltip('Scan store QR'), findsOneWidget);
      expect(tester.getTopLeft(search).dy,
          greaterThan(tester.getBottomLeft(find.text('Visit store')).dy));
    });

    testWidgets('typing narrows the carousel; no match shows a notice',
        (tester) async {
      await _pump(tester, [_store('Nena Bakery'), _store('Ben Hardware')]);
      expect(find.text('1 / 2'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hardware');
      await tester.pump();
      expect(find.text('Ben Hardware'), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No shop matches “zzz”'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('a small phone with the keyboard up does not overflow',
        (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await _pump(tester, [_store('A very long bakery name that wraps twice')],
          size: const Size(360, 640));
      expect(tester.takeException(), isNull);
    });
  });
}
