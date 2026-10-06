// lib/features/core/widgets/loading_listener.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/application/state.dart';
import '../../../features/auth/data/providers.dart';

/// A reusable widget that listens to [AuthState] and shows a loading overlay.
/// This keeps your UI pages clean and free from repetitive loader logic.
class LoadingListener extends ConsumerWidget {
  final Widget child;

  const LoadingListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Stack(
      children: [
        child,
        if (authState.status == AuthStatus.loading)
          Container(
            color: Colors.black.withValues(alpha: 0.4),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}
