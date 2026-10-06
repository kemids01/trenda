// lib/features/orders/presentation/order_details_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/models/order_model.dart';
import 'package:trenda_shared/core/config.dart';
import 'package:trenda_shared/services/websocket_service.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/orders_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../core/widgets/error_handler.dart';
import 'widgets/order_eta_card.dart';
import 'widgets/order_status_badge.dart';
import '../utils/order_presentation.dart';
import 'widgets/cancel_order_button.dart';
import 'widgets/rate_delivery_dialog.dart';
import 'widgets/order_tracking_map.dart';
import 'widgets/proof_of_delivery_display.dart';
import '../widgets/batch_progress_card.dart';
import '../../checkout/widgets/pasabay_guide_modal.dart';
import '../../checkout/data/pasabay_repository.dart';
import 'return_request_page.dart';
import 'refund_request_page.dart';
import '../../stores/utils/advance_order_notice.dart';
import '../../stores/widgets/advance_order_notice.dart';
import 'package:trenda_shared/core/taps/taps.dart';

/// Cached return window days from backend config
int _cachedReturnWindowDays = 7;
bool _returnWindowFetched = false;

Future<int> _getReturnWindowDays() async {
  if (_returnWindowFetched) return _cachedReturnWindowDays;
  try {
    final response = await http
        .get(
          Uri.parse('${AppConfig.backendBaseUrl}/api/config/delivery-fees'),
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final data = body['data'] ?? body;
      _cachedReturnWindowDays = (data['returnWindowDays'] ?? 7) as int;
      _returnWindowFetched = true;
    }
  } catch (_) {
    // Fallback to default 7 days
  }
  return _cachedReturnWindowDays;
}

