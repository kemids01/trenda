// test/closed_store_reopening_test.dart
// The closed-store dialog and banner render a readable reopening time.
// The backend sends storeStatus.nextOpenTime as an OBJECT, so a plain
// toString() used to put a raw map behind "Opens ...".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/stores/widgets/closed_store_dialog.dart';
import 'package:trenda_frontend/features/vendors/providers/vendor_follow_provider.dart';
import 'package:trenda_shared/models/product_model.dart';

void main() {
  group('reopeningLine', () {
    test('formats the structured day + time', () {
      expect(
        reopeningLine(day: 'saturday', time: '08:00'),
        'Opens Sat · 8:00 AM',
      );
    });

    test('falls back to a legacy plain string', () {
      expect(
        reopeningLine(legacy: '2026-06-29 09:00'),
        'Opens 2026-06-29 09:00',
      );
    });

    test('prefers the structured value over the legacy one', () {
      expect(
        reopeningLine(day: 'monday', time: '07:30', legacy: 'whenever'),
        'Opens Mon · 7:30 AM',
      );
    });

    test('is null when nothing usable was sent', () {
      expect(reopeningLine(), isNull);
      expect(reopeningLine(legacy: '   '), isNull);
    });
  });

  group('ProductStoreStatus reopening fields', () {
    test('unpacks the nextOpen OBJECT instead of stringifying it', () {
      final s = ProductStoreStatus.fromJson({
        'isOpen': false,
        'canOrder': false,
        'nextOpen': {
          'date': '2026-09-13T00:00:00.000Z',
          'day': 'saturday',
          'open': '08:00',
          'close': '17:00',
          'isSpecialHours': false,
        },
      });

      expect(s.nextOpenDay, 'saturday');
      expect(s.nextOpenAt, '08:00');
      // Never a stringified map.
      expect(s.nextOpenTime, isNull);
      expect(reopeningLine(day: s.nextOpenDay, time: s.nextOpenAt),
          'Opens Sat · 8:00 AM');
    });

    test('reads the nextOpenTime OBJECT too', () {
      final s = ProductStoreStatus.fromJson({
        'nextOpenTime': {'day': 'monday', 'time': '07:30'},
      });

      expect(s.nextOpenDay, 'monday');
      expect(s.nextOpenAt, '07:30');
    });

    test('still keeps a genuine plain string (legacy payloads)', () {
      final s = ProductStoreStatus.fromJson({'nextOpen': '2026-06-29 09:00'});

      expect(s.nextOpenTime, '2026-06-29 09:00');
      expect(s.nextOpenDay, isNull);
    });

    test('survives a toJson round trip (cart persistence)', () {
      final s = ProductStoreStatus.fromJson({
        'isOpen': false,
        'canOrder': false,
        'nextOpen': {'day': 'friday', 'open': '09:00'},
      });
      final round = ProductStoreStatus.fromJson(s.toJson());

      expect(round.nextOpenDay, 'friday');
      expect(round.nextOpenAt, '09:00');
      expect(round.isOpen, isFalse);
      expect(round.canOrder, isFalse);
    });
  });

  group('VendorProfile reopening fields', () {
    test('unpacks storeStatus.nextOpenTime', () {
      final p = VendorProfile.fromJson({
        'id': 'v1',
        'storeName': 'Dubets Store',
        'storeStatus': {
          'isOpen': false,
          'nextOpenTime': {'day': 'sunday', 'open': '10:00'},
        },
      });

      expect(p.isOpen, isFalse);
      expect(p.nextOpenDay, 'sunday');
      expect(p.nextOpenAt, '10:00');
      expect(p.nextOpenTime, isNull);
    });

    test('an open store carries no reopening slot', () {
      final p = VendorProfile.fromJson({
        'id': 'v1',
        'storeName': 'Dubets Store',
        'storeStatus': {'isOpen': true, 'nextOpenTime': null},
      });

      expect(p.isOpen, isTrue);
      expect(p.nextOpenDay, isNull);
      expect(p.nextOpenAt, isNull);
    });
  });

  group('widgets', () {
    testWidgets('the banner shows the formatted line, never a map',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClosedStoreBanner(nextOpenDay: 'saturday', nextOpenAt: '08:00'),
          ),
        ),
      );

      expect(find.text('Opens Sat · 8:00 AM'), findsOneWidget);
      expect(find.textContaining('isSpecialHours'), findsNothing);
    });

    testWidgets('the banner omits the line when there is no slot',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ClosedStoreBanner())),
      );

      expect(find.textContaining('Opens'), findsNothing);
      expect(find.text('This store is currently closed'), findsOneWidget);
    });

    testWidgets('the blocked dialog shows the formatted line', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showStoreClosedBlockedDialog(
                  context,
                  storeName: 'Dubets Store',
                  nextOpenDay: 'wednesday',
                  nextOpenAt: '13:15',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.text('Dubets Store is currently closed and not accepting orders.'),
        findsOneWidget,
      );
      expect(find.text('Opens Wed · 1:15 PM'), findsOneWidget);
    });
  });
}
