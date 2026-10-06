// trenda_shared/lib/core/extensions.dart
// ============================================================================
// DART EXTENSIONS - Useful extensions for common types
// ============================================================================

import 'package:flutter/material.dart';
import 'timezone.dart';

// ============================================================================
// STRING EXTENSIONS
// ============================================================================

extension StringExtensions on String {
  /// Capitalize first letter
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Capitalize each word
  String get titleCase {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  /// Check if string is a valid email
  bool get isValidEmail {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);
  }

  /// Check if string is a valid phone number
  bool get isValidPhone {
    return RegExp(r'^[\d\s\-\+\(\)]{10,}$').hasMatch(this);
  }

  /// Check if string is a valid URL
  bool get isValidUrl {
    return Uri.tryParse(this)?.hasAbsolutePath ?? false;
  }

  /// Check if string is numeric
  bool get isNumeric {
    return double.tryParse(this) != null;
  }

  /// Truncate string with ellipsis
  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  /// Remove all whitespace
  String get removeWhitespace => replaceAll(RegExp(r'\s+'), '');

  /// Convert to snake_case
  String get toSnakeCase {
    return replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).replaceFirst(RegExp(r'^_'), '');
  }

  /// Convert to camelCase
  String get toCamelCase {
    final words = split(RegExp(r'[_\s-]'));
    if (words.isEmpty) return this;
    return words.first.toLowerCase() +
        words.skip(1).map((w) => w.capitalize).join();
  }

  /// Parse as int or null
  int? get toIntOrNull => int.tryParse(this);

  /// Parse as double or null
  double? get toDoubleOrNull => double.tryParse(this);

  /// Check if blank (empty or whitespace only)
  bool get isBlank => trim().isEmpty;

  /// Check if not blank
  bool get isNotBlank => !isBlank;
}

// ============================================================================
// NULLABLE STRING EXTENSIONS
// ============================================================================

extension NullableStringExtensions on String? {
  /// Return this or default if null/empty
  String orDefault(String defaultValue) {
    if (this == null || this!.isEmpty) return defaultValue;
    return this!;
  }

  /// Check if null or empty
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  /// Check if not null and not empty
  bool get isNotNullOrEmpty => !isNullOrEmpty;

  /// Check if null or blank
  bool get isNullOrBlank => this == null || this!.isBlank;
}

// ============================================================================
// DATETIME EXTENSIONS
// ============================================================================

extension DateTimeExtensions on DateTime {
  /// Format as date string (MM/DD/YYYY)
  String get toDateString => '$month/$day/$year';

  /// Format as time string (HH:MM AM/PM)
  String get toTimeString {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Format as date and time string
  String get toDateTimeString => '$toDateString $toTimeString';

  /// Format as ISO date (YYYY-MM-DD)
  String get toIsoDateString =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  /// Check if today (Philippine time)
  bool get isToday => TrendaTimezone.isToday(this);

  /// Check if yesterday (Philippine time)
  bool get isYesterday => TrendaTimezone.isYesterday(this);

  /// Check if tomorrow (Philippine time)
  bool get isTomorrow {
    final l = TrendaTimezone.toLocal(this);
    final tomorrow = TrendaTimezone.today().add(const Duration(days: 1));
    return l.year == tomorrow.year &&
        l.month == tomorrow.month &&
        l.day == tomorrow.day;
  }

  /// Check if in the past
  bool get isPast => isBefore(DateTime.now());

  /// Check if in the future
  bool get isFuture => isAfter(DateTime.now());

  /// Get start of day
  DateTime get startOfDay => DateTime(year, month, day);

  /// Get end of day
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  /// Get start of week (Monday)
  DateTime get startOfWeek {
    final days = weekday - 1;
    return subtract(Duration(days: days)).startOfDay;
  }

  /// Get start of month
  DateTime get startOfMonth => DateTime(year, month, 1);

  /// Get end of month
  DateTime get endOfMonth => DateTime(year, month + 1, 0, 23, 59, 59, 999);

  /// Get relative time string (e.g., "2 hours ago")
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inDays > 365) {
      final years = (diff.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
    if (diff.inDays > 30) {
      final months = (diff.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }
    if (diff.inDays > 0) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    }
    return 'Just now';
  }
}

// ============================================================================
// LIST EXTENSIONS
// ============================================================================

extension ListExtensions<T> on List<T> {
  /// Get first element or null if empty
  T? get firstOrNull => isEmpty ? null : first;

