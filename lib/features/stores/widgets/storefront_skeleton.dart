// lib/features/stores/widgets/storefront_skeleton.dart
// Loading state for the stores street: shopfronts under construction hoarding.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class StorefrontSkeleton extends StatelessWidget {
  final bool tall;

  const StorefrontSkeleton({super.key, this.tall = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final base = dark ? const Color(0xFF2A313B) : const Color(0xFFE9EBEF);
    final highlight = dark ? const Color(0xFF3A424E) : const Color(0xFFF6F7F9);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: tall ? 178 : 138, color: base),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(base, width: 190, height: 11),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _bar(base, width: 54, height: 11),
                      const SizedBox(width: 14),
                      _bar(base, width: 64, height: 11),
                      const Spacer(),
                      _bar(base, width: 80, height: 11),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(Color color, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}
