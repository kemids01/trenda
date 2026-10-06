// trenda_shared/lib/core/performance.dart
// ============================================================================
// PERFORMANCE MONITORING - Timing and metrics utilities
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Simple stopwatch wrapper for performance timing
class PerformanceTimer {
  final String name;
  final Stopwatch _stopwatch = Stopwatch();
  final List<Duration> _laps = [];

  PerformanceTimer(this.name);

  /// Start the timer
  void start() {
    _stopwatch.start();
  }

  /// Stop the timer and record the duration
  Duration stop() {
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsed;
    _laps.add(elapsed);
    return elapsed;
  }

  /// Record a lap without stopping
  Duration lap() {
    final elapsed = _stopwatch.elapsed;
    _laps.add(elapsed);
    return elapsed;
  }

  /// Reset the timer
  void reset() {
    _stopwatch.reset();
    _laps.clear();
  }

  /// Get elapsed time
  Duration get elapsed => _stopwatch.elapsed;

  /// Get all recorded laps
  List<Duration> get laps => List.unmodifiable(_laps);

  /// Log the elapsed time
  void log([String? additionalInfo]) {
    if (kDebugMode) {
      final info = additionalInfo != null ? ' - $additionalInfo' : '';
      debugPrint('⏱ [$name]$info: ${elapsed.inMilliseconds}ms');
    }
  }
}

/// Measure and log the execution time of a function
Future<T> measureAsync<T>(
  String name,
  Future<T> Function() action, {
  bool log = true,
}) async {
  final timer = PerformanceTimer(name)..start();
  try {
    return await action();
  } finally {
    timer.stop();
    if (log) timer.log();
  }
}

/// Measure and log the execution time of a sync function
T measure<T>(String name, T Function() action, {bool log = true}) {
  final timer = PerformanceTimer(name)..start();
  try {
    return action();
  } finally {
    timer.stop();
    if (log) timer.log();
  }
}

// ============================================================================
// METRICS COLLECTOR
// ============================================================================

/// Collects application metrics for monitoring
class MetricsCollector {
  static final MetricsCollector _instance = MetricsCollector._();
  static MetricsCollector get instance => _instance;

  MetricsCollector._();

  final Map<String, int> _counters = {};
  final Map<String, List<double>> _timings = {};
  final Map<String, double> _gauges = {};

  /// Increment a counter
  void increment(String name, [int amount = 1]) {
    _counters[name] = (_counters[name] ?? 0) + amount;
  }

  /// Set a gauge value (point-in-time measurement)
  void gauge(String name, double value) {
    _gauges[name] = value;
  }

  /// Record a timing measurement
  void timing(String name, Duration duration) {
    _timings.putIfAbsent(name, () => []);
    _timings[name]!.add(duration.inMilliseconds.toDouble());

    // Keep only last 100 measurements
    if (_timings[name]!.length > 100) {
      _timings[name]!.removeAt(0);
    }
  }

  /// Get counter value
  int getCounter(String name) => _counters[name] ?? 0;

  /// Get gauge value
  double? getGauge(String name) => _gauges[name];

  /// Get timing stats
  Map<String, double>? getTimingStats(String name) {
    final timings = _timings[name];
    if (timings == null || timings.isEmpty) return null;

    final sorted = List<double>.from(timings)..sort();
    final sum = timings.reduce((a, b) => a + b);

    return {
      'count': timings.length.toDouble(),
      'min': sorted.first,
      'max': sorted.last,
      'avg': sum / timings.length,
      'p50': sorted[(sorted.length * 0.5).floor()],
      'p95': sorted[(sorted.length * 0.95).floor()],
      'p99': sorted[(sorted.length * 0.99).floor()],
    };
  }

  /// Get all metrics as a map
  Map<String, dynamic> getAll() {
    return {
      'counters': Map.from(_counters),
      'gauges': Map.from(_gauges),
      'timings': _timings.map((k, v) => MapEntry(k, getTimingStats(k))),
    };
  }

  /// Reset all metrics
  void reset() {
    _counters.clear();
    _timings.clear();
    _gauges.clear();
  }

  /// Log all metrics
  void logAll() {
    if (kDebugMode) {
      debugPrint('📊 === METRICS ===');

      if (_counters.isNotEmpty) {
        debugPrint('Counters:');
        _counters.forEach((k, v) => debugPrint('  $k: $v'));
      }

      if (_gauges.isNotEmpty) {
        debugPrint('Gauges:');
        _gauges.forEach((k, v) => debugPrint('  $k: $v'));
      }

      if (_timings.isNotEmpty) {
        debugPrint('Timings:');
        _timings.forEach((k, _) {
          final stats = getTimingStats(k);
          if (stats != null) {
            debugPrint(
              '  $k: avg=${stats['avg']?.toStringAsFixed(1)}ms, '
              'p95=${stats['p95']?.toStringAsFixed(1)}ms',
            );
          }
        });
      }
    }
  }
}

