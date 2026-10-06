// lib/features/orders/widgets/order_status_alert_overlay.dart
// ============================================================================
// ORDER STATUS ALERT - Floating notification when order status changes
// Shows alert when vendor confirms order or rider is on the way
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_shared/services/websocket_service.dart';
import '../../core/services/notification_sound_service.dart';

/// Provider for managing order status alerts
final orderStatusAlertProvider =
    StateNotifierProvider<OrderStatusAlertNotifier, OrderStatusAlertState>(
        (ref) {
  return OrderStatusAlertNotifier(ref);
});

class OrderStatusAlertState {
  final bool isVisible;
  final String? orderId;
  final String? orderNumber;
  final String? status;
  final String? message;

  const OrderStatusAlertState({
    this.isVisible = false,
    this.orderId,
    this.orderNumber,
    this.status,
    this.message,
  });

  OrderStatusAlertState copyWith({
    bool? isVisible,
    String? orderId,
    String? orderNumber,
    String? status,
    String? message,
  }) {
    return OrderStatusAlertState(
      isVisible: isVisible ?? this.isVisible,
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }
}

class OrderStatusAlertNotifier extends StateNotifier<OrderStatusAlertState> {
  final Ref _ref;
  bool _isListening = false;
  late final WebSocketEventCallback _wsCallback;

  OrderStatusAlertNotifier(this._ref) : super(const OrderStatusAlertState()) {
    _wsCallback = _handleWebSocketEvent;
    _setupListener();
  }

  void _setupListener() {
    if (_isListening) return;
    _isListening = true;

    _ref.read(webSocketProvider.notifier).addEventCallback(_wsCallback);
    debugPrint('📱 OrderStatusAlert: WebSocket listener added');
  }

  void _handleWebSocketEvent(String event, Map<String, dynamic> data) {
    if (event == 'order:status_changed') {
      final newStatus = data['newStatus']?.toString() ?? '';
      final orderId = data['orderId']?.toString();
      final orderNumber = data['orderNumber']?.toString() ?? '';

      // Only show alert for important status changes
      if (_shouldShowAlert(newStatus)) {
        debugPrint(
            '📱 Order Status Alert - Status: $newStatus, Order: $orderNumber');

        // Play notification sound
        _ref.read(notificationSoundProvider).playOrderUpdateSound();

        state = OrderStatusAlertState(
          isVisible: true,
          orderId: orderId,
          orderNumber: orderNumber,
          status: newStatus,
          message: _getStatusMessage(newStatus),
        );
      }
    }
  }

  bool _shouldShowAlert(String status) {
    return [
      'confirmed', // Vendor accepted order
      'pickup_started', // Rider is on the way to pickup
      'out_for_delivery', // Rider is on the way to customer
      'arriving_at_customer', // Rider has arrived
      'delivered', // Order delivered
      'cancelled', // Order cancelled by vendor
    ].contains(status.toLowerCase());
  }

  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Your order has been confirmed by the vendor! 🎉';
      case 'pickup_started':
        return 'A rider is on the way to pick up your order 🏍️';
      case 'out_for_delivery':
        return 'Your order is on the way! 🚀';
      case 'arriving_at_customer':
        return 'Rider has arrived at your location! 📍';
      case 'delivered':
        return 'Your order has been delivered! ✅';
      case 'cancelled':
        return 'Unfortunately, your order has been cancelled 😔';
      default:
        return 'Your order status has been updated';
    }
  }

  IconData getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle;
      case 'pickup_started':
        return Icons.directions_bike;
      case 'out_for_delivery':
        return Icons.local_shipping;
      case 'arriving_at_customer':
        return Icons.pin_drop;
      case 'delivered':
        return Icons.celebration;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.notifications_active;
    }
  }

  Color getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return Colors.blue;
      case 'pickup_started':
        return Colors.orange;
      case 'out_for_delivery':
        return Colors.teal;
      case 'arriving_at_customer':
        return Colors.green;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  void dismiss() {
    state = const OrderStatusAlertState(isVisible: false);
  }

  @override
  void dispose() {
    if (_isListening) {
      try {
        _ref.read(webSocketProvider.notifier).removeEventCallback(_wsCallback);
      } catch (e) {
        // Ignore if already disposed
      }
    }
    super.dispose();
  }
}

/// Widget that shows the order status alert overlay
class OrderStatusAlertOverlay extends ConsumerWidget {
  final Widget child;

  const OrderStatusAlertOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertState = ref.watch(orderStatusAlertProvider);

    return Stack(
      children: [
        child,
        if (alertState.isVisible) ...[
          // Semi-transparent background
          Positioned.fill(
            child: GestureDetector(
              onTap: () =>
                  ref.read(orderStatusAlertProvider.notifier).dismiss(),
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),
          // Centered alert card
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _OrderStatusAlertCard(
                    orderId: alertState.orderId,
                    orderNumber: alertState.orderNumber,
                    status: alertState.status,
                    message: alertState.message,
                    onDismiss: () =>
                        ref.read(orderStatusAlertProvider.notifier).dismiss(),
                    onViewOrder: () {
                      ref.read(orderStatusAlertProvider.notifier).dismiss();
                      final orderId = alertState.orderId;
                      debugPrint('📱 View Order tapped - orderId: $orderId');
                      if (orderId != null && orderId.isNotEmpty) {
                        debugPrint('📱 Navigating to /orders/$orderId');
                        context.push('/orders/$orderId');
                      } else {
                        debugPrint('📱 No orderId, navigating to /orders');
                        context.push('/orders');
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OrderStatusAlertCard extends ConsumerStatefulWidget {
  final String? orderId;
  final String? orderNumber;
  final String? status;
  final String? message;
  final VoidCallback onDismiss;
  final VoidCallback onViewOrder;

  const _OrderStatusAlertCard({
    this.orderId,
    this.orderNumber,
    this.status,
    this.message,
    required this.onDismiss,
    required this.onViewOrder,
  });

  @override
  ConsumerState<_OrderStatusAlertCard> createState() =>
      _OrderStatusAlertCardState();
}

class _OrderStatusAlertCardState extends ConsumerState<_OrderStatusAlertCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();

    // Auto-dismiss after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(orderStatusAlertProvider.notifier);
    final statusColor = notifier.getStatusColor(widget.status);
    final statusIcon = notifier.getStatusIcon(widget.status);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor,
                  statusColor.withValues(alpha: 0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Icon with pulse animation
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        statusIcon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Order info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTitle(widget.status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (widget.orderNumber != null &&
                              widget.orderNumber!.isNotEmpty)
                            Text(
                              'Order #${widget.orderNumber}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            widget.message ?? 'Order status updated',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Close button
                    IconButton(
                      onPressed: _dismiss,
                      icon: const Icon(Icons.close, color: Colors.white70),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // View Order button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onViewOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: statusColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'View Order',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTitle(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return '✅ ORDER CONFIRMED!';
      case 'pickup_started':
        return '🏍️ RIDER ON THE WAY!';
      case 'out_for_delivery':
        return '🚀 OUT FOR DELIVERY!';
      case 'arriving_at_customer':
        return '📍 RIDER ARRIVED!';
      case 'delivered':
        return '🎉 ORDER DELIVERED!';
      case 'cancelled':
        return '❌ ORDER CANCELLED';
      default:
        return '📦 ORDER UPDATE';
    }
  }
}
