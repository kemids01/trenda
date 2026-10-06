// lib/features/wishlist/providers/presentation/wishlist_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trenda_shared/models/product_model.dart';
import '../wishlist_provider.dart';
import '../../../../design_system/design_system.dart';
import 'package:trenda_frontend/features/products/utils/price_display.dart';

class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistAsync = ref.watch(wishlistProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wishlist'),
        actions: [
          wishlistAsync.maybeWhen(
            data: (items) => items.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _showClearDialog(context, ref),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: wishlistAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border,
                      size: 80, color: AppColors.borderDark),
                  AppSpacing.verticalMD,
                  Text(
                    'Your wishlist is empty',
                    style: AppTypography.titleMedium,
                  ),
                  AppSpacing.verticalXS,
                  Text(
                    'Add items you love to your wishlist',
                    style: AppTypography.asSecondary(AppTypography.bodyMedium),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(wishlistProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.separated(
              padding: AppSpacing.paddingMD,
              itemCount: products.length,
              separatorBuilder: (_, __) => AppSpacing.verticalSM,
              itemBuilder: (context, index) {
                final product = products[index];
                return _WishlistItem(product: product);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load wishlist'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(wishlistProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Wishlist'),
        content: const Text('Remove all items from your wishlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(wishlistProvider.notifier).clearWishlist();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _WishlistItem extends ConsumerWidget {
  final ProductModel product;

  const _WishlistItem({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingSM,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppSpacing.borderRadiusMD,
              child: CachedNetworkImage(
                imageUrl: product.images.isNotEmpty ? product.images.first : '',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 80,
                  height: 80,
                  color: AppColors.surfaceVariant,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 80,
                  height: 80,
                  color: AppColors.surfaceDim,
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
            AppSpacing.horizontalSM,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTypography.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppSpacing.verticalXXS,
                  Text(
                    '₱${product.basePrice.toStringAsFixed(2)}${pricingUnitSuffix(product.pricingUnit)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.productPriceSmall,
                  ),
                  AppSpacing.verticalXXS,
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Text(
                        product.averageRating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Spacer(),
                      if (product.isOutOfStock)
                        Text(
                          'Out of Stock',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else if (product.isLowStock)
                        Text(
                          'Low Stock',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    ref
                        .read(wishlistProvider.notifier)
                        .removeFromWishlist(product.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Removed from wishlist')),
                    );
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: product.isOutOfStock
                      ? null
                      : () {
                          // Add to cart
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Added to cart')),
                          );
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child:
                      const Text('Add to Cart', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
