// lib/features/orders/utils/order_presentation.dart
// How an order reads to the customer: what its status is called, what tone to
// show it in, whether it can still be cancelled, and how old it is.
//
// Each of the three order cards used to carry its own switch over the status
// string, so the same order could be named differently depending on which tab
// it appeared in — and a status one card knew about fell through another's
// default and was printed as the raw backend token ('out_for_delivery').
// Widget-free so the wording can be tested.

import 'package:flutter/foundation.dart';
import 'package:trenda_shared/core/timezone.dart';

/// The meaning of a status, so the widget layer picks the colour. Keeping the
/// tone semantic rather than naming a colour lets both themes style it.
enum OrderTone {
  /// Nothing to do yet — waiting on the shop.
  waiting,

  /// Underway.
  inProgress,

  /// On its way to the door.
  arriving,

  /// Finished well.
  done,

  /// Finished badly, or undone.
  stopped,
}

@immutable
class OrderStatusView {
  final String label;
  final OrderTone tone;

  const OrderStatusView(this.label, this.tone);
}

/// Every status the customer app can receive, named in plain words.
///
/// Unknown statuses are title-cased rather than shown raw, so a backend status
/// this build has not seen still reads as English.
OrderStatusView orderStatusView(String status) {
  switch (status.toLowerCase().trim()) {
    case 'pending':
      return const OrderStatusView('Awaiting confirmation', OrderTone.waiting);
    case 'confirmed':
      return const OrderStatusView('Confirmed', OrderTone.inProgress);
    case 'waiting_for_batch':
      return const OrderStatusView('Waiting for batch', OrderTone.waiting);
    case 'batch_ready':
      return const OrderStatusView('Batch ready', OrderTone.inProgress);
    case 'processing':
      return const OrderStatusView('Being prepared', OrderTone.inProgress);
    case 'ready_to_ship':
      return const OrderStatusView('Ready for pickup', OrderTone.inProgress);
    case 'assigned_to_rider':
      return const OrderStatusView('Rider assigned', OrderTone.inProgress);
    case 'shipped':
      return const OrderStatusView('Handed to rider', OrderTone.inProgress);
    case 'pickup_started':
      return const OrderStatusView('Rider picking up', OrderTone.inProgress);
    case 'out_for_delivery':
      return const OrderStatusView('Out for delivery', OrderTone.arriving);
    case 'arriving_at_customer':
      return const OrderStatusView('Arriving soon', OrderTone.arriving);
    case 'delivered':
      return const OrderStatusView('Delivered', OrderTone.done);
    case 'completed':
      return const OrderStatusView('Completed', OrderTone.done);
    case 'cancelled':
      return const OrderStatusView('Cancelled', OrderTone.stopped);
    case 'returned':
      return const OrderStatusView('Returned', OrderTone.stopped);
    case 'refunded':
      return const OrderStatusView('Refunded', OrderTone.stopped);
    case 'failed':
      return const OrderStatusView('Delivery failed', OrderTone.stopped);
    // Delivery exceptions: the order is not over — someone is acting on it.
    case 'delivery_failed':
      return const OrderStatusView('Delivery attempt failed', OrderTone.waiting);
    case 'delivery_refused':
      return const OrderStatusView('Delivery refused', OrderTone.waiting);
    case 'pending_address_verification':
      return const OrderStatusView('Checking your address', OrderTone.waiting);
    case 'rescheduled':
      return const OrderStatusView('Delivery rescheduled', OrderTone.waiting);
    case 'returning_to_vendor':
    case 'return_to_vendor':
      return const OrderStatusView('Returning to shop', OrderTone.waiting);
    case 'awaiting_replacement':
      return const OrderStatusView('Awaiting replacement', OrderTone.waiting);
    default:
      return OrderStatusView(titleCaseStatus(status), OrderTone.inProgress);
  }
}

/// 'out_for_delivery' -> 'Out for delivery'.
String titleCaseStatus(String status) {
  final cleaned = status.trim().replaceAll('_', ' ');
  if (cleaned.isEmpty) return 'Unknown';
  return cleaned[0].toUpperCase() + cleaned.substring(1).toLowerCase();
}

/// A customer may only call off an order the shop has not started moving.
/// Once a rider is involved it is a cancellation request, not a self-service
/// action, so the button is not offered.
bool canCancelOrder(String status) =>
    const {'pending', 'confirmed'}.contains(status.toLowerCase().trim());

/// Which My-orders tab an order belongs in.
enum OrderBucket { active, done, cancelled }

/// Finished well — the Done tab.
const kDoneOrderStatuses = ['delivered', 'completed'];

/// Finished badly, or undone — the Cancelled tab. ('returned' is not a backend
/// status today; kept so an order carrying it is never lost.)
const kCancelledOrderStatuses = ['cancelled', 'returned', 'refunded', 'failed'];

