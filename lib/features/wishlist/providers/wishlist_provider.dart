// lib/features/wishlist/providers/wishlist_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_frontend/features/auth/data/providers.dart' show currentUidProvider;
import 'package:trenda_shared/models/product_model.dart';
import 'package:trenda_shared/core/config.dart';
import '../data/wishlist_repository.dart';
import 'package:trenda_shared/core/taps/taps.dart';

/// Repository provider
final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository(baseUrl: AppConfig.backendBaseUrl);
});

/// Wishlist state provider
final wishlistProvider =
    StateNotifierProvider<WishlistNotifier, AsyncValue<List<ProductModel>>>(
  (ref) {
    // Rebuilt (and reloaded) on every account change — see currentUidProvider.
    ref.watch(currentUidProvider);
    return WishlistNotifier(ref.read(wishlistRepositoryProvider));
  },
);

class WishlistNotifier extends StateNotifier<AsyncValue<List<ProductModel>>> {
  final WishlistRepository _repository;

  WishlistNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadWishlist();
  }

  /// Load wishlist from backend
  Future<void> loadWishlist() async {
    state = const AsyncValue.loading();
    try {
      final wishlist = await _repository.getWishlist();
      state = AsyncValue.data(wishlist);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Add product to wishlist
  Future<bool> addToWishlist(ProductModel product) async {
    try {
      await _repository.addToWishlist(product.id);

      // Optimistic update
      state.whenData((wishlist) {
        if (!wishlist.any((p) => p.id == product.id)) {
          state = AsyncValue.data([...wishlist, product]);
        }
      });

      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Remove product from wishlist
  Future<bool> removeFromWishlist(String productId) async {
    try {
      await _repository.removeFromWishlist(productId);
    } catch (e) {
      // Ignore 404 errors - product may have been deleted from database
      // Still proceed to remove from local state
      debugPrint('Wishlist remove error (ignoring): $e');
    }

    // Always update local state to remove the item
    state.whenData((wishlist) {
      state = AsyncValue.data(
        wishlist.where((p) => p.id != productId).toList(),
      );
    });

    return true;
  }

  /// Toggle wishlist (add if not in wishlist, remove if in wishlist)
  Future<bool> toggleWishlist(ProductModel product) async {
    final inWishlist = isInWishlist(product.id);

    if (inWishlist) {
      return await removeFromWishlist(product.id);
    } else {
      return await addToWishlist(product);
    }
  }

  /// Move item to cart and remove from wishlist
  Future<bool> moveToCart(String productId) async {
    try {
      await _repository.moveToCart(productId);

      // Remove from local state
      state.whenData((wishlist) {
        state = AsyncValue.data(
          wishlist.where((p) => p.id != productId).toList(),
        );
      });

      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Clear all wishlist items
  Future<bool> clearWishlist() async {
    try {
      // Remove all items individually
      final productIds = state.when(
        data: (wishlist) => wishlist.map((p) => p.id).toList(),
        loading: () => <String>[],
        error: (_, __) => <String>[],
      );

      for (final productId in productIds) {
        await _repository.removeFromWishlist(productId);
      }

      state = const AsyncValue.data([]);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Check if product is in wishlist
  bool isInWishlist(String productId) {
    return state.when(
      data: (wishlist) => wishlist.any((p) => p.id == productId),
      loading: () => false,
      error: (_, __) => false,
    );
  }

  /// Get wishlist count
  int get count => state.when(
        data: (wishlist) => wishlist.length,
        loading: () => 0,
        error: (_, __) => 0,
      );
}

/// Provider to check if a specific product is in wishlist
final isProductInWishlistProvider =
    Provider.family<bool, String>((ref, productId) {
  return ref.watch(wishlistProvider.notifier).isInWishlist(productId);
});

/// Provider for wishlist count (for badges)
final wishlistCountProvider = Provider<int>((ref) {
  return ref.watch(wishlistProvider.notifier).count;
});

/// Helper widget for wishlist button
class WishlistButton extends ConsumerWidget {
  final ProductModel product;
  final bool showText;

  const WishlistButton({
    super.key,
    required this.product,
    this.showText = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInWishlist = ref.watch(isProductInWishlistProvider(product.id));

    if (showText) {
      return OutlinedButton.icon(
        icon: Icon(
          isInWishlist ? Icons.favorite : Icons.favorite_border,
          color: isInWishlist ? Colors.red : null,
        ),
        label: Text(isInWishlist ? 'In Wishlist' : 'Add to Wishlist'),
        onPressed: () => TapGuard.run('wishlist_provider.toggleWishlist', () => _toggleWishlist(context, ref, isInWishlist)),
      );
    }

    return IconButton(
      icon: Icon(
        isInWishlist ? Icons.favorite : Icons.favorite_border,
        color: isInWishlist ? Colors.red : null,
      ),
      onPressed: () => TapGuard.run('wishlist_provider.toggleWishlist', () => _toggleWishlist(context, ref, isInWishlist)),
    );
  }

  Future<void> _toggleWishlist(
      BuildContext context, WidgetRef ref, bool isInWishlist) async {
    final success =
        await ref.read(wishlistProvider.notifier).toggleWishlist(product);

    if (context.mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isInWishlist ? 'Removed from wishlist' : 'Added to wishlist ❤️',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
