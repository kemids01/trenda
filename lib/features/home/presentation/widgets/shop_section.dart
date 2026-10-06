// lib/features/home/presentation/widgets/shop_section.dart
// Shared furniture for the home shelves: a section header with an accent rule,
// a horizontal rail, and the shimmer placeholders shown while a shelf loads.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A merchandising shelf header: accent bar, title, optional subtitle, and a
/// "See all" affordance that only appears when there is somewhere to go.
class ShopSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color accent;
  final VoidCallback? onSeeAll;

  const ShopSectionHeader({
    super.key,
    required this.title,
    required this.accent,
    this.subtitle,
    this.icon,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 26,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 15, color: accent),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                visualDensity: VisualDensity.compact,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See all',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 17),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal shelf of fixed-width cards.
class ShopRail extends StatelessWidget {
  final int itemCount;
  final double itemWidth;
  final double height;
  final Widget Function(BuildContext, int) itemBuilder;

  const ShopRail({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.itemWidth = 158,
    this.height = 278,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        clipBehavior: Clip.none,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => SizedBox(
          width: itemWidth,
          child: itemBuilder(context, i),
        ),
      ),
    );
  }
}

/// Shimmer stand-ins so a loading shelf holds its shape instead of collapsing
/// to a spinner and shoving the page around when the data lands.
class ShopRailSkeleton extends StatelessWidget {
  final int count;
  final double itemWidth;
  final double height;

  const ShopRailSkeleton({
    super.key,
    this.count = 3,
    this.itemWidth = 158,
    this.height = 278,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF2A313B) : const Color(0xFFE9EBEF);
    final highlight = dark ? const Color(0xFF3A424E) : const Color(0xFFF6F7F9);

    return SizedBox(
      height: height,
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: count,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, __) => Container(
            width: itemWidth,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
