// lib/features/vendors/utils/store_hours.dart
// Turns the two opening-hours shapes /api/stores/:id can return into one
// ordered Monday-to-Sunday list the store page can render. Widget-free.

import '../../stores/utils/storefront_style.dart';

/// One day on the shop's trading week.
class StoreDayHours {
  /// Lowercase weekday key, e.g. 'monday'.
  final String day;
  final bool isOpen;

  /// 24h opening/closing times as the backend stores them ('09:00').
  final String? open;
  final String? close;

  const StoreDayHours({
    required this.day,
    required this.isOpen,
    this.open,
    this.close,
  });

  /// 'Monday'
  String get label =>
      day.isEmpty ? '' : day[0].toUpperCase() + day.substring(1);

  /// '9:00 AM – 9:00 PM', or 'Closed' when the shop does not trade that day.
  String get range {
    if (!isOpen) return 'Closed';
    final o = open?.trim() ?? '';
    final c = close?.trim() ?? '';
    if (o.isEmpty && c.isEmpty) return 'Open';
    if (c.isEmpty) return 'From ${formatClockTime(o)}';
    if (o.isEmpty) return 'Until ${formatClockTime(c)}';
    return '${formatClockTime(o)} – ${formatClockTime(c)}';
  }
}

const List<String> kWeekdayOrder = <String>[
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

/// Today's weekday key, Monday-indexed like [kWeekdayOrder].
String weekdayKey(DateTime date) => kWeekdayOrder[date.weekday - 1];

/// Reads the weekly hours out of whichever shape the store carries.
///
/// `storeHours` (VendorStoreHours) is a MAP keyed by weekday:
///   { monday: {open, close, isOpen}, ... } — a null day means "not trading".
/// `operatingHours` (VendorStore) is a LIST:
///   [ {day, isOpen, openTime, closeTime}, ... ].
///
/// Returns an empty list when the shop has published no schedule at all, so
/// callers can hide the section rather than show a week of blanks.
List<StoreDayHours> parseWeeklyHours({
  dynamic storeHours,
  dynamic operatingHours,
}) {
  final byDay = <String, StoreDayHours>{};

  if (storeHours is Map) {
    for (final day in kWeekdayOrder) {
      final slot = storeHours[day];
      if (slot is Map) {
        byDay[day] = StoreDayHours(
          day: day,
          isOpen: slot['isOpen'] != false,
          open: slot['open']?.toString(),
          close: slot['close']?.toString(),
        );
      } else if (storeHours.containsKey(day)) {
        // An explicit null day is a real answer: closed.
        byDay[day] = StoreDayHours(day: day, isOpen: false);
      }
    }
  }

  if (operatingHours is List) {
    for (final entry in operatingHours) {
      if (entry is! Map) continue;
      final day = entry['day']?.toString().toLowerCase();
      if (day == null || !kWeekdayOrder.contains(day)) continue;
      // The map shape wins — it is the schedule the open/closed check uses.
      byDay.putIfAbsent(
        day,
        () => StoreDayHours(
          day: day,
          isOpen: entry['isOpen'] != false,
          open: (entry['openTime'] ?? entry['open'])?.toString(),
          close: (entry['closeTime'] ?? entry['close'])?.toString(),
        ),
      );
    }
  }

  if (byDay.isEmpty) return const [];
  return [
    for (final day in kWeekdayOrder)
      if (byDay.containsKey(day)) byDay[day]!,
  ];
}

/// 'Mon–Fri' style summary of the days a shop trades, for a one-line preview.
/// Returns null when there is no schedule or the shop trades every day.
String? tradingDaysSummary(List<StoreDayHours> week) {
  if (week.isEmpty) return null;
  final open = week.where((d) => d.isOpen).toList();
  if (open.isEmpty) return null;
  if (open.length == 7) return 'Open every day';
  return open.map((d) => shortDay(d.day)).join(', ');
}
