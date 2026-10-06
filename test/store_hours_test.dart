// test/store_hours_test.dart
// /api/stores/:id returns trading hours in two shapes; the store page renders
// one ordered week from whichever it gets.

import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/vendors/utils/store_hours.dart';

void main() {
  group('parseWeeklyHours', () {
    test('reads the VendorStoreHours MAP in Monday-first order', () {
      final week = parseWeeklyHours(storeHours: {
        'sunday': {'open': '10:00', 'close': '16:00', 'isOpen': true},
        'monday': {'open': '08:00', 'close': '17:00', 'isOpen': true},
        'tuesday': {'open': '08:00', 'close': '17:00', 'isOpen': true},
      });

      expect(week.map((d) => d.day), ['monday', 'tuesday', 'sunday']);
      expect(week.first.range, '8:00 AM – 5:00 PM');
      expect(week.last.range, '10:00 AM – 4:00 PM');
    });

    test('reads the VendorStore LIST shape (openTime/closeTime)', () {
      final week = parseWeeklyHours(operatingHours: [
        {'day': 'friday', 'isOpen': true, 'openTime': '09:30', 'closeTime': '21:00'},
        {'day': 'saturday', 'isOpen': false},
      ]);

      expect(week.map((d) => d.day), ['friday', 'saturday']);
      expect(week.first.range, '9:30 AM – 9:00 PM');
      expect(week.last.range, 'Closed');
    });

    test('the map wins when a day appears in both shapes', () {
      final week = parseWeeklyHours(
        storeHours: {
          'monday': {'open': '08:00', 'close': '17:00', 'isOpen': true}
        },
        operatingHours: [
          {'day': 'monday', 'isOpen': true, 'openTime': '06:00', 'closeTime': '10:00'},
          {'day': 'tuesday', 'isOpen': true, 'openTime': '07:00', 'closeTime': '11:00'},
        ],
      );

      expect(week.length, 2);
      expect(week.first.range, '8:00 AM – 5:00 PM');
      expect(week.last.day, 'tuesday');
    });

    test('an explicit null day is a real answer: closed', () {
      final week = parseWeeklyHours(storeHours: {
        'monday': {'open': '08:00', 'close': '17:00', 'isOpen': true},
        'sunday': null,
      });

      expect(week.map((d) => d.day), ['monday', 'sunday']);
      expect(week.last.isOpen, isFalse);
      expect(week.last.range, 'Closed');
    });

    test('isOpen false overrides any times present', () {
      final week = parseWeeklyHours(storeHours: {
        'wednesday': {'open': '08:00', 'close': '17:00', 'isOpen': false},
      });

      expect(week.single.range, 'Closed');
    });

    test('handles half-open ranges without printing a dangling dash', () {
      final week = parseWeeklyHours(storeHours: {
        'monday': {'open': '08:00', 'isOpen': true},
        'tuesday': {'close': '17:00', 'isOpen': true},
        'wednesday': {'isOpen': true},
      });

      expect(week[0].range, 'From 8:00 AM');
      expect(week[1].range, 'Until 5:00 PM');
      expect(week[2].range, 'Open');
    });

    test('no schedule at all returns empty, so the section can hide', () {
      expect(parseWeeklyHours(), isEmpty);
      expect(parseWeeklyHours(storeHours: null, operatingHours: null), isEmpty);
      expect(parseWeeklyHours(storeHours: 'nonsense'), isEmpty);
      expect(parseWeeklyHours(storeHours: const {}), isEmpty);
    });

    test('ignores junk entries instead of throwing', () {
      final week = parseWeeklyHours(operatingHours: [
        'not a map',
        {'day': 'funday', 'isOpen': true},
        {'isOpen': true},
        {'day': 'monday', 'isOpen': true, 'openTime': '08:00', 'closeTime': '17:00'},
      ]);

      expect(week.map((d) => d.day), ['monday']);
    });

    test('labels are title-cased', () {
      final week = parseWeeklyHours(storeHours: {'thursday': {'isOpen': true}});
      expect(week.single.label, 'Thursday');
    });
  });

  group('weekdayKey', () {
    test('is Monday-indexed to match kWeekdayOrder', () {
      // 2026-09-14 is a Monday.
      expect(weekdayKey(DateTime(2026, 9, 14)), 'monday');
      expect(weekdayKey(DateTime(2026, 9, 18)), 'friday');
      expect(weekdayKey(DateTime(2026, 9, 20)), 'sunday');
    });

    test('every weekday maps into the order list', () {
      for (var i = 0; i < 7; i++) {
        final key = weekdayKey(DateTime(2026, 9, 14).add(Duration(days: i)));
        expect(kWeekdayOrder, contains(key));
      }
    });
  });

  group('tradingDaysSummary', () {
    test('names the trading days', () {
      final week = parseWeeklyHours(storeHours: {
        'monday': {'isOpen': true, 'open': '08:00', 'close': '17:00'},
        'saturday': {'isOpen': true, 'open': '08:00', 'close': '12:00'},
        'sunday': null,
      });

      expect(tradingDaysSummary(week), 'Mon, Sat');
    });

    test('collapses a full week', () {
      final week = parseWeeklyHours(
        storeHours: {
          for (final d in kWeekdayOrder)
            d: {'isOpen': true, 'open': '08:00', 'close': '17:00'}
        },
      );

      expect(tradingDaysSummary(week), 'Open every day');
    });

    test('is null when the shop never trades or has no schedule', () {
      expect(tradingDaysSummary(const []), isNull);
      expect(
        tradingDaysSummary(parseWeeklyHours(storeHours: {'monday': null})),
        isNull,
      );
    });
  });
}