class OrderDetailsPage extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailsPage({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends ConsumerState<OrderDetailsPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Subscribe to real-time order updates via WebSocket
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(webSocketProvider.notifier).subscribeToOrder(widget.orderId);

      // Listen for order status changes and refresh the order details
      ref.read(webSocketProvider.notifier).addEventCallback(_onWebSocketEvent);

      // Start auto-refresh timer for active orders (30 seconds)
      _startAutoRefresh();
    });
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      // Only refresh if order is still active (not delivered/cancelled)
      final orderAsync = ref.read(orderDetailsProvider(widget.orderId));
      orderAsync.whenData((order) {
        if (order != null &&
            !['delivered', 'cancelled', 'returned'].contains(order.status)) {
          ref.invalidate(orderDetailsProvider(widget.orderId));
        } else {
          // Stop auto-refresh for completed orders
          _refreshTimer?.cancel();
        }
      });
    });
  }

  void _onWebSocketEvent(String event, Map<String, dynamic> data) {
    if (event == 'order:status_changed' || event == 'order:update') {
      final eventOrderId = data['orderId'] as String?;
      if (eventOrderId == widget.orderId) {
        // Refresh order details when status changes
        ref.invalidate(orderDetailsProvider(widget.orderId));
      }
    } else if (event == 'pasabay:batch_cancelled') {
      ref.invalidate(orderDetailsProvider(widget.orderId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Your Pasabay batch has expired. Please select a fallback option.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 8),
          ),
        );
      }
    } else if (event.startsWith('pasabay:batch_')) {
      // Invalidate to refresh batch progress/status live
      ref.invalidate(orderDetailsProvider(widget.orderId));
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    // Unsubscribe from order updates when leaving the page
    ref.read(webSocketProvider.notifier).unsubscribeFromOrder(widget.orderId);
    ref.read(webSocketProvider.notifier).removeEventCallback(_onWebSocketEvent);
    super.dispose();
  }

  Future<void> _showDeliveryTypeSelectionBottomSheet(
      BuildContext context, String orderId, PasabayRepository repo) async {
    showModalBottomSheet(
      context: context,
      isDismissible: false, // Force them to choose
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            if (isLoading) {
              return const SizedBox(
                height: 250,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Updating delivery options...',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 20,
                  left: 16,
                  right: 16,
                  bottom: 20 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select New Delivery Option',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose how you want your order to be delivered now that you have left the batch:',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFF3E0),
                        child: Icon(Icons.flash_on, color: Colors.orange),
                      ),
                      title: const Text('Express Delivery',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text(
                          'Fastest delivery directly to your location'),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
                      onTap: () => TapGuard.run('order_details.change@198', () async {
                        setState(() => isLoading = true);
                        final success =
                            await repo.changeDeliveryType(orderId, 'express');
                        if (success) {
                          ref.invalidate(orderDetailsProvider(orderId));
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Delivery option changed to Express.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          setState(() => isLoading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Failed to update delivery option. Please try again.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE3F2FD),
                        child: Icon(Icons.fitness_center, color: Colors.blue),
                      ),
                      title: const Text('Heavy Express',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text(
                          'Required for large/heavy items (recalculates fees)'),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
                      onTap: () => TapGuard.run('order_details.change@240', () async {
                        setState(() => isLoading = true);
                        final success = await repo.changeDeliveryType(
                            orderId, 'heavy_express');
                        if (success) {
                          ref.invalidate(orderDetailsProvider(orderId));
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Delivery option changed to Heavy Express.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          setState(() => isLoading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Failed to update delivery option. Please try again.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE8F5E9),
                        child: Icon(Icons.groups, color: Colors.green),
                      ),
                      title: const Text('Wait in a New Batch (Pasabay)',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text(
                          'Join a new batch with neighbors in your barangay'),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
                      onTap: () => TapGuard.run('order_details.change@282', () async {
                        setState(() => isLoading = true);
                        final success =
                            await repo.changeDeliveryType(orderId, 'pasabay');
                        if (success) {
                          ref.invalidate(orderDetailsProvider(orderId));
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Rejoined new batch successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          setState(() => isLoading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Failed to rejoin batch. Please try again.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailsProvider(widget.orderId));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: AsyncBuilder<OrderModel?>(
          asyncValue: orderAsync,
          onRetry: () => ref.refresh(orderDetailsProvider(widget.orderId)),
          builder: (order) {
            if (order == null) {
              return const Center(child: Text('Order not found'));
            }

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 120.0,
                    floating: true,
                    pinned: true,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/main');
                        }
                      },
                    ),
                    flexibleSpace: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: FlexibleSpaceBar(
                        centerTitle: false,
                        titlePadding: const EdgeInsets.only(
                            left: 16, bottom: 48), // Adjusted for TabBar
                        title: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Order Details',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '#${order.orderNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: () => ref
                            .invalidate(orderDetailsProvider(widget.orderId)),
                        tooltip: 'Refresh',
                      ),
                      IconButton(
                        icon: const Icon(Icons.home_outlined,
                            color: Colors.white),
                        onPressed: () => context.go('/main'),
                        tooltip: 'Go to Home',
                      ),
                    ],
                    bottom: const TabBar(
                      indicatorColor: Colors.white,
                      indicatorWeight: 3,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      labelStyle: TextStyle(fontWeight: FontWeight.bold),
                      tabs: [
                        Tab(text: 'DETAILS'),
                        Tab(text: 'TRACK ORDER'),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                physics:
                    const NeverScrollableScrollPhysics(), // Disable swipe to prevent conflict with map
                children: [
                  // Tab 1: Details
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ETA Card for active orders
                        OrderETACard(order: order),
                        _buildHeaderCard(order),
                        const SizedBox(height: 12),
                        // Placed while the store was closed, not yet accepted.
                        if (isAwaitingStoreOpening(order)) ...[
                          AdvanceOrderNotice(
                            title: 'Waiting for the store to open',
                            message: awaitingStoreMessage(order.advanceOrder!),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (order.delivery?.type == 'pasabay') ...[
                          BatchProgressCard(
                            orderId: order.id,
                            batchInfo: order.delivery?.batchInfo,
                            requiresCustomerAction:
                                order.delivery?.requiresCustomerAction ?? false,
                            actionRequired: order.delivery?.actionRequired,
                            onHowItWorks: () => PasabayGuideModal.show(context),
                            onRefresh: () => ref.invalidate(
                                orderDetailsProvider(widget.orderId)),
                            onLeaveBatch: order.delivery?.batchInfo?.batchStatus
                                            ?.toLowerCase() ==
                                        'waiting' ||
                                    order.delivery?.batchInfo?.batchStatus
                                            ?.toLowerCase() ==
                                        'collecting'
                                ? () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title:
                                            const Text('Leave Pasabay Batch?'),
                                        content: const Text(
                                          'Leaving this batch will convert your order to Express Delivery and add the regular shipping fee. Do you want to proceed?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            style: TextButton.styleFrom(
                                                foregroundColor: Colors.red),
                                            child: const Text('Leave Batch'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      final user =
                                          FirebaseAuth.instance.currentUser;
                                      final token =
                                          await user?.getIdToken() ?? '';
                                      final repo = PasabayRepository(
                                        baseUrl: AppConfig.backendBaseUrl,
                                        getToken: () => token,
                                      );
                                      final success = await repo.leaveBatch(
                                        order.delivery?.batchInfo?.batchId ??
                                            '',
                                        order.id,
                                      );
                                      if (success) {
                                        ref.invalidate(orderDetailsProvider(
                                            widget.orderId));
                                        if (mounted) {
                                          _showDeliveryTypeSelectionBottomSheet(
                                              context, order.id, repo);
                                        }
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Failed to leave batch. Please try again.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        // Cancel button for pre-pickup orders
                        CancelOrderButton(
                          order: order,
                          onCancelled: () => context.pop(),
                        ),
                        // Note: Map moved to Tab 2

                        // Proof of delivery photo for delivered orders
                        ProofOfDeliveryDisplay(order: order),
                        _buildSectionHeader('Timeline'),
                        _buildOrderTimeline(order),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Items'),
                        _buildOrderItems(order),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader('Delivery'),
                                  _buildShippingAddress(order),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Payment'),
                        _buildPaymentSummary(order),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),

                  // Tab 2: Track Order (Map)
                  Column(
                    children: [
                      Expanded(
                        child: OrderTrackingMap(order: order),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: orderAsync.maybeWhen(
          data: (order) {
            if (order == null) return null;
            if (order.status == 'delivered') {
              return FutureBuilder<int>(
                future: _getReturnWindowDays(),
                builder: (context, snapshot) {
                  final windowDays = snapshot.data ?? _cachedReturnWindowDays;
                  return _buildDeliveredActionsBar(
                      context, ref, order, windowDays);
                },
              );
            }
            return null;
          },
          orElse: () => null,
        ),
      ),
    );
  }

  Widget _buildHeaderCard(OrderModel order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Placed',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(order.createdAt),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
              _buildStatusChip(order.status),
            ],
          ),
          if (order.isOfficial == true) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFB8860B).withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded,
                      size: 18, color: Color(0xFFB8860B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sold & fulfilled directly by Official Trenda',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB8860B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF546E7A),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  /// Labels and icons for each stage. What is COMPLETE and what is CURRENT is
  /// decided by orderStageStates, not here — see the warning on that function:
  /// this list used to compute each step inline with tests like
  /// `!['pending','confirmed','processing'].contains(status)`, which marked a
  /// cancelled order's shipping steps as done.
  static const Map<OrderStage, ({String title, IconData icon})> _stageInfo = {
    OrderStage.placed: (title: 'Order placed', icon: Icons.receipt_long),
    OrderStage.confirmed: (
      title: 'Confirmed',
      icon: Icons.check_circle_outline
    ),
    OrderStage.processing: (
      title: 'Being prepared',
      icon: Icons.inventory_2_outlined
    ),
    OrderStage.readyToShip: (
      title: 'Ready for pickup',
      icon: Icons.local_shipping_outlined
    ),
    OrderStage.riderAssigned: (
      title: 'Rider assigned',
      icon: Icons.delivery_dining
    ),
    OrderStage.outForDelivery: (
      title: 'Out for delivery',
      icon: Icons.directions_bike
    ),
    OrderStage.arriving: (title: 'Arriving', icon: Icons.location_on_outlined),
    OrderStage.delivered: (title: 'Delivered', icon: Icons.home_outlined),
  };

  String _stageSubtitle(
      OrderStage stage, OrderStageState state, OrderModel order) {
    switch (stage) {
      case OrderStage.placed:
        return _formatDate(order.createdAt);
      case OrderStage.confirmed:
        return state.completed ? 'Order confirmed' : 'Awaiting confirmation';
      case OrderStage.processing:
        return state.current ? 'The shop is preparing your order' : '';
      case OrderStage.readyToShip:
        return state.current ? 'Waiting for a rider' : '';
      case OrderStage.riderAssigned:
        return state.current ? 'Rider is collecting your order' : '';
      case OrderStage.outForDelivery:
        return state.current ? 'On the way to you' : '';
      case OrderStage.arriving:
        return state.current ? 'Rider is at your location' : '';
      case OrderStage.delivered:
        return order.deliveredAt != null
            ? 'Delivered ${_formatDate(order.deliveredAt!)}'
            : '';
    }
  }

  Widget _buildOrderTimeline(OrderModel order) {
    // Completion comes from what actually happened, so a stopped order does
    // not display stages it never reached.
    final states = orderStageStates(
      status: order.status,
      history: order.statusHistory.map((h) => h.status).toList(),
    );

    final steps = [
      for (final state in states)
        OrderStep(
          title: _stageInfo[state.stage]!.title,
          subtitle: _stageSubtitle(state.stage, state, order),
          icon: _stageInfo[state.stage]!.icon,
          isCompleted: state.completed,
          isCurrent: state.current,
        ),
      if (orderStatusView(order.status).tone == OrderTone.stopped)
        OrderStep(
          title: orderStatusView(order.status).label,
          subtitle: order.cancelReason?.trim().isNotEmpty == true
              ? order.cancelReason!.trim()
              : 'This order did not complete',
          icon: Icons.cancel_outlined,
          isCompleted: true,
          isCurrent: true,
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final isLast = index == steps.length - 1;
            return _buildTimelineStep(step, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(OrderStep step, bool isLast) {
    final activeColor = const Color(0xFF1E88E5);
    final inactiveColor = Colors.grey.shade300;

    final circleColor =
        step.isCompleted || step.isCurrent ? activeColor : inactiveColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: circleColor.withValues(alpha: 0.1),
                  border: Border.all(
                    color: circleColor,
                    width: 2,
                  ),
                ),
                child: step.isCompleted
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: activeColor,
                          ),
                        ),
                      )
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: step.isCompleted ? activeColor : inactiveColor,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: step.isCompleted || step.isCurrent
                          ? const Color(0xFF2C3E50)
                          : Colors.grey.shade500,
                    ),
                  ),
                  if (step.subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        step.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItems(OrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: order.items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 24, thickness: 0.5),
            itemBuilder: (context, index) {
              final item = order.items[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                      image: item.productImage != null
                          ? DecorationImage(
                              image: NetworkImage(item.productImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: Colors.grey.shade50,
                    ),
                    child: item.productImage == null
                        ? const Icon(Icons.image_not_supported,
                            size: 20, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Color(0xFF2C3E50),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Qty: ${item.quantity}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₱${item.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShippingAddress(OrderModel order) {
    final address = order.shippingAddress;
    final municipality = address?.municipality ?? address?.city;
    final isCrossMuni =
        order.commission?.ratesApplied?['municipalityOverride'] == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: address == null
          ? const Text('No shipping address')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: Color(0xFF546E7A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address.name ?? 'Receiver',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    // ✅ GAP-F9: Cross-municipality indicator
                    if (isCrossMuni)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz,
                                size: 10, color: Colors.orange),
                            SizedBox(width: 2),
                            Text('Cross-Muni',
                                style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (address.phone != null)
                        Text(
                          address.phone!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          address.street,
                          if (address.barangay != null)
                            'Brgy. ${address.barangay}',
                          if (municipality != null &&
                              municipality != address.city)
                            '$municipality (${address.city})'
                          else
                            address.city,
                          address.region,
                          address.postalCode,
                        ].where((e) => e != null && e.isNotEmpty).join(', '),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                      // ✅ Municipality label
                      if (municipality != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_city,
                                size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              'Municipality: $municipality',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPaymentSummary(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Subtotal', order.subtotal),
          const SizedBox(height: 12),
          _buildSummaryRow('Delivery Fee', order.shippingFee),
          // ✅ GAP-F14: Cross-municipality surcharge line
          if (order.commission?.ratesApplied?['municipalityOverride'] == true &&
              (order.commission?.ratesApplied?['crossMunicipalitySurcharge'] ??
                      0) >
                  0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Cross-Muni Surcharge',
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange.shade700)),
                    const SizedBox(width: 4),
                    Icon(Icons.swap_horiz,
                        size: 12, color: Colors.orange.shade600),
                  ],
                ),
                Text(
                  '+₱${(order.commission!.ratesApplied!['crossMunicipalitySurcharge'] as num).toDouble().toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
          if (order.tax > 0) ...[
            const SizedBox(height: 12),
            _buildSummaryRow('Tax', order.tax),
          ],
          if (order.discount > 0) ...[
            const SizedBox(height: 12),
            _buildSummaryRow('Discount', -order.discount, isDiscount: true),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          _buildSummaryRow('Total', order.total, isTotal: true),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.payment, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatPaymentMethod(order.paymentMethod),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  _formatPaymentStatus(order.paymentStatus).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _getPaymentStatusColor(order.paymentStatus),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount,
      {bool isTotal = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
            color: isTotal ? const Color(0xFF2C3E50) : Colors.grey.shade600,
          ),
        ),
        Text(
          '₱${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 18 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal
                ? const Color(0xFF2C3E50)
                : isDiscount
                    ? Colors.red
                    : const Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }

  /// Status wording, tone and colour all come from the shared vocabulary.
  ///
  /// This page used to carry its OWN switch — a fourth copy, with a third set
  /// of labels ("Processing" where the list said something else) and the same
  /// `default: label = status` leak, so an order that was out for delivery
  /// showed the raw token 'out_for_delivery' on its own detail page. It also
  /// knew nothing about ready_to_ship, pickup_started, arriving_at_customer,
  /// assigned_to_rider, returned, refunded, failed or completed.
  Widget _buildStatusChip(String status) =>
      OrderStatusBadge(status: status, compact: true);

  String _formatDate(DateTime date) => formatOrderDate(date);

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cod':
        return 'Cash on Delivery';
      case 'card':
        return 'Credit/Debit Card';
      case 'ewallet':
        return 'E-Wallet';
      default:
        return method;
    }
  }

  String _formatPaymentStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'paid':
        return 'Paid';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      default:
        return status;
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  bool _isReturnWindowOpen(OrderModel order, int windowDays) {
    if (order.deliveredAt == null) return false;
    return DateTime.now().difference(order.deliveredAt!).inDays <= windowDays;
  }

  Widget _buildDeliveredActionsBar(
      BuildContext context, WidgetRef ref, OrderModel order, int windowDays) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Rate Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => RateDeliveryDialog.show(context, order.id),
                    icon: const Icon(Icons.star, size: 18, color: Colors.amber),
                    label: const Text('Rate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber.shade700,
                      side: BorderSide(color: Colors.amber.shade300),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Reorder Button
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => TapGuard.run('order_details.handleReorder', () => _handleReorder(context, ref, order)),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reorder Items'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Return/Refund row — only show within return window
            if (_isReturnWindowOpen(order, windowDays))
              Row(
                children: [
                  // Return Items
                  Expanded(
                    child: Tooltip(
                      message: 'Request a physical return of items',
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final items = order.items
                              .map((item) => <String, dynamic>{
                                    'id': item.productId,
                                    'productId': item.productId,
                                    'name': item.productName,
                                    'quantity': item.quantity,
                                    'price': item.price,
                                    'image': item.productImage,
                                  })
                              .toList();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReturnRequestPage(
                                orderId: order.id,
                                orderNumber: order.orderNumber,
                                items: items,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.assignment_return, size: 18),
                        label: const Text('Return'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade700,
                          side: BorderSide(color: Colors.orange.shade300),
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Request Refund
                  Expanded(
                    child: Tooltip(
                      message: 'Request a monetary refund',
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final items = order.items
                              .map((item) => <String, dynamic>{
                                    'id': item.productId,
                                    'name': item.productName,
                                    'quantity': item.quantity,
                                    'price': item.price,
                                  })
                              .toList();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RefundRequestPage(
                                orderId: order.id,
                                orderNumber: order.orderNumber,
                                orderTotal: order.total,
                                items: items,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.money_off, size: 18),
                        label: const Text('Refund'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Return window expired ($windowDays days). Contact support for assistance.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleReorder(
      BuildContext context, WidgetRef ref, OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reorder'),
        content: Text(
            'Add all ${order.items.length} items from this order to your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add to Cart'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      int addedCount = 0;
      final cartRepo = ref.read(cartRepositoryProvider);

      for (final item in order.items) {
        try {
          await cartRepo.addToCart(
            productId: item.productId,
            quantity: item.quantity,
            variantId: item.variantId,
          );
          addedCount++;
        } catch (e) {
          debugPrint('Failed to add ${item.productName}: $e');
        }
      }

      await ref.read(cartProvider.notifier).loadCart();

      if (!context.mounted) return;

      if (addedCount > 0) {
        context.push('/cart');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add items to cart')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reorder: $e')),
      );
    }
  }
}

class OrderStep {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isCompleted;
  final bool isCurrent;

  OrderStep({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isCompleted,
    this.isCurrent = false,
  });
}
