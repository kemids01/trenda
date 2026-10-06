// lib/features/core/widgets/skeleton_loader.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable skeleton loader widget for loading states
class SkeletonLoader extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height = 20,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Product card skeleton
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          const SkeletonLoader(
            width: double.infinity,
            height: 150,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title skeleton
                const SkeletonLoader(width: double.infinity, height: 16),
                const SizedBox(height: 8),
                // Price skeleton
                const SkeletonLoader(width: 80, height: 20),
                const SizedBox(height: 8),
                // Rating skeleton
                Row(
                  children: [
                    const SkeletonLoader(width: 60, height: 14),
                    const Spacer(),
                    const SkeletonLoader(width: 50, height: 14),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Order card skeleton
class OrderCardSkeleton extends StatelessWidget {
  const OrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SkeletonLoader(width: 120, height: 20),
                const SkeletonLoader(width: 80, height: 24),
              ],
            ),
            const SizedBox(height: 8),
            const SkeletonLoader(width: 150, height: 14),
            const SizedBox(height: 16),
            // Items
            Row(
              children: [
                const SkeletonLoader(width: 50, height: 50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonLoader(width: double.infinity, height: 14),
                      const SizedBox(height: 4),
                      const SkeletonLoader(width: 60, height: 12),
                    ],
                  ),
                ),
                const SkeletonLoader(width: 60, height: 16),
              ],
            ),
            const SizedBox(height: 16),
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SkeletonLoader(width: 100, height: 24),
                const SkeletonLoader(width: 120, height: 36),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Cart item skeleton
class CartItemSkeleton extends StatelessWidget {
  const CartItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const SkeletonLoader(
              width: 80,
              height: 80,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonLoader(width: double.infinity, height: 14),
                  const SizedBox(height: 4),
                  const SkeletonLoader(width: 80, height: 18),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SkeletonLoader(width: 100, height: 32),
                      const Spacer(),
                      const SkeletonLoader(width: 32, height: 32),
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
}

/// List skeleton with shimmer effect
class ListSkeleton extends StatelessWidget {
  final Widget child;
  final int itemCount;

  const ListSkeleton({
    super.key,
    required this.child,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => child,
    );
  }
}

/// Grid skeleton with shimmer effect
class GridSkeleton extends StatelessWidget {
  final Widget child;
  final int itemCount;

  const GridSkeleton({
    super.key,
    required this.child,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: itemCount,
      itemBuilder: (_, __) => child,
    );
  }
}
