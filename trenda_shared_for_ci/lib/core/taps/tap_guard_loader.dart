// lib/core/taps/tap_guard_loader.dart
import 'package:flutter/material.dart';

/// The centred mini loader shown while a [TapGuard.run] action is in flight:
/// a small rounded card with a spinner, over a transparent barrier that
/// absorbs every touch until the action finishes. Theme-coloured, so it reads
/// in dark mode too.
class TapGuardLoader extends StatelessWidget {
  const TapGuardLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Colors.transparent),
        Center(
          child: Container(
            key: const Key('tap-guard-loader'),
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: scheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
