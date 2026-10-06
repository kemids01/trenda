// lib/features/core/widgets/error_boundary.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global error boundary widget that catches uncaught errors
class ErrorBoundary extends ConsumerStatefulWidget {
  final Widget child;
  final Widget Function(FlutterErrorDetails details)? errorBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
  });

  @override
  ConsumerState<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends ConsumerState<ErrorBoundary> {
  FlutterErrorDetails? _errorDetails;

  @override
  void initState() {
    super.initState();

    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      // Log error for monitoring
      _logError(details.exception, details.stack);

      // Defer setState to avoid calling during build phase
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _errorDetails = details;
            });
          }
        });
      }
    };
  }

  void _logError(Object error, StackTrace? stackTrace) {
    debugPrint('❌ Error caught by boundary: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _resetError() {
    setState(() {
      _errorDetails = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errorDetails != null) {
      return widget.errorBuilder?.call(_errorDetails!) ??
          _buildDefaultErrorWidget();
    }
    return widget.child;
  }

  Widget _buildDefaultErrorWidget() {
    // Wrap in Directionality since we're outside MaterialApp context
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Oops! Something went wrong',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'We\'re sorry for the inconvenience. Please try restarting the app.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Material(
                  child: ElevatedButton.icon(
                    onPressed: _resetError,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Provider error boundary for handling async errors in providers
class ProviderErrorBoundary extends ConsumerWidget {
  final AsyncValue asyncValue;
  final Widget Function() data;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;

  const ProviderErrorBoundary({
    super.key,
    required this.asyncValue,
    required this.data,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncValue.when(
      data: (_) => data(),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        if (errorBuilder != null) {
          return errorBuilder!(error, stackTrace);
        }
        return _buildDefaultErrorWidget(context, error);
      },
    );
  }

  Widget _buildDefaultErrorWidget(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Failed to load data',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _getUserFriendlyError(error),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getUserFriendlyError(Object error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('socket') || errorString.contains('network')) {
      return 'Please check your internet connection and try again.';
    }
    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return 'Session expired. Please login again.';
    }
    if (errorString.contains('404') || errorString.contains('not found')) {
      return 'Resource not found.';
    }
    if (errorString.contains('500') || errorString.contains('server')) {
      return 'Server error. Please try again later.';
    }

    return 'Something went wrong. Please try again.';
  }
}