/// The tab an order sits in. Everything not Done or Cancelled is ACTIVE —
/// including a status this build has never heard of, which is far more likely in
/// progress than over; showing it somewhere beats showing it nowhere.
///
/// ⚠️ Deliberately defined by the two TERMINAL lists, never by a list of active
/// statuses. The tabs used to ask the server for a hand-kept list of active
/// statuses, and `assigned_to_rider`, the Pasabay hold (`waiting_for_batch`,
/// `batch_ready`) and every delivery exception were missing from it — a Pasabay
/// order vanished from My orders the moment it was placed.
OrderBucket orderBucket(String status) {
  final s = status.toLowerCase().trim();
  if (kDoneOrderStatuses.contains(s)) return OrderBucket.done;
  if (kCancelledOrderStatuses.contains(s)) return OrderBucket.cancelled;
  return OrderBucket.active;
}

/// When an order is over, one way or another.
bool isTerminalOrder(String status) =>
    orderBucket(status) != OrderBucket.active;

/// How old an order is, in the words a person would use.
///
/// [now] is injectable so the wording can be tested without waiting for a
/// clock. Replaces two different inline formatters, one of which printed an
/// unpadded '3/9/2026 9:5'.
String formatOrderDate(DateTime? date, {DateTime? now}) {
  if (date == null) return '';
  date = TrendaTimezone.toLocal(date);
  final current = TrendaTimezone.toLocal(now ?? DateTime.now());
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(current.year, current.month, current.day);
  final dayDiff = today.difference(day).inDays;

  final time = '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  if (dayDiff == 0) return 'Today, $time';
  if (dayDiff == 1) return 'Yesterday, $time';
  if (dayDiff > 1 && dayDiff < 7) return '$dayDiff days ago';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final monthName = months[date.month - 1];
  // A future-dated order (clock skew) still reads sensibly.
  return date.year == current.year
      ? '$monthName ${date.day}, $time'
      : '$monthName ${date.day}, ${date.year}';
}

/// '3 items' — what the card says it is carrying.
String orderItemCountLabel(int lineCount) =>
    lineCount == 1 ? '1 item' : '$lineCount items';

// ===========================================================================
// TIMELINE
// ===========================================================================

/// The stages of the happy path, in order.
enum OrderStage {
  placed,
  confirmed,
  processing,
  readyToShip,
  riderAssigned,
  outForDelivery,
  arriving,
  delivered,
}

/// Which stage a raw status represents, or null when the status is not a point
/// on the happy path (a cancellation, return, refund or failure).
OrderStage? stageForStatus(String status) {
  switch (status.toLowerCase().trim()) {
    case 'pending':
      return OrderStage.placed;
    case 'confirmed':
    case 'waiting_for_batch':
    case 'batch_ready':
      return OrderStage.confirmed;
    case 'processing':
      return OrderStage.processing;
    case 'ready_to_ship':
      return OrderStage.readyToShip;
    case 'assigned_to_rider':
    case 'shipped':
    case 'pickup_started':
      return OrderStage.riderAssigned;
    case 'out_for_delivery':
      return OrderStage.outForDelivery;
    case 'arriving_at_customer':
      return OrderStage.arriving;
    case 'delivered':
    case 'completed':
      return OrderStage.delivered;
    default:
      return null;
  }
}

@immutable
class OrderStageState {
  final OrderStage stage;

  /// This stage happened.
  final bool completed;

  /// The order is sitting here right now.
  final bool current;

  const OrderStageState({
    required this.stage,
    required this.completed,
    required this.current,
  });
}

/// The state of every stage on the timeline.
///
/// ⚠️ A STOPPED order does not get a completed timeline. The page used to
/// decide each step with tests like `!['pending','confirmed','processing']
/// .contains(status)`, and 'cancelled' is in none of those lists — so an order
/// cancelled while still pending rendered "Ready to Ship", "Rider Assigned"
/// and "Out for Delivery" as DONE, claiming a history that never happened.
///
/// For a stopped order the stages actually reached are read from
/// [history] (the order's statusHistory). With no history nothing beyond
/// "placed" is claimed, because nothing can be proven.
List<OrderStageState> orderStageStates({
  required String status,
  List<String> history = const [],
}) {
  final current = stageForStatus(status);

  if (current != null) {
    return [
      for (final stage in OrderStage.values)
        OrderStageState(
          stage: stage,
          completed: stage.index < current.index ||
              (stage == current && current == OrderStage.delivered),
          current: stage == current,
        ),
    ];
  }

  // Stopped: only what the history can vouch for.
  final reached = <OrderStage>{OrderStage.placed};
  for (final entry in history) {
    final stage = stageForStatus(entry);
    if (stage != null) reached.add(stage);
  }
  final furthest = reached.fold<int>(
    0,
    (max, stage) => stage.index > max ? stage.index : max,
  );

  return [
    for (final stage in OrderStage.values)
      OrderStageState(
        stage: stage,
        completed: stage.index <= furthest,
        current: false,
      ),
  ];
}
