// lib/features/wishlist/presentation/wishlist_page.dart
// Full-featured wishlist page with grid view and quick actions

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trenda_shared/models/product_model.dart';
import '../providers/wishlist_provider.dart';
import '../../cart/providers/cart_provider.dart';
import 'package:trenda_frontend/features/products/utils/price_display.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistState = ref.watch(wishlistProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wishlist'),
        centerTitle: true,
        actions: [
          wishlistState.maybeWhen(
            data: (items) => items.isNotEmpty
                ? PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'clear') {
                        TapGuard.run('wishlist.showClearConfirmation', () async => _showClearConfirmation(context, ref));
                      } else if (value == 'add_all') {
                        TapGuard.run('wishlist.addAll',
                            () => _addAllToCart(context, ref, items));
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'add_all',
                        child: Row(
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('Add All to Cart'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Clear Wishlist',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: wishlistState.when(
        data: (items) {
          if (items.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildWishlistGrid(context, ref, items);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildErrorState(context, ref, e.toString()),
      ),
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
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border,
                size: 64,
                color: Colors.red.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your wishlist is empty',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save items you love by tapping the heart icon on any product',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Start Shopping'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text('Failed to load wishlist'),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(wishlistProvider.notifier).loadWishlist(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWishlistGrid(
      BuildContext context, WidgetRef ref, List<ProductModel> items) {
    return RefreshIndicator(
      onRefresh: () => ref.read(wishlistProvider.notifier).loadWishlist(),
      child: Column(
        children: [
          // Summary bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                Icon(Icons.favorite, color: Colors.red.shade400, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${items.length} ${items.length == 1 ? 'item' : 'items'} saved',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  'Total: ₱${_calculateTotal(items).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (ctx, index) {
                final product = items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: product.images.isNotEmpty
                            ? product.images.first
                            : '',
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
                        const SizedBox(height: 4),
                        Text(
                          '₱${product.basePrice.toStringAsFixed(0)}${pricingUnitSuffix(product.pricingUnit)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                            fontSize: 15,
                          ),
                        ),
                        if (product.isOutOfStock)
                          const Text(
                            'Out of Stock',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.add_shopping_cart,
                            color: product.isOutOfStock
                                ? Colors.grey
                                : Theme.of(context).primaryColor,
                          ),
                          onPressed: product.isOutOfStock
                              ? null
                              : () => TapGuard.run('wishlist.addToCart', () => _addToCart(context, ref, product)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => TapGuard.run('wishlist.removeItem', () => _removeItem(context, ref, product)),
                        ),
                      ],
                    ),
                    onTap: () => context.push('/product/${product.id}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotal(List<ProductModel> items) {
    return items.fold(0, (sum, item) => sum + item.basePrice);
  }

  Future<void> _removeItem(
      BuildContext context, WidgetRef ref, ProductModel product) async {
    final success = await ref
        .read(wishlistProvider.notifier)
        .removeFromWishlist(product.id);
    if (context.mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} removed from wishlist'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () =>
                ref.read(wishlistProvider.notifier).addToWishlist(product),
          ),
        ),
      );
    }
  }

  Future<void> _addToCart(
      BuildContext context, WidgetRef ref, ProductModel product) async {
    try {
      final cart = ref.read(cartProvider.notifier);
      if (!await cart.addToCart(product)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(cart.lastError ?? "Couldn't add this to your cart"),
                backgroundColor: Colors.red),
          );
        }
        return;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to add to cart: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addAllToCart(
      BuildContext context, WidgetRef ref, List<ProductModel> items) async {
    // Counted from the real result: this used to count every item as added,
    // including the ones the server refused.
    final cart = ref.read(cartProvider.notifier);
    int added = 0;
    for (final item in items) {
      if (await cart.addToCart(item)) added++;
    }
    final skipped = items.length - added;
    // Only a partial failure is announced; a full success says nothing.
    if (skipped > 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$added added, $skipped could not be added')),
      );
    }
  }

  void _showClearConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Wishlist?'),
        content: const Text(
            'This will remove all items from your wishlist. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => TapGuard.run('wishlist.clear@360', () async {
              Navigator.pop(ctx);
              await ref.read(wishlistProvider.notifier).clearWishlist();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Wishlist cleared')),
                );
              }
            }),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
