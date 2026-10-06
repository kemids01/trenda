// lib/features/orders/presentation/orders_page.dart
// ============================================================================
// MY ORDERS PAGE - Simplified with Active Orders & Completed tabs
// Shows order status progression: Pending → Confirmed → Processing → In Transit
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_shared/models/order_model.dart';
import '../../core/widgets/official_tag.dart';
import '../providers/orders_provider.dart';
import 'widgets/order_status_stepper.dart';
import 'widgets/order_status_badge.dart';
import '../utils/order_presentation.dart';
import '../../core/widgets/error_handler.dart';
import '../../core/providers/websocket_provider.dart';
import '../../cart/providers/cart_provider.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Setup WebSocket listener for real-time order updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setupOrderStatusRefresh(ref);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for real-time WebSocket updates and refresh orders
    ref.listen(orderRefreshTriggerProvider, (previous, next) {
      if (previous != next) {
        // Refresh order lists when any order status changes
        // The three tabs and the counts all derive from myOrdersProvider.
        ref.invalidate(myOrdersProvider);
      }
    });

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final counts = ref.watch(orderCountsProvider).valueOrNull;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF0E1116)
          : const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('My orders'),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/my-returns'),
            icon: const Icon(Icons.assignment_return_outlined, size: 17),
            label: const Text(
              'Returns',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 48,
            color: scheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: scheme.primary,
              unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.45),
              indicatorColor: scheme.primary,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                letterSpacing: 0.3,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                letterSpacing: 0.3,
              ),
              // Counts come from the provider the profile tab already uses, so
              // a shopper can see there is something waiting without opening
              // every tab.
              tabs: [
                _countedTab(
                  'Active',
                  (counts?['pending'] ?? 0) + (counts?['active'] ?? 0),
                ),
                _countedTab('Done', counts?['completed']),
                _countedTab('Cancelled', counts?['cancelled']),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ActiveOrdersList(),
          _CompletedOrdersList(),
          _CancelledOrdersList(),
        ],
      ),
    );
  }

  Widget _countedTab(String label, int? count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (count != null && count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 17),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// ACTIVE ORDERS LIST - Shows pending, confirmed, processing, in transit orders
// ============================================================================
class _ActiveOrdersList extends ConsumerWidget {
  const _ActiveOrdersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(activeOrdersProvider);

    return AsyncBuilder<List<OrderModel>>(
      asyncValue: ordersAsync,
      onRetry: () => ref.invalidate(myOrdersProvider),
      emptyMessage: 'No active orders',
      builder: (orders) {
        return RefreshIndicator(
          onRefresh: () {
            ref.invalidate(myOrdersProvider);
            return ref.refresh(activeOrdersProvider.future);
          },
          child: orders.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _ActiveOrderCard(order: order),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return OrdersEmptyState(
      icon: Icons.local_shipping_outlined,
      title: 'Nothing on its way',
      body: 'When you place an order you can follow it here.',
      actionLabel: 'Start shopping',
      onAction: () => context.go('/main'),
    );
  }
}

// ============================================================================
// COMPLETED ORDERS LIST - Shows delivered, cancelled, returned orders
// ============================================================================
class _CompletedOrdersList extends ConsumerWidget {
  const _CompletedOrdersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(completedOrdersProvider);

    return AsyncBuilder<List<OrderModel>>(
      asyncValue: ordersAsync,
      onRetry: () => ref.invalidate(myOrdersProvider),
      emptyMessage: 'No completed orders',
      builder: (orders) {
        return RefreshIndicator(
          onRefresh: () {
            ref.invalidate(myOrdersProvider);
            return ref.refresh(completedOrdersProvider.future);
          },
          child: orders.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CompletedOrderCard(order: order),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return OrdersEmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'No completed orders yet',
      body: 'Orders you have received will be kept here.',
      actionLabel: 'Browse shops',
      onAction: () => context.go('/main'),
    );
  }
}

// ============================================================================
// CANCELLED ORDERS LIST - Shows cancelled, returned, refunded orders
// ============================================================================
class _CancelledOrdersList extends ConsumerWidget {
  const _CancelledOrdersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(cancelledOrdersProvider);

    return AsyncBuilder<List<OrderModel>>(
      asyncValue: ordersAsync,
      onRetry: () => ref.invalidate(myOrdersProvider),
      emptyMessage: 'No cancelled orders',
      builder: (orders) {
        return RefreshIndicator(
          onRefresh: () {
            ref.invalidate(myOrdersProvider);
            return ref.refresh(cancelledOrdersProvider.future);
          },
          child: orders.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CancelledOrderCard(order: order),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const OrdersEmptyState(
      icon: Icons.verified_outlined,
      title: 'Nothing cancelled',
      body: 'All your orders have gone through.',
    );
  }
}

// ============================================================================
// CANCELLED ORDER CARD - Simple card for cancelled orders
// ============================================================================
class _CancelledOrderCard extends ConsumerWidget {
  final OrderModel order;

  const _CancelledOrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/orders/${order.id}'),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cancel,
                      color: Colors.red.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Order #${order.orderNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    if (order.isOfficial == true) ...[
                      const OfficialTag(compact: true, label: 'Official'),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        orderStatusView(order.status).label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '${order.items.length} items • ',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      '₱${order.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatOrderDate(order.createdAt),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                // Show cancellation info
                if (order.cancelReason != null &&
                    order.cancelReason!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 14, color: Colors.red.shade700),
                            const SizedBox(width: 6),
                            Text(
                              'Reason:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.cancelReason!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_getCancellationNote(order) != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 14, color: Colors.red.shade700),
                            const SizedBox(width: 6),
                            Text(
                              'Reason:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getCancellationNote(order)!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Show who cancelled (from status history)
                if (_getCancelledBy(order) != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Cancelled by: ${_getCancelledBy(order)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _getCancellationNote(OrderModel order) {
    // Find the cancellation entry in status history
    final cancelEntry = order.statusHistory.lastWhere(
      (h) => h.status.toLowerCase() == 'cancelled',
      orElse: () => StatusHistory(status: '', timestamp: DateTime.now()),
    );
    if (cancelEntry.status.isNotEmpty &&
        cancelEntry.note != null &&
        cancelEntry.note!.isNotEmpty) {
      return cancelEntry.note;
    }
    return null;
  }

  String? _getCancelledBy(OrderModel order) {
    // Check status history for who cancelled
    final cancelEntry = order.statusHistory.lastWhere(
      (h) => h.status.toLowerCase() == 'cancelled',
      orElse: () => StatusHistory(status: '', timestamp: DateTime.now()),
    );

    if (cancelEntry.status.isEmpty) return null;

    // The note often contains who cancelled, or we can infer from context
    final note = cancelEntry.note?.toLowerCase() ?? '';
    if (note.contains('vendor') ||
        note.contains('rejected') ||
        note.contains('store')) {
      return 'Vendor';
    } else if (note.contains('customer') ||
        note.contains('user') ||
        note.contains('by user')) {
      return 'Customer';
    } else if (note.contains('system') || note.contains('auto')) {
      return 'System';
    }
    return null;
  }

}

// ============================================================================
// ACTIVE ORDER CARD - Shows status progression stepper
// ============================================================================
class _ActiveOrderCard extends ConsumerWidget {
  final OrderModel order;

  const _ActiveOrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/orders/${order.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Order # + Date
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.shopping_bag,
                          size: 20, color: Colors.indigo.shade600),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.orderNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatOrderDate(order.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (order.isOfficial == true) ...[
                      const OfficialTag(compact: true, label: 'Official'),
                      const SizedBox(width: 8),
                    ],
                    _buildStatusBadge(context, order.status),
                  ],
                ),

                const SizedBox(height: 16),

                // Status Progress Stepper
                OrderStatusStepper(status: order.status),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Items Preview
                ...order.items.take(2).map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          // CachedNetworkImage like the rest of the app: a raw
                          // NetworkImage here had no placeholder or error
                          // builder, so a dead image URL threw instead of
                          // degrading to the fallback icon.
                          OrderItemThumb(imageUrl: item.productImage),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${item.quantity}x • ₱${item.price.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₱${(item.quantity * item.price).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )),

                if (order.items.length > 2) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${order.items.length - 2} more items',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.indigo.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Footer: Total + Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        Text(
                          '₱${order.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ],
                    ),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canCancelOrder(order.status))
                            SizedBox(
                              height: 32,
                              child: OutlinedButton(
                                onPressed: () =>
                                    _showCancelDialog(context, ref, order),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade600,
                                  side: BorderSide(color: Colors.red.shade200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  context.push('/orders/${order.id}'),
                              icon: const Icon(Icons.visibility, size: 14),
                              label: const Text('Track'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo.shade600,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) =>
      OrderStatusBadge(status: status);



  void _showCancelDialog(
      BuildContext context, WidgetRef ref, OrderModel order) {
    String? selectedReason;
    final reasons = [
      'Changed my mind',
      'Found better price elsewhere',
      'Order taking too long',
      'Ordered by mistake',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Cancel Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Are you sure you want to cancel order #${order.orderNumber}?'),
              const SizedBox(height: 16),
              const Text('Please select a reason:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              ...reasons.map((reason) => RadioListTile<String>(
                    title: Text(reason, style: const TextStyle(fontSize: 14)),
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (value) =>
                        setState(() => selectedReason = value),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Order'),
            ),
            TextButton(
              onPressed: selectedReason == null
                  ? null
                  : () => TapGuard.run('orders.performCancelOrder', () async {
                      Navigator.pop(ctx);
                      await _performCancelOrder(
                          context, ref, order, selectedReason!);
                    }),
              child: Text(
                'Cancel Order',
                style: TextStyle(
                    color: selectedReason == null ? Colors.grey : Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performCancelOrder(BuildContext context, WidgetRef ref,
      OrderModel order, String reason) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Cancelling order...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      await ref.read(orderActionsProvider).cancelOrder(order.id, reason);
      ref.invalidate(myOrdersProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to cancel: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// ============================================================================
// ORDER STATUS STEPPER - Visual progress indicator
// ============================================================================
class _CompletedOrderCard extends ConsumerWidget {
  final OrderModel order;

  const _CompletedOrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDelivered = order.status.toLowerCase() == 'delivered';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/orders/${order.id}'),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isDelivered ? Icons.check_circle : Icons.cancel,
                      color: isDelivered ? Colors.green : Colors.red.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Order #${order.orderNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    if (order.isOfficial == true) ...[
                      const OfficialTag(compact: true, label: 'Official'),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDelivered
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isDelivered ? 'Delivered' : order.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDelivered
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '${order.items.length} items • ',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      '₱${order.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (isDelivered)
                      TextButton.icon(
                        onPressed: () => TapGuard.run('orders.handleReorder', () => _handleReorder(context, ref)),
                        icon: const Icon(Icons.replay, size: 16),
                        label: const Text('Reorder'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.indigo.shade600,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleReorder(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Adding items to cart...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final cart = ref.read(cartProvider.notifier);
      final success = await cart.reorderFromOrder(order.items);
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      // A failed reorder used to show nothing at all.
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                cart.lastError ?? "Couldn't add these items to your cart"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

