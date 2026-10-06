// lib/features/cart/providers/cart_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_frontend/features/auth/data/providers.dart'
    show currentUidProvider;
import 'package:trenda_shared/models/order_model.dart';
import 'package:trenda_shared/models/product_model.dart';
import 'package:trenda_shared/core/config.dart';
import '../data/cart_repository.dart';
import '../models/cart_model.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(baseUrl: AppConfig.backendBaseUrl);
});

/// Cart State Provider
final cartProvider = StateNotifierProvider<CartNotifier, AsyncValue<CartModel>>(
  (ref) {
    // Rebuilt (and reloaded) on every account change — see currentUidProvider.
    ref.watch(currentUidProvider);
    return CartNotifier(ref.read(cartRepositoryProvider));
  },
);

/// Cart line ids the shopper has UNticked — they stay in the cart but are left
/// out of checkout. Stored as the excluded set so new lines start ticked.
final deselectedCartItemsProvider = StateProvider<Set<String>>((ref) {
  ref.watch(currentUidProvider);
  return const <String>{};
});

/// The cart as checkout sees it: only the ticked lines, subtotal recomputed.
final checkoutCartProvider = Provider<AsyncValue<CartModel>>((ref) {
  final excluded = ref.watch(deselectedCartItemsProvider);
  return ref.watch(cartProvider).whenData((cart) {
    if (excluded.isEmpty) return cart;
    final items = cart.items.where((i) => !excluded.contains(i.id)).toList();
    return CartModel(
      items: items,
      subtotal: items.fold<double>(0, (s, i) => s + i.subtotal),
      itemCount: items.length,
    );
  });
});

/// Every write returns `true` on success and `false` on failure — it never
/// throws, and on failure the cart is LEFT AS IT WAS, with the reason in
/// [lastError] (the server's own words, e.g. "Insufficient stock. Available: 2").
///
/// ⚠️ Before, the repository ignored refusals, so every failed add reported
/// "Added to cart"; and when a write did fail, the notifier replaced the whole
/// cart with an error state, dropping the shopper's basket off the screen for a
/// problem with one line. Callers show [lastError] when a write returns false.
class CartNotifier extends StateNotifier<AsyncValue<CartModel>> {
  final CartRepository _repository;

  CartNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadCart();
  }

  /// Why the last write failed, or null after a success.
  String? lastError;

  /// Load cart from backend. [silent] keeps the current cart on screen while
  /// refreshing (used after a write, so the page does not flash a spinner).
  Future<void> loadCart({bool silent = false}) async {
    if (!silent || !state.hasValue) state = const AsyncValue.loading();
    try {
      final cart = await _repository.getCart();
      if (mounted) state = AsyncValue.data(cart);
    } catch (e, stack) {
      if (mounted) state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> _write(Future<void> Function() write) async {
    try {
      await write();
      lastError = null;
      await loadCart(silent: true);
      return true;
    } catch (e) {
      lastError = e is CartException
          ? e.message
          : 'Something went wrong. Please try again.';
      return false;
    }
  }

  /// Add product to cart.
  Future<bool> addToCart(ProductModel product,
          {int quantity = 1, String? variantId}) =>
      _write(() => _repository.addToCart(
            productId: product.id,
            quantity: quantity,
            variantId:
                variantId, // ✅ Pass variant ID for products with variants
          ));

  /// Add bundle to cart (the same endpoint resolves a bundle id).
  Future<bool> addBundleToCart(String bundleId, {int quantity = 1}) => _write(
      () => _repository.addToCart(productId: bundleId, quantity: quantity));

  /// Update cart item quantity; below 1 removes the line.
  Future<bool> updateQuantity(String itemId, int quantity) {
    if (quantity < 1) return removeFromCart(itemId);
    return _write(() => _repository.updateCartItem(itemId, quantity));
  }

  /// Remove item from cart.
  Future<bool> removeFromCart(String itemId) =>
      _write(() => _repository.removeFromCart(itemId));

  /// Clear entire cart.
  Future<bool> clearCart() => _write(_repository.clearCart);

  /// Remove several lines (e.g. the ones just checked out), one reload at the end.
  Future<bool> removeItems(Iterable<String> itemIds) => _write(() async {
        for (final id in itemIds) {
          await _repository.removeFromCart(id);
        }
      });

  /// Reorder - add all items from a previous order to cart. A partial reorder
  /// returns false with [lastError] naming how many items did not make it; the
  /// ones that did are in the cart (it is reloaded either way).
  ///
  /// ⚠️ Typed, not `List<dynamic>`: reading `item.variantId` off a dynamic
  /// compiled fine and threw NoSuchMethodError on every tap while the field
  /// did not exist on [OrderItem].
  Future<bool> reorderFromOrder(List<OrderItem> orderItems) async {
    final items = orderItems
        .map((item) => {
              'productId': item.productId,
              'quantity': item.quantity,
              'variantId': item.variantId,
            })
        .toList();
    final ok = await _write(() => _repository.addItemsFromOrder(items));
    if (!ok) await loadCart(silent: true);
    return ok;
  }
}
