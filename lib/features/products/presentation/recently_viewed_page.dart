// lib/features/products/presentation/recently_viewed_page.dart
// Full-page view of recently viewed products with grid layout

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trenda_shared/models/product_model.dart';
import '../providers/recently_viewed_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../utils/price_display.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class RecentlyViewedPage extends ConsumerWidget {
  const RecentlyViewedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentlyViewed = ref.watch(recentlyViewedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently Viewed'),
        centerTitle: true,
        actions: [
          if (recentlyViewed.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showClearConfirmation(context, ref),
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: recentlyViewed.isEmpty
          ? _buildEmptyState(context)
          : _buildProductGrid(context, ref, recentlyViewed),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                size: 64,
                color: Colors.teal.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No recently viewed products',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Products you view will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Browse Products'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid(
    BuildContext context,
    WidgetRef ref,
    List<ProductModel> products,
  ) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildProductListItem(
                  context,
                  ref,
                  products[index],
                ),
              ),
              childCount: products.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductListItem(
    BuildContext context,
    WidgetRef ref,
    ProductModel product,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: product.images.isNotEmpty ? product.images.first : '',
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 60,
              height: 60,
              color: Colors.grey.shade200,
              child: const Icon(Icons.image),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 60,
              height: 60,
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image),
            ),
          ),
        ),
        title: Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.category.isNotEmpty)
              Text(
                product.category,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              '₱${product.basePrice.toStringAsFixed(0)}${pricingUnitSuffix(product.pricingUnit)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                fontSize: 15,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.add_shopping_cart,
                color: theme.colorScheme.primary,
              ),
              onPressed: () => TapGuard.run('recently_viewed.add@187', () async {
                final cart = ref.read(cartProvider.notifier);
                final added = await cart.addToCart(product);
                if (!context.mounted) return;
                // It used to announce "added" before the server had answered.
                if (!added) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          cart.lastError ?? "Couldn't add this to your cart"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              }),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.grey[600]),
              onPressed: () {
                ref
                    .read(recentlyViewedProvider.notifier)
                    .removeProduct(product.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Removed from recently viewed'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
        onTap: () => context.push('/product/${product.id}'),
      ),
    );
  }

  void _showClearConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Recently Viewed?'),
        content: const Text(
          'This will remove all products from your recently viewed list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(recentlyViewedProvider.notifier).clearAll();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Recently viewed cleared'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
