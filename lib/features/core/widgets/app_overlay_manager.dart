// lib/features/core/widgets/app_overlay_manager.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/providers.dart';
import '../../auth/application/state.dart'; // ✅ import the state
import '../../orders/widgets/order_status_alert_overlay.dart';

/// Global overlay: handles loading & snackbars consistently
class AppOverlayManager extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  const AppOverlayManager({
    super.key,
    required this.child,
    required this.messengerKey,
  });

  @override
  ConsumerState<AppOverlayManager> createState() => _AppOverlayManagerState();
}

class _AppOverlayManagerState extends ConsumerState<AppOverlayManager> {
  @override
  Widget build(BuildContext context) {
    // Track loading status
    final isLoading = ref.watch(
        authNotifierProvider.select((s) => s.status == AuthStatus.loading));

    // Listen to auth state and perform side effects safely
    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (next.errorMsg != null && next.errorMsg!.isNotEmpty) {
          _showSnackBar(next.errorMsg!, Colors.red);
          ref.read(authNotifierProvider.notifier).clearTransientMessages();
          return;
        }
      });
    });

    return OrderStatusAlertOverlay(
      child: Stack(
        children: [
          widget.child,
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    final messenger = widget.messengerKey.currentState;
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
