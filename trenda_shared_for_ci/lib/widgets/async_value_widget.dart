// trenda_shared/lib/widgets/async_value_widget.dart
// ============================================================================
// ASYNC VALUE WIDGETS - Loading, Error, and Retry UI components
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// ASYNC VALUE WIDGET
// Handles AsyncValue states (loading, error, data) with proper UI
// ============================================================================

class AsyncValueWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget Function()? loading;
  final Widget Function(Object error, StackTrace? stackTrace)? error;
  final VoidCallback? onRetry;

  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => loading?.call() ?? const LoadingWidget(),
      error: (e, st) =>
          error?.call(e, st) ?? ErrorDisplayWidget(error: e, onRetry: onRetry),
    );
  }
}

/// Sliver version for use in CustomScrollView
class SliverAsyncValueWidget<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget Function()? loading;
  final Widget Function(Object error, StackTrace? stackTrace)? error;
  final VoidCallback? onRetry;

  const SliverAsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () =>
          SliverToBoxAdapter(child: loading?.call() ?? const LoadingWidget()),
      error: (e, st) => SliverToBoxAdapter(
        child:
            error?.call(e, st) ??
            ErrorDisplayWidget(error: e, onRetry: onRetry),
      ),
    );
  }
}

// ============================================================================
// LOADING WIDGET
// Customizable loading indicator with optional message
// ============================================================================

class LoadingWidget extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;
  final bool useShimmer;

  const LoadingWidget({
    super.key,
    this.message,
    this.size = 40,
    this.color,
    this.useShimmer = false,
  });

  /// Full page loading overlay
  const factory LoadingWidget.fullPage({Key? key, String? message}) =
      _FullPageLoading;

  /// Inline loading (smaller)
  const factory LoadingWidget.inline({Key? key, String? message, double size}) =
      _InlineLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = color ?? theme.colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(indicatorColor),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FullPageLoading extends LoadingWidget {
  const _FullPageLoading({super.key, super.message}) : super(size: 48);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(
                  color ?? theme.colorScheme.primary,
                ),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 24),
              Text(
                message!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineLoading extends LoadingWidget {
  const _InlineLoading({super.key, super.message, double size = 20})
    : super(size: size);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(
              color ?? theme.colorScheme.primary,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(width: 12),
          Text(
            message!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// ERROR DISPLAY WIDGET
// Shows error message with retry option
// ============================================================================

class ErrorDisplayWidget extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final String? customMessage;
  final IconData icon;
  final bool showDetails;

  const ErrorDisplayWidget({
    super.key,
    required this.error,
    this.stackTrace,
    this.onRetry,
    this.customMessage,
    this.icon = Icons.error_outline,
    this.showDetails = false,
  });

  /// Compact error for inline use
  const factory ErrorDisplayWidget.compact({
    Key? key,
    required Object error,
    VoidCallback? onRetry,
    String? customMessage,
  }) = _CompactErrorDisplay;

  /// Full page error
  const factory ErrorDisplayWidget.fullPage({
    Key? key,
    required Object error,
    StackTrace? stackTrace,
    VoidCallback? onRetry,
    String? customMessage,
  }) = _FullPageErrorDisplay;

  String get _errorMessage {
    if (customMessage != null) return customMessage!;

    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('socket') ||
        errorStr.contains('connection') ||
        errorStr.contains('network')) {
      return 'Unable to connect. Please check your internet connection.';
    }

    if (errorStr.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
      return 'Session expired. Please sign in again.';
    }

    if (errorStr.contains('403') || errorStr.contains('forbidden')) {
      return 'You don\'t have permission to access this.';
    }

    if (errorStr.contains('404') || errorStr.contains('not found')) {
      return 'The requested content was not found.';
    }

    if (errorStr.contains('500') || errorStr.contains('server')) {
      return 'Something went wrong on our end. Please try again later.';
    }

    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: errorColor),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (showDetails) ...[
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactErrorDisplay extends ErrorDisplayWidget {
  const _CompactErrorDisplay({
    super.key,
    required super.error,
    super.onRetry,
    super.customMessage,
  }) : super(icon: Icons.warning_amber_rounded);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (onRetry != null)
            IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 20),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _FullPageErrorDisplay extends ErrorDisplayWidget {
  const _FullPageErrorDisplay({
    super.key,
    required super.error,
    super.stackTrace,
    super.onRetry,
    super.customMessage,
  }) : super(icon: Icons.error_outline);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: errorColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 64, color: errorColor),
                ),
                const SizedBox(height: 24),
                Text(
                  'Oops!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// RETRY WIDGET
// Wraps content with automatic retry on failure
// ============================================================================

class RetryWidget extends StatefulWidget {
  final Future<void> Function() onLoad;
  final Widget child;
  final Widget Function()? loadingBuilder;
  final Widget Function(Object error, VoidCallback retry)? errorBuilder;
  final int maxRetries;
  final Duration retryDelay;
  final bool autoRetry;

  const RetryWidget({
    super.key,
    required this.onLoad,
    required this.child,
    this.loadingBuilder,
    this.errorBuilder,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.autoRetry = false,
  });

  @override
  State<RetryWidget> createState() => _RetryWidgetState();
}

class _RetryWidgetState extends State<RetryWidget> {
  bool _isLoading = true;
  Object? _error;
  int _retryCount = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.onLoad();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _retryCount = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e;
        });

        // Auto-retry if enabled and under limit
        if (widget.autoRetry && _retryCount < widget.maxRetries) {
          _retryCount++;
          _retryTimer = Timer(widget.retryDelay, _load);
        }
      }
    }
  }

  void _retry() {
    _retryCount = 0;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingBuilder?.call() ?? const LoadingWidget();
    }

    if (_error != null) {
      return widget.errorBuilder?.call(_error!, _retry) ??
          ErrorDisplayWidget(error: _error!, onRetry: _retry);
    }

    return widget.child;
  }
}

// ============================================================================
// EMPTY STATE WIDGET
// Shows when data is empty
// ============================================================================

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
