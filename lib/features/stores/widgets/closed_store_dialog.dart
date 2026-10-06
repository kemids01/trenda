// lib/features/stores/widgets/closed_store_dialog.dart
// Dialog shown when customer tries to order from a closed store

import 'package:flutter/material.dart';
import '../utils/storefront_style.dart';

/// The reopening line these surfaces show, e.g. 'Opens Sat · 8:00 AM'.
///
/// The backend sends the reopening slot as an OBJECT, so callers pass the day
/// and time fields; [legacy] covers the older payloads that really did carry a
/// plain string. Returns null when the store has no known reopening slot.
String? reopeningLine({String? day, String? time, String? legacy}) {
  final structured = formatReopening(day: day, time: time);
  if (structured != null) return structured;
  final l = legacy?.trim();
  return (l == null || l.isEmpty) ? null : 'Opens $l';
}

/// Whether a store with this isOpen flag should accept orders client-side.
/// null => unknown => orderable (server re-checks authoritatively).
bool isStoreOrderable(bool? isOpen) => isOpen != false;

/// What the customer app should do when adding/checking out an item, given the
/// store's open + orderable flags.
enum ClosedStoreAction {
  /// Store is open (or status unknown) — proceed normally.
  allowed,

  /// Store is closed but accepts advance orders (vendor enabled
  /// allowOrdersWhenClosed) — show the "order anyway / delivered when open" prompt.
  advanceOrder,

  /// Store is closed AND not accepting orders — block with an informational dialog.
  blocked,
}

/// Pure decision used by the add-to-cart / checkout guards.
/// - open or unknown `isOpen` => allowed
/// - closed + `canOrder == false` => blocked
/// - closed otherwise (advance orders allowed, or canOrder unknown) => advanceOrder
ClosedStoreAction closedStoreAction({bool? isOpen, bool? canOrder}) {
  if (isOpen != false) return ClosedStoreAction.allowed;
  if (canOrder == false) return ClosedStoreAction.blocked;
  return ClosedStoreAction.advanceOrder;
}

/// Informational dialog when a closed store is NOT accepting orders. No "proceed".
Future<void> showStoreClosedBlockedDialog(
  BuildContext context, {
  String? storeName,
  String? nextOpenTime,
  String? nextOpenDay,
  String? nextOpenAt,
}) {
  final reopening = reopeningLine(
    day: nextOpenDay,
    time: nextOpenAt,
    legacy: nextOpenTime,
  );
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.storefront_outlined, size: 48, color: Colors.redAccent),
      title: const Text('Store Closed'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            storeName != null
                ? '$storeName is currently closed and not accepting orders.'
                : 'This store is currently closed and not accepting orders.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          if (reopening != null) ...[
            const SizedBox(height: 12),
            Text(reopening,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ],
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Shows a confirmation dialog when a customer tries to order from a closed store.
/// Returns true if the user confirms they want to proceed with a delayed order.
/// [reopening] is the line from [reopeningLine] ('Opens Mon · 9:00 AM'), so
/// the shopper knows when the store will pick the order up.
/// [question] / [confirmLabel] override the closing prompt and the confirm button — checkout
/// asks whether to PLACE the order and wait, the product page whether to order at all.
Future<bool> showClosedStoreDialog(BuildContext context,
    {String? storeName,
    String? reopening,
    String question = 'Do you still want to proceed with your order?',
    String confirmLabel = 'Order Anyway'}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: const Icon(
        Icons.schedule,
        size: 48,
        color: Colors.orange,
      ),
      title: const Text('Store Closed'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            storeName != null
                ? '$storeName is currently closed.'
                : 'This store is currently closed.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The store will accept and process your order when it opens'
                    '${reopening == null ? '' : ' ($reopening)'}.',
                    // On the pale orange box in both themes, so dark ink.
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            question,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Widget that shows a "Store Closed" banner at the top of a store page
class ClosedStoreBanner extends StatelessWidget {
  final String? nextOpenTime;
  final String? nextOpenDay;
  final String? nextOpenAt;

  const ClosedStoreBanner({
    super.key,
    this.nextOpenTime,
    this.nextOpenDay,
    this.nextOpenAt,
  });

  @override
  Widget build(BuildContext context) {
    final reopening = reopeningLine(
      day: nextOpenDay,
      time: nextOpenAt,
      legacy: nextOpenTime,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.orange.shade300),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This store is currently closed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (reopening != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    reopening,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  'You can still browse and order for delayed delivery',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
