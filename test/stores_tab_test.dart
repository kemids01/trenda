// test/stores_tab_test.dart
// The Stores page: one semi-full-screen carousel ordered featured → open →
// closed, chips that narrow it, and the storeStatus payload the cards read
// their OPEN/CLOSED badges from.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/presentation/stores_tab.dart';
import 'package:trenda_frontend/features/home/providers/stores_provider.dart';
import 'package:trenda_frontend/features/stores/utils/store_carousel.dart';

StoreData _store(String name,
        {bool isOpen = true, bool featured = false, String? day, String? at}) =>
    StoreData(
      id: 'id-$name',
      name: name,
      description: '$name sells fresh things every day.',
      category: 'Bakery',
      rating: 4.2,
      reviewCount: 3,
      productCount: 9,
      isFeatured: featured,
      municipality: 'Tuguegarao City',
      address: 'Rizal St.',
      storeStatus: StoreStatus(isOpen: isOpen, nextOpenDay: day, nextOpenAt: at),
    );

Future<void> _pumpTab(
  WidgetTester tester,
  Map<String, List<StoreData>> data,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        publicStoresProvider.overrideWith((ref) async => data),
      ],
      child: const MaterialApp(home: Scaffold(body: StoresTab())),
    ),
  );
  await tester.pump();
}

void main() {
  group('carousel deck', () {
    test('featured first, then open, then closed — each shop once', () {
      final a = _store('A', featured: true);
      final b = _store('B');
      final c = _store('C', isOpen: false);
      final deck = carouselDeck(featured: [a], open: [b, a], closed: [c]);
      expect(deck.map((s) => s.name), ['A', 'B', 'C']);
    });

    test('Open now reads the shop status, not its bucket', () {
      final deck = [
        _store('Flagship', featured: true, isOpen: false),
        _store('Bakeshop'),
      ];
      expect(filterStores(deck, StoreFilter.open).map((s) => s.name),
          ['Bakeshop']);
      expect(filterStores(deck, StoreFilter.featured).map((s) => s.name),
          ['Flagship']);
    });

    test('hours line', () {
      expect(storeHoursLabel(_store('A')), 'Open now');
      expect(storeHoursLabel(_store('B', isOpen: false, day: 'saturday', at: '08:00')),
          'Opens Sat · 8:00 AM');
      expect(storeHoursLabel(_store('C', isOpen: false)), 'Closed');
    });
  });

  group('StoresTab', () {
    testWidgets('shows the count, the open pill and the first shop in full',
        (tester) async {
      await _pumpTab(tester, {
        'featured': [_store('Aling Nena', featured: true)],
        'open': [_store('Bakeshop')],
        'closed': [_store('Hardware', isOpen: false)],
      });

      expect(find.text('3 shops'), findsOneWidget);
      expect(find.text('2 open'), findsOneWidget);
      expect(find.text('Aling Nena'), findsOneWidget);
      expect(find.text('FEATURED'), findsWidgets);
      expect(find.text('Visit store'), findsWidgets);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('swiping moves to the next shop', (tester) async {
      await _pumpTab(tester, {
        'open': [_store('Bakeshop'), _store('Sari-sari')],
      });
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('swiping past the last shop loops to the first',
        (tester) async {
      await _pumpTab(tester, {
        'open': [_store('Bakeshop'), _store('Sari-sari')],
      });
      for (var i = 0; i < 2; i++) {
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
      }
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('swiping back from the first shop shows the last',
        (tester) async {
      await _pumpTab(tester, {
        'open': [_store('Bakeshop'), _store('Sari-sari'), _store('Carinderia')],
      });
      await tester.drag(find.byType(PageView), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('changing the filter restarts on the first shop',
        (tester) async {
      await _pumpTab(tester, {
        'open': [_store('Bakeshop'), _store('Sari-sari')],
        'closed': [_store('Hardware', isOpen: false)],
      });
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Open now'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Open now chip drops closed shops', (tester) async {
      await _pumpTab(tester, {
        'open': [_store('Bakeshop')],
        'closed': [_store('Hardware', isOpen: false)],
      });
      await tester.tap(find.widgetWithText(ChoiceChip, 'Open now'));
      await tester.pump();
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.text('Hardware'), findsNothing);
    });

    testWidgets('a closed shop says when it reopens', (tester) async {
      await _pumpTab(tester, {
        'closed': [_store('Hardware', isOpen: false, day: 'monday', at: '09:00')],
      });
      expect(find.text('CLOSED'), findsOneWidget);
      expect(find.text('Opens Mon · 9:00 AM'), findsOneWidget);
      expect(find.text('Browse store'), findsOneWidget);
    });

    testWidgets('empty city shows a notice instead of a blank page',
        (tester) async {
      await _pumpTab(tester, {});
      expect(find.text('No shops here yet'), findsOneWidget);
    });

    testWidgets('fits a small phone under an app bar without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          publicStoresProvider.overrideWith((ref) async => {
                'open': [_store('A very long bakery name that wraps twice')],
              }),
        ],
        child: MaterialApp(
          home: Scaffold(appBar: AppBar(title: const Text('Stores')), body: const StoresTab()),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Visit store'), findsOneWidget);
    });

    testWidgets('singular copy for a lone shop', (tester) async {
      await _pumpTab(tester, {'open': [_store('Bakeshop')]});
      expect(find.text('1 shop'), findsOneWidget);
    });
  });

  group('StoreStatus.fromJson', () {
    test('pulls day and time out of the nextOpenTime OBJECT', () {
      final s = StoreStatus.fromJson({
        'isOpen': false,
        'nextOpenTime': {
          'date': '2026-09-13T00:00:00.000Z',
          'day': 'saturday',
          'open': '08:00',
          'close': '17:00',
          'isSpecialHours': false,
        },
      });

      expect(s.isOpen, isFalse);
      expect(s.nextOpenDay, 'saturday');
      expect(s.nextOpenAt, '08:00');
    });

    test('also reads the {date,time} shape from the store schedule', () {
      final s = StoreStatus.fromJson({
        'isOpen': false,
        'nextOpenTime': {'date': '2026-09-13T00:00:00.000Z', 'time': '07:30'},
      });

      expect(s.nextOpenAt, '07:30');
      expect(s.nextOpenDay, isNull);
    });

    test('an open store carries no reopening slot', () {
      final s = StoreStatus.fromJson({'isOpen': true, 'nextOpenTime': null});

      expect(s.isOpen, isTrue);
      expect(s.nextOpenDay, isNull);
      expect(s.nextOpenAt, isNull);
    });

    test('defaults to open when the backend omits the flag', () {
      expect(StoreStatus.fromJson(const {}).isOpen, isTrue);
    });
  });
}