  /// Get last element or null if empty
  T? get lastOrNull => isEmpty ? null : last;

  /// Get element at index or null if out of bounds
  T? getOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }

  /// Separate list into chunks
  List<List<T>> chunked(int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      chunks.add(sublist(i, i + size > length ? length : i + size));
    }
    return chunks;
  }

  /// Group by a key
  Map<K, List<T>> groupBy<K>(K Function(T) keyExtractor) {
    final map = <K, List<T>>{};
    for (final item in this) {
      final key = keyExtractor(item);
      (map[key] ??= []).add(item);
    }
    return map;
  }

  /// Find first matching element or null
  T? firstWhereOrNull(bool Function(T) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }

  /// Map with index
  List<R> mapIndexed<R>(R Function(int index, T item) transform) {
    final result = <R>[];
    for (var i = 0; i < length; i++) {
      result.add(transform(i, this[i]));
    }
    return result;
  }

  /// Get unique elements
  List<T> get unique => toSet().toList();

  /// Remove nulls from nullable list
  List<T> get whereNotNull => where((e) => e != null).toList();
}

// ============================================================================
// MAP EXTENSIONS
// ============================================================================

extension MapExtensions<K, V> on Map<K, V> {
  /// Get value or default
  V getOrDefault(K key, V defaultValue) {
    return this[key] ?? defaultValue;
  }

  /// Deep merge with another map
  Map<K, V> merge(Map<K, V> other) {
    return {...this, ...other};
  }

  /// Filter entries by predicate
  Map<K, V> whereEntries(bool Function(K key, V value) test) {
    return Map.fromEntries(entries.where((e) => test(e.key, e.value)));
  }
}

// ============================================================================
// NUM EXTENSIONS
// ============================================================================

extension NumExtensions on num {
  /// Format as currency
  String toCurrency({String symbol = '\$', int decimals = 2}) {
    return '$symbol${toStringAsFixed(decimals)}';
  }

  /// Format with thousand separators
  String get formatted {
    final str = toString();
    final parts = str.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }

  /// Clamp between min and max
  num clampBetween(num min, num max) => clamp(min, max);

  /// Check if between two values (inclusive)
  bool isBetween(num min, num max) => this >= min && this <= max;
}

// ============================================================================
// DURATION EXTENSIONS
// ============================================================================

extension DurationExtensions on Duration {
  /// Format as HH:MM:SS
  String get formatted {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Human readable format
  String get humanReadable {
    if (inDays > 0) return '$inDays ${inDays == 1 ? 'day' : 'days'}';
    if (inHours > 0) return '$inHours ${inHours == 1 ? 'hour' : 'hours'}';
    if (inMinutes > 0) {
      return '$inMinutes ${inMinutes == 1 ? 'minute' : 'minutes'}';
    }
    return '$inSeconds ${inSeconds == 1 ? 'second' : 'seconds'}';
  }
}

// ============================================================================
// BUILDCONTEXT EXTENSIONS
// ============================================================================

extension BuildContextExtensions on BuildContext {
  /// Get the theme
  ThemeData get theme => Theme.of(this);

  /// Get the color scheme
  ColorScheme get colorScheme => theme.colorScheme;

  /// Get the text theme
  TextTheme get textTheme => theme.textTheme;

  /// Get screen size
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Get screen width
  double get screenWidth => screenSize.width;

  /// Get screen height
  double get screenHeight => screenSize.height;

  /// Check if keyboard is visible
  bool get isKeyboardVisible => MediaQuery.viewInsetsOf(this).bottom > 0;

  /// Get padding (safe area)
  EdgeInsets get padding => MediaQuery.paddingOf(this);

  /// Check if dark mode
  bool get isDarkMode => theme.brightness == Brightness.dark;

  /// Get platform brightness
  Brightness get platformBrightness => MediaQuery.platformBrightnessOf(this);
}
