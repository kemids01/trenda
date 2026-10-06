// trenda_shared/lib/core/timezone.dart
// ============================================================================
// TIMEZONE UTILITY - GMT+8 (Asia/Manila) Timezone Handling
// ============================================================================

import 'package:intl/intl.dart';

/// Trenda platform timezone offset (GMT+8 = Asia/Manila, Philippines)
const int kTrendaTimezoneOffsetHours = 8;

/// Duration offset for GMT+8
const Duration kTrendaTimezoneOffset = Duration(
  hours: kTrendaTimezoneOffsetHours,
);

/// Timezone utility for consistent date/time handling across all Trenda apps.
///
/// Every app shows time in Philippine time (Asia/Manila, UTC+8, no DST) whatever zone the
/// device is set to. The backend sends UTC instants; `DateTime.parse` keeps them UTC, and
/// `DateFormat.format` prints a DateTime's OWN fields, so formatting one directly shows UTC
/// (8 hours behind). Format for display with `DateFormat(...).formatPh(dt)` instead.
///
/// [toLocal]/[now]/[today] return Manila WALL-CLOCK values (their fields read as Manila
/// time). They are for display and day-bucketing only: never send one to the server, and
/// never pass one to [format]/`formatPh` again (that shifts it a second time).
class TrendaTimezone {
  TrendaTimezone._();

  /// Manila wall-clock fields for the instant [dateTime] (UTC- or device-local-flagged alike).
  static DateTime toLocal(DateTime dateTime) =>
      dateTime.toUtc().add(kTrendaTimezoneOffset);

  /// Convert a Manila wall-clock value back to the UTC instant it names.
  static DateTime toUtc(DateTime manila) {
    return DateTime.utc(manila.year, manila.month, manila.day, manila.hour,
            manila.minute, manila.second, manila.millisecond)
        .subtract(kTrendaTimezoneOffset);
  }

  /// Get current time in GMT+8 (wall-clock)
  static DateTime now() {
    return DateTime.now().toUtc().add(kTrendaTimezoneOffset);
  }

  /// Get today's date in GMT+8 (midnight, wall-clock)
  static DateTime today() {
    final now = TrendaTimezone.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Parse a datetime string into GMT+8 wall-clock (display only).
  static DateTime? parse(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      final parsed = DateTime.parse(dateString);
      // If the string contains 'Z' or timezone info, it's UTC
      if (dateString.endsWith('Z') || dateString.contains('+')) {
        return toLocal(parsed);
      }
      // Assume it's already in local time
      return parsed;
    } catch (e) {
      return null;
    }
  }

  /// Format the instant [dateTime] in GMT+8 with a custom pattern.
  static String format(
    DateTime? dateTime, {
    String pattern = 'MMM d, yyyy h:mm a',
  }) {
    if (dateTime == null) return '';
    return DateFormat(pattern).formatPh(dateTime);
  }

  /// Format date only (no time)
  static String formatDate(
    DateTime? dateTime, {
    String pattern = 'MMM d, yyyy',
  }) {
    return format(dateTime, pattern: pattern);
  }

  /// Format time only
  static String formatTime(DateTime? dateTime, {String pattern = 'h:mm a'}) {
    return format(dateTime, pattern: pattern);
  }

  /// Format relative time (e.g., "2 hours ago", "Yesterday")
  static String formatRelative(DateTime? dateTime) {
    if (dateTime == null) return '';

    final diff = DateTime.now().difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return formatDate(dateTime);
    }
  }

  /// Check if the instant is today in GMT+8
  static bool isToday(DateTime? dateTime) {
    if (dateTime == null) return false;
    final local = toLocal(dateTime);
    final today = TrendaTimezone.today();
    return local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
  }

  /// Check if the instant is yesterday in GMT+8
  static bool isYesterday(DateTime? dateTime) {
    if (dateTime == null) return false;
    final local = toLocal(dateTime);
    final yesterday = TrendaTimezone.today().subtract(const Duration(days: 1));
    return local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day;
  }

  /// Get start of the GMT+8 day containing the instant (wall-clock)
  static DateTime startOfDay(DateTime dateTime) {
    final local = toLocal(dateTime);
    return DateTime(local.year, local.month, local.day);
  }

  /// Get end of the GMT+8 day containing the instant (wall-clock)
  static DateTime endOfDay(DateTime dateTime) {
    final local = toLocal(dateTime);
    return DateTime(local.year, local.month, local.day, 23, 59, 59, 999);
  }

  /// Get timezone display string
  static String get timezoneString => 'GMT+$kTrendaTimezoneOffsetHours';
  static String get timezoneName => 'Asia/Manila';
}

/// Extension on DateTime for easy GMT+8 conversion
extension TrendaDateTimeExtension on DateTime {
  /// Convert to GMT+8 (Manila wall-clock — display only)
  DateTime get toManilaTime => TrendaTimezone.toLocal(this);

  /// Format in GMT+8 with default pattern
  String get formattedManila => TrendaTimezone.format(this);

  /// Format date only in GMT+8
  String get formattedDateManila => TrendaTimezone.formatDate(this);

  /// Format time only in GMT+8
  String get formattedTimeManila => TrendaTimezone.formatTime(this);

  /// Format as relative time in GMT+8
  String get relativeManila => TrendaTimezone.formatRelative(this);

  /// Check if this datetime is today in GMT+8
  bool get isTodayManila => TrendaTimezone.isToday(this);
}

/// Philippine-time formatting for any [DateFormat].
extension TrendaPhDateFormat on DateFormat {
  /// Formats the instant [dateTime] as Philippine time (Asia/Manila, UTC+8), whatever the
  /// device's own zone. Use this — not `format` — for every timestamp shown to a person.
  String formatPh(DateTime dateTime) => format(TrendaTimezone.toLocal(dateTime));
}
