// lib/features/orders/providers/orders_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_frontend/features/auth/data/providers.dart' show currentUidProvider;
import 'package:trenda_shared/data/orders_repository.dart';
import 'package:trenda_shared/models/order_model.dart';
import 'package:trenda_shared/core/logger.dart';
import 'package:trenda_shared/core/config.dart';
import '../utils/order_presentation.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(baseUrl: AppConfig.backendBaseUrl);
});

/// Fetch single order details
final orderDetailsProvider = FutureProvider.family<OrderModel?, String>(
  (ref, orderId) async {
    ref.watch(currentUidProvider);
    final repo = ref.watch(ordersRepositoryProvider);

    try {
      // Use getOrderById for customer orders (correct method)
      return await repo.getOrderById(orderId);
    } catch (e) {
      AppLogger.error('Error fetching order details', e);
      return null;
    }
  },
);

/// Order actions provider
final orderActionsProvider = Provider<OrderActions>((ref) {
  final repo = ref.watch(ordersRepositoryProvider);
  return OrderActions(repo);
});

class OrderActions {
  final OrdersRepository _repository;

  OrderActions(this._repository);

  Future<void> cancelOrder(String orderId, String reason) async {
    try {
      // Use cancelOrder method for customer orders (POST /api/orders/:id/cancel)
      await _repository.cancelOrder(orderId: orderId, reason: reason);
    } catch (e) {
      AppLogger.error('Error cancelling order', e);
      rethrow;
    }
  }

  Future<void> requestReturn(String orderId, String reason,
      {List<String>? itemIds}) async {
    try {
      await _repository.requestReturn(
        orderId: orderId,
        reason: reason,
        itemIds: itemIds,
      );
      AppLogger.info('Return requested for order $orderId', 'Orders');
    } catch (e) {
      AppLogger.error('Error requesting return', e);
      rethrow;
    }
  }

  Future<void> leaveReview(
    String orderId,
    String productId, {
    required int rating,
    required String comment,
    List<String>? photoUrls,
  }) async {
    try {
      await _repository.submitReview(
        orderId: orderId,
        productId: productId,
        rating: rating,
        comment: comment,
        photoUrls: photoUrls,
      );
      AppLogger.info('Review submitted for product $productId', 'Orders');
    } catch (e) {
      AppLogger.error('Error submitting review', e);
      rethrow;
    }
  }

  Future<void> requestRefund(
    String orderId, {
    required String reason,
    required String description,
    required String refundType,
    List<String>? itemIds,
  }) async {
    try {
      await _repository.requestRefund(
        orderId: orderId,
        reason: reason,
        description: description,
        refundType: refundType,
        itemIds: itemIds,
      );
      AppLogger.info('Refund requested for order $orderId', 'Orders');
    } catch (e) {
      AppLogger.error('Error requesting refund', e);
      rethrow;
    }
  }
}

/// How many of the customer's newest orders the My-orders tabs cover.
const kMyOrdersWindow = 100;

/// The customer's newest [kMyOrdersWindow] orders, ONE request, shared by all three
/// tabs and the badge counts.
///
/// The tabs used to ask the server once PER STATUS from a hand-kept list, and the
/// server filters by exact status — so any status missing from that list was an
/// order in NO tab. `assigned_to_rider`, the Pasabay hold (`waiting_for_batch`,
/// `batch_ready`) and every delivery exception were missing: a Pasabay order
/// vanished from My orders the moment it was placed. Fetching once and bucketing
/// with [orderBucket] (unknown → Active) makes that impossible, and turns 12
/// sequential requests into one.
///
/// Errors PROPAGATE so a tab shows Retry. They used to be swallowed into an empty
/// list, and a dead connection read as "Nothing on its way".
final myOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  ref.watch(currentUidProvider);
  final repo = ref.watch(ordersRepositoryProvider);
  final result = await repo.fetchOrders(page: 1, limit: kMyOrdersWindow);
  return [...result.orders]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

Future<List<OrderModel>> _ordersIn(Ref ref, OrderBucket bucket) async {
  final orders = await ref.watch(myOrdersProvider.future);
  return orders.where((o) => orderBucket(o.status) == bucket).toList();
}

/// Order counts for profile badges.
///
/// `pending` = still with the shop (pending/confirmed); `active` = every other
/// order that is not over. Same source and same [orderBucket] rule as the tabs,
/// so a badge can never count an order no tab shows.
final orderCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  try {
    final orders = await ref.watch(myOrdersProvider.future);

    int pendingCount = 0;
    int activeCount = 0;
    int completedCount = 0;
    int cancelledCount = 0;

    for (final order in orders) {
      final status = order.status.toLowerCase().trim();
      switch (orderBucket(status)) {
        case OrderBucket.active:
          if (status == 'pending' || status == 'confirmed') {
            pendingCount++;
          } else {
            activeCount++;
          }
        case OrderBucket.done:
          completedCount++;
        case OrderBucket.cancelled:
          cancelledCount++;
      }
    }

    return {
      'pending': pendingCount,
      'active': activeCount,
      'completed': completedCount,
      'cancelled': cancelledCount,
      'total': orders.length,
    };
  } catch (e) {
    AppLogger.error('Error fetching order counts', e);
    return {
      'pending': 0,
      'active': 0,
      'completed': 0,
      'cancelled': 0,
      'total': 0
    };
  }
});

/// Active tab — every order that is not over.
final activeOrdersProvider = FutureProvider<List<OrderModel>>(
    (ref) => _ordersIn(ref, OrderBucket.active));

/// Done tab — delivered / completed.
final completedOrdersProvider = FutureProvider<List<OrderModel>>(
    (ref) => _ordersIn(ref, OrderBucket.done));

/// Cancelled tab — cancelled, returned, refunded, failed.
final cancelledOrdersProvider = FutureProvider<List<OrderModel>>(
    (ref) => _ordersIn(ref, OrderBucket.cancelled));
