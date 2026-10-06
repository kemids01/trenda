// lib/core/logger.dart - Production-safe logging utility
// Replace print() statements with this for proper debug logging

import 'package:flutter/foundation.dart';

/// Production-safe logger that only outputs in debug mode
/// Prevents sensitive information from leaking in production builds
class AppLogger {
  static const String _tag = 'Trenda';

  /// Log debug information (development only)
  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      debugPrint('[$_tag${tag != null ? ':$tag' : ''}] $message');
    }
  }

  /// Log general information
  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      debugPrint('ℹ️ [$_tag${tag != null ? ':$tag' : ''}] $message');
    }
  }

  /// Log warnings
  static void warning(String message, [String? tag]) {
    if (kDebugMode) {
      debugPrint('⚠️ [$_tag${tag != null ? ':$tag' : ''}] $message');
    }
  }

  /// Log errors with optional stack trace
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('❌ [$_tag] ERROR: $message');
      if (error != null) {
        debugPrint('   Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('   Stack: $stackTrace');
      }
    }
    // In production, you could send to Crashlytics here:
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }

  /// Log API requests (development only)
  static void api(String method, String url, [int? statusCode]) {
    if (kDebugMode) {
      final status = statusCode != null ? ' → $statusCode' : '';
      debugPrint('🌐 [$_tag:API] $method $url$status');
    }
  }

  /// Log navigation events
  static void navigation(String route, [String? action]) {
    if (kDebugMode) {
      final act = action ?? 'navigated to';
      debugPrint('🧭 [$_tag:Nav] $act $route');
    }
  }

  /// Log state changes (for debugging state management)
  static void state(String provider, String event) {
    if (kDebugMode) {
      debugPrint('🔄 [$_tag:State] $provider: $event');
    }
  }

  /// Log timing for performance debugging
  static Stopwatch startTiming(String label) {
    final stopwatch = Stopwatch()..start();
    if (kDebugMode) {
      debugPrint('⏱️ [$_tag:Timing] Started: $label');
    }
    return stopwatch;
  }

  static void endTiming(String label, Stopwatch stopwatch) {
    stopwatch.stop();
    if (kDebugMode) {
      debugPrint(
        '⏱️ [$_tag:Timing] $label: ${stopwatch.elapsedMilliseconds}ms',
      );
    }
  }
}

/// Shorthand function for quick debug logging
/// Usage: log('message') instead of print('message')
void log(String message, [String? tag]) {
  AppLogger.debug(message, tag);
}

/// Shorthand for error logging
void logError(String message, [Object? error, StackTrace? stackTrace]) {
  AppLogger.error(message, error, stackTrace);
}