// ============================================================================
// FRAME MONITORING (For UI Performance)
// ============================================================================

/// Monitor frame rendering performance
class FrameMonitor {
  static final FrameMonitor _instance = FrameMonitor._();
  static FrameMonitor get instance => _instance;

  FrameMonitor._();

  final List<Duration> _frameDurations = [];
  Stopwatch? _frameStopwatch;
  int _droppedFrames = 0;

  /// Call at the start of each frame
  void frameStart() {
    _frameStopwatch = Stopwatch()..start();
  }

  /// Call at the end of each frame
  void frameEnd() {
    if (_frameStopwatch == null) return;

    _frameStopwatch!.stop();
    final duration = _frameStopwatch!.elapsed;

    _frameDurations.add(duration);

    // Keep only last 120 frames (2 seconds at 60fps)
    if (_frameDurations.length > 120) {
      _frameDurations.removeAt(0);
    }

    // Count dropped frames (> 16.67ms)
    if (duration.inMicroseconds > 16670) {
      _droppedFrames++;
    }
  }

  /// Get average frame time
  Duration get averageFrameTime {
    if (_frameDurations.isEmpty) return Duration.zero;
    final totalMicros = _frameDurations
        .map((d) => d.inMicroseconds)
        .reduce((a, b) => a + b);
    return Duration(microseconds: totalMicros ~/ _frameDurations.length);
  }

  /// Get approximate FPS
  double get fps {
    final avgMicros = averageFrameTime.inMicroseconds;
    if (avgMicros == 0) return 60;
    return 1000000 / avgMicros;
  }

  /// Get dropped frame count
  int get droppedFrames => _droppedFrames;

  /// Reset stats
  void reset() {
    _frameDurations.clear();
    _droppedFrames = 0;
  }

  /// Log stats
  void log() {
    if (kDebugMode) {
      debugPrint(
        '🖼 FPS: ${fps.toStringAsFixed(1)}, '
        'Avg frame: ${averageFrameTime.inMilliseconds}ms, '
        'Dropped: $_droppedFrames',
      );
    }
  }
}

// ============================================================================
// NETWORK MONITOR
// ============================================================================

/// Track network request statistics
class NetworkMonitor {
  static final NetworkMonitor _instance = NetworkMonitor._();
  static NetworkMonitor get instance => _instance;

  NetworkMonitor._();

  int _totalRequests = 0;
  int _failedRequests = 0;
  int _totalBytes = 0;
  final Map<int, int> _statusCounts = {};
  final List<NetworkRequestInfo> _recentRequests = [];

  /// Record a network request
  void recordRequest({
    required String url,
    required String method,
    required int statusCode,
    required Duration duration,
    int? responseBytes,
  }) {
    _totalRequests++;
    if (statusCode >= 400) _failedRequests++;
    if (responseBytes != null) _totalBytes += responseBytes;

    _statusCounts[statusCode] = (_statusCounts[statusCode] ?? 0) + 1;

    _recentRequests.add(
      NetworkRequestInfo(
        url: url,
        method: method,
        statusCode: statusCode,
        duration: duration,
        timestamp: DateTime.now(),
      ),
    );

    // Keep only last 50 requests
    if (_recentRequests.length > 50) {
      _recentRequests.removeAt(0);
    }

    // Log slow requests
    if (kDebugMode && duration.inMilliseconds > 2000) {
      debugPrint(
        '🐌 Slow request: $method $url (${duration.inMilliseconds}ms)',
      );
    }
  }

  /// Get success rate
  double get successRate {
    if (_totalRequests == 0) return 1.0;
    return (_totalRequests - _failedRequests) / _totalRequests;
  }

  /// Get statistics
  Map<String, dynamic> get stats => {
    'totalRequests': _totalRequests,
    'failedRequests': _failedRequests,
    'successRate': successRate,
    'totalBytesReceived': _totalBytes,
    'statusCounts': Map.from(_statusCounts),
  };

  /// Get slow requests (> threshold)
  List<NetworkRequestInfo> getSlowRequests({
    Duration threshold = const Duration(seconds: 1),
  }) {
    return _recentRequests.where((r) => r.duration > threshold).toList();
  }

  /// Reset stats
  void reset() {
    _totalRequests = 0;
    _failedRequests = 0;
    _totalBytes = 0;
    _statusCounts.clear();
    _recentRequests.clear();
  }
}

class NetworkRequestInfo {
  final String url;
  final String method;
  final int statusCode;
  final Duration duration;
  final DateTime timestamp;

  NetworkRequestInfo({
    required this.url,
    required this.method,
    required this.statusCode,
    required this.duration,
    required this.timestamp,
  });
}
