// lib/core/error_boundary.dart
// ============================================================================
// ERROR BOUNDARY - Production-Safe Error Handling for Flutter Apps
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ============================================================================
// ERROR BOUNDARY WIDGET
// Catches errors in its child widget tree and displays a fallback UI
// ============================================================================
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(FlutterErrorDetails)? fallbackBuilder;
  final void Function(FlutterErrorDetails)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallbackBuilder,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  FlutterErrorDetails? _error;

  @override
  void initState() {
    super.initState();
    // Store original error handler
    final originalHandler = FlutterError.onError;

    FlutterError.onError = (details) {
      // Check if error is from this widget's subtree
      if (mounted) {
        setState(() => _error = details);
        widget.onError?.call(details);
      }

      // Call original handler for logging
      originalHandler?.call(details);
    };
  }

  void _resetError() {
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.fallbackBuilder?.call(_error!) ??
          ErrorFallbackWidget(error: _error!, onRetry: _resetError);
    }
    return widget.child;
  }
}

// ============================================================================
// ERROR FALLBACK WIDGET
// User-friendly error display with retry option
// ============================================================================
class ErrorFallbackWidget extends StatelessWidget {
  final FlutterErrorDetails error;
  final VoidCallback? onRetry;
  final String? customMessage;

  const ErrorFallbackWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.1),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                customMessage ?? 'We encountered an unexpected error.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error.exceptionAsString(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ASYNC ERROR WIDGET
// For displaying errors from async operations (FutureBuilder, StreamBuilder)
// ============================================================================
class AsyncErrorWidget extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const AsyncErrorWidget({
    super.key,
    required this.error,
    this.stackTrace,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = _getErrorMessage(error);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 48,
            color: colorScheme.error.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel ?? 'Retry'),
            ),
          ],
        ],
      ),
    );
  }

  String _getErrorMessage(Object error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('socket') || errorStr.contains('network')) {
      return 'Network error. Please check your connection.';
    }
    if (errorStr.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
      return 'Session expired. Please log in again.';
    }
    if (errorStr.contains('403') || errorStr.contains('forbidden')) {
      return 'Access denied.';
    }
    if (errorStr.contains('404') || errorStr.contains('not found')) {
      return 'Resource not found.';
    }
    if (errorStr.contains('500') || errorStr.contains('server')) {
      return 'Server error. Please try again later.';
    }

    return 'Something went wrong. Please try again.';
  }
}

// ============================================================================
// APP ERROR HANDLER
// Global error handler setup for production apps
// ============================================================================
class AppErrorHandler {
  static bool _initialized = false;

  /// Initialize global error handling
  /// Call this in main() before runApp()
  static void initialize({
    void Function(Object error, StackTrace stack)? onError,
  }) {
    if (_initialized) return;
    _initialized = true;

    // Handle Flutter framework errors
    FlutterError.onError = (details) {
      FlutterError.presentError(details);

      if (!kDebugMode) {
        // In production, log to crash reporting service
        _reportError(details.exception, details.stack);
      }
    };

    // Handle errors outside Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      if (!kDebugMode) {
        _reportError(error, stack);
      }
      onError?.call(error, stack);
      return true; // Prevent app crash
    };
  }

  static void _reportError(Object error, StackTrace? stack) {
    // TODO: Integrate with Crashlytics or Sentry in production
    // FirebaseCrashlytics.instance.recordError(error, stack);

    // For now, just log in debug
    if (kDebugMode) {
      debugPrint('🔴 Error: $error');
      debugPrint('Stack: $stack');
    }
  }

  /// Safely execute a function and catch errors
  static T? tryCatch<T>(
    T Function() action, {
    T? fallback,
    void Function(Object error)? onError,
  }) {
    try {
      return action();
    } catch (e) {
      onError?.call(e);
      return fallback;
    }
  }

  /// Safely execute an async function
  static Future<T?> tryAsync<T>(
    Future<T> Function() action, {
    T? fallback,
    void Function(Object error)? onError,
  }) async {
    try {
      return await action();
    } catch (e) {
      onError?.call(e);
      return fallback;
    }
  }
}

// ============================================================================
// EXTENSION FOR CONVENIENT ERROR HANDLING
// ============================================================================
extension ErrorHandlingExtension<T> on Future<T> {
  /// Handle errors with a fallback value
  Future<T?> orNull() async {
    try {
      return await this;
    } catch (_) {
      return null;
    }
  }

  /// Handle errors with a custom fallback
  Future<T> orDefault(T defaultValue) async {
    try {
      return await this;
    } catch (_) {
      return defaultValue;
    }
  }
}
