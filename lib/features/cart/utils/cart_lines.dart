// lib/features/cart/utils/cart_lines.dart
// What is wrong with a cart line, decided in one place.
//
// Stock can fall and a shop can close between adding an item and opening the
// cart. The cart used to show none of it — the customer only found out when
// checkout refused them. These statuses let the basket say so up front.

import '../../stores/widgets/closed_store_dialog.dart';
import '../models/cart_model.dart';

enum CartLineIssue {
  /// Fine to order.
  none,

  /// The shop has none of this left.
  outOfStock,

  /// Fewer left than the quantity in the cart.
  notEnoughStock,

  /// The shop is closed and is not taking advance orders.
  storeClosed,

  /// The shop is closed but will accept the order for later.
  advanceOrder,
}

class CartLineStatus {
  final CartLineIssue issue;

  /// Units the shop can actually supply, for [CartLineIssue.notEnoughStock].
  final int available;

  const CartLineStatus(this.issue, {this.available = 0});

  /// Whether checkout will refuse this line. An advance order is a warning,
  /// not a blocker — the shop has opted in to taking it.
  bool get blocksCheckout =>
      issue == CartLineIssue.outOfStock ||
      issue == CartLineIssue.notEnoughStock ||
      issue == CartLineIssue.storeClosed;

  bool get isFine => issue == CartLineIssue.none;
}

/// Stock problems outrank shop hours: a closed shop can reopen, but an item it
/// does not have cannot be ordered whatever the hours say.
CartLineStatus cartLineStatus(CartItem item) {
  final stock = item.stock;
  if (stock <= 0) return const CartLineStatus(CartLineIssue.outOfStock);
  if (item.quantity > stock) {
    return CartLineStatus(CartLineIssue.notEnoughStock, available: stock);
  }

  switch (closedStoreAction(
    isOpen: item.storeStatus?.isOpen,
    canOrder: item.storeStatus?.canOrder,
  )) {
    case ClosedStoreAction.blocked:
      return const CartLineStatus(CartLineIssue.storeClosed);
    case ClosedStoreAction.advanceOrder:
      return const CartLineStatus(CartLineIssue.advanceOrder);
    case ClosedStoreAction.allowed:
      return const CartLineStatus(CartLineIssue.none);
  }
}

/// Lines checkout will refuse.
List<CartItem> blockedLines(List<CartItem> items) =>
    items.where((i) => cartLineStatus(i).blocksCheckout).toList();

/// One sentence naming what has to be sorted out before checkout, or null when
/// the basket is good to go.
String? cartBlockerSummary(List<CartItem> items) {
  final blocked = blockedLines(items);
  if (blocked.isEmpty) return null;

  final n = blocked.length;
  final noun = n == 1 ? 'item needs' : 'items need';
  return '$n $noun your attention before checkout';
}

/// What the customer is told about a line, and what to do about it.
({String label, String? action}) cartLineMessage(CartLineStatus status) {
  switch (status.issue) {
    case CartLineIssue.outOfStock:
      return (label: 'Out of stock', action: 'Remove');
    case CartLineIssue.notEnoughStock:
      return (
        label: status.available == 1
            ? 'Only 1 left'
            : 'Only ${status.available} left',
        action: 'Update',
      );
    case CartLineIssue.storeClosed:
      return (label: 'Shop closed — not taking orders', action: null);
    case CartLineIssue.advanceOrder:
      return (label: 'Shop closed — delivered when it reopens', action: null);
    case CartLineIssue.none:
      return (label: '', action: null);
  }
}
