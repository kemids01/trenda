// lib/features/stores/utils/advance_order_notice.dart
// What the shopper is told when a store in their order is CLOSED but still
// taking orders: the order is placed now, and the store accepts and processes
// it when it opens. One wording, used by checkout, the confirmation page and
// the order details, so the three never disagree.
import 'package:trenda_shared/models/order_model.dart';
import '../../cart/models/cart_model.dart';
import '../../cart/utils/cart_lines.dart';
import '../widgets/closed_store_dialog.dart' show reopeningLine;

/// A closed store in the cart, with when it next opens (null when unknown).
typedef ClosedStoreInCart = ({String name, String? reopening});

/// The closed-but-ordering stores in [items], once each, in cart order.
List<ClosedStoreInCart> advanceOrderStores(List<CartItem> items) {
  final seen = <String>{};
  final out = <ClosedStoreInCart>[];
  for (final item in items) {
    if (cartLineStatus(item).issue != CartLineIssue.advanceOrder) continue;
    final name = (item.storeName ?? '').trim();
    final key = name.isEmpty ? 'this store' : name;
    if (!seen.add(key)) continue;
    final st = item.storeStatus;
    out.add((
      name: key,
      reopening: reopeningLine(
        day: st?.nextOpenDay,
        time: st?.nextOpenAt,
        legacy: st?.nextOpenTime,
      ),
    ));
  }
  return out;
}

/// The checkout notice, or null when every store is open.
String? advanceOrderMessage(List<ClosedStoreInCart> stores) {
  if (stores.isEmpty) return null;
  if (stores.length == 1) {
    final s = stores.first;
    final when = s.reopening == null ? '' : ' (${s.reopening})';
    return '${s.name} is closed right now. You can still order — the store '
        'will accept and process your order when it opens$when.';
  }
  return '${stores.length} stores in your order are closed right now. You can '
      'still order — each store will accept and process its items when it opens.';
}

/// Whether the order screens should show the "waiting for the store" note:
/// placed while the store was closed, and not yet accepted.
bool isAwaitingStoreOpening(OrderModel order) =>
    order.advanceOrder != null && order.status.toLowerCase() == 'pending';

/// The order-screen note for an order placed while the store was closed.
String awaitingStoreMessage(AdvanceOrderInfo info) {
  final when = reopeningLine(day: info.nextOpenDay, time: info.nextOpenAt);
  return 'The store was closed when you ordered. It will accept and process '
      'your order when it opens${when == null ? '' : ' ($when)'}.';
}
