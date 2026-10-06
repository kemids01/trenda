// lib/features/products/presentation/compare_bar.dart
// Slim persistent "Compare (N)" pill. Self-hides when nothing is selected.
// Tapping opens the comparison table (/compare).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/design_system.dart';
import '../providers/comparison_provider.dart';

class CompareBar extends ConsumerWidget {
  const CompareBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(comparisonCountProvider);
    if (count == 0) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Material(
          color: AppColors.primary,
          borderRadius: AppSpacing.borderRadiusLG,
          elevation: 4,
          child: InkWell(
            borderRadius: AppSpacing.borderRadiusLG,
            onTap: () => context.push('/compare'),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.compare_arrows,
                      color: AppColors.onPrimary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Compare ($count)',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
