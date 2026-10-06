// trenda_shared/lib/widgets/connectivity_banner.dart
// ============================================================================
// CONNECTIVITY BANNER
// Shows offline status and syncs when connection is restored
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/offline_queue.dart';
import '../core/logger.dart';

/// Wraps child with a connectivity status banner
class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  final VoidCallback? onConnectionRestored;

  const ConnectivityBanner({
    super.key,
    required this.child,
    this.onConnectionRestored,
  });

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isOnline = true;
  bool _showBanner = false;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<double>(begin: -1, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _checkConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _onConnectivityChanged(result);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline =
        results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);

    if (!_isOnline) {
      // Going offline
      setState(() => _showBanner = true);
      _animationController.forward();
      AppLogger.warning('Device went offline', 'Connectivity');
    } else if (!wasOnline && _isOnline) {
      // Coming back online
      AppLogger.info('Device back online', 'Connectivity');
      _syncData();

      // Hide banner after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isOnline) {
          _animationController.reverse().then((_) {
            if (mounted) setState(() => _showBanner = false);
          });
        }
      });
    }
  }

  Future<void> _syncData() async {
    if (OfflineQueue.hasPendingActions) {
      AppLogger.info(
        'Syncing ${OfflineQueue.pendingCount} pending actions',
        'Connectivity',
      );
      await OfflineQueue.processQueue();
    }
    widget.onConnectionRestored?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_showBanner)
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value * 50),
                child: child,
              );
            },
            child: _buildBanner(context),
          ),
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _buildBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: _isOnline ? Colors.green : colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isOnline ? Icons.cloud_done : Icons.cloud_off,
                size: 16,
                color: _isOnline ? Colors.white : colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Text(
                _isOnline
                    ? 'Back online! Syncing...'
                    : 'You\'re offline. Changes will sync when connected.',
                style: TextStyle(
                  fontSize: 13,
                  color: _isOnline
                      ? Colors.white
                      : colorScheme.onErrorContainer,
                ),
              ),
              if (!_isOnline && OfflineQueue.hasPendingActions) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${OfflineQueue.pendingCount}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple connectivity status indicator
class ConnectivityIndicator extends StatefulWidget {
  const ConnectivityIndicator({super.key});

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  bool _isOnline = true;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      setState(() {
        _isOnline =
            results.isNotEmpty &&
            results.any((r) => r != ConnectivityResult.none);
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline =
          result.isNotEmpty && result.any((r) => r != ConnectivityResult.none);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline) return const SizedBox.shrink();

    return Tooltip(
      message: 'You\'re offline',
      child: Icon(
        Icons.cloud_off,
        size: 20,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
