// trenda_shared/lib/core/debounce.dart
// ============================================================================
// DEBOUNCE & THROTTLE - Rate limiting utilities
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Debounces function calls - only executes after a delay with no calls
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// Call the function after the delay, canceling any pending calls
  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancel any pending calls
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dispose the debouncer
  void dispose() {
    cancel();
  }

  /// Whether there's a pending call
  bool get isPending => _timer?.isActive ?? false;
}

/// Creates a debounced version of a function
VoidCallback debounce(
  VoidCallback action, {
  Duration delay = const Duration(milliseconds: 300),
}) {
  Timer? timer;
  return () {
    timer?.cancel();
    timer = Timer(delay, action);
  };
}

/// Creates a debounced version of a function with argument
void Function(T) debounceArg<T>(
  void Function(T) action, {
  Duration delay = const Duration(milliseconds: 300),
}) {
  Timer? timer;
  return (T value) {
    timer?.cancel();
    timer = Timer(delay, () => action(value));
  };
}

// ============================================================================
// THROTTLE
// ============================================================================

/// Throttles function calls - only executes once per interval
class Throttler {
  final Duration interval;
  DateTime? _lastCall;
  Timer? _timer;
  final bool _trailing;

  Throttler({
    this.interval = const Duration(milliseconds: 300),
    bool trailing = false,
  }) : _trailing = trailing;

  /// Call the function, throttled to the interval
  void call(VoidCallback action) {
    final now = DateTime.now();

    if (_lastCall == null || now.difference(_lastCall!) >= interval) {
      _lastCall = now;
      action();
    } else if (_trailing) {
      // Schedule trailing call
      _timer?.cancel();
      _timer = Timer(interval - now.difference(_lastCall!), () {
        _lastCall = DateTime.now();
        action();
      });
    }
  }

  /// Cancel any pending trailing calls
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dispose the throttler
  void dispose() {
    cancel();
  }
}

/// Creates a throttled version of a function
VoidCallback throttle(
  VoidCallback action, {
  Duration interval = const Duration(milliseconds: 300),
  bool trailing = false,
}) {
  DateTime? lastCall;
  Timer? timer;

  return () {
    final now = DateTime.now();

    if (lastCall == null || now.difference(lastCall!) >= interval) {
      lastCall = now;
      action();
    } else if (trailing) {
      timer?.cancel();
      timer = Timer(interval - now.difference(lastCall!), () {
        lastCall = DateTime.now();
        action();
      });
    }
  };
}

// ============================================================================
// RATE LIMITER
// ============================================================================

/// Generic rate limiter with configurable limits
class RateLimiter {
  final int maxCalls;
  final Duration window;
  final List<DateTime> _calls = [];

  RateLimiter({required this.maxCalls, required this.window});

  /// Check if a call is allowed
  bool get canCall {
    _cleanup();
    return _calls.length < maxCalls;
  }

  /// Record a call attempt, returns true if allowed
  bool tryCall() {
    _cleanup();
    if (_calls.length < maxCalls) {
      _calls.add(DateTime.now());
      return true;
    }
    return false;
  }

  /// Get time until next call is allowed
  Duration? get timeUntilNextCall {
    if (canCall) return null;
    _cleanup();
    if (_calls.isEmpty) return null;

    final oldestCall = _calls.first;
    final elapsed = DateTime.now().difference(oldestCall);
    final remaining = window - elapsed;
    return remaining.isNegative ? null : remaining;
  }

  void _cleanup() {
    final cutoff = DateTime.now().subtract(window);
    _calls.removeWhere((call) => call.isBefore(cutoff));
  }

  /// Reset the rate limiter
  void reset() {
    _calls.clear();
  }
}

// ============================================================================
// RETRY HELPER
// ============================================================================

/// Retry an async operation with exponential backoff
Future<T> retry<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(seconds: 1),
  double backoffMultiplier = 2.0,
  bool Function(Object error)? shouldRetry,
}) async {
  int attempts = 0;
  Duration delay = initialDelay;

  while (true) {
    try {
      attempts++;
      return await action();
    } catch (e) {
      if (attempts >= maxAttempts) rethrow;
      if (shouldRetry != null && !shouldRetry(e)) rethrow;

      await Future.delayed(delay);
      delay = Duration(
        milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
      );
    }
  }
}
