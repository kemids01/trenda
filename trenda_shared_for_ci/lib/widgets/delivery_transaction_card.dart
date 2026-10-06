// trenda_shared/lib/widgets/delivery_transaction_card.dart
// Enhanced transaction history card showing all delivery details with timeline
// Shared widget for trenda_delivery and trenda_admin apps

import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../core/timezone.dart';

/// Displays detailed transaction information for a delivered order
/// Includes: timeline, vendor payment, delivery duration, commission breakdown
class DeliveryTransactionCard extends StatelessWidget {
  final OrderModel order;
  final double? vendorCommission;
  final double? deliveryCommission;

  const DeliveryTransactionCard({
    super.key,
    required this.order,
    this.vendorCommission,
    this.deliveryCommission,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(context),
          const Divider(height: 1),

          // Timeline Section
          _buildTimelineSection(context),
          const Divider(height: 1),

          // Financial Summary
          _buildFinancialSection(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getStatusColor(order.status).withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order.orderNumber}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  order.vendor?.storeName ?? 'Unknown Vendor',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildStatusBadge(order.status),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        _formatStatus(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTimelineSection(BuildContext context) {
    final events = _getTimelineEvents();
    final deliveryDuration = _calculateDeliveryDuration();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  '📍 Delivery Timeline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (deliveryDuration != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⏱ $deliveryDuration',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...events.asMap().entries.map((entry) {
            final index = entry.key;
            final event = entry.value;
            final isLast = index == events.length - 1;
            return _buildTimelineItem(event, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(TimelineEvent event, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: event.color.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: event.color, width: 2),
              ),
              child: Icon(event.icon, size: 16, color: event.color),
            ),
            if (!isLast)
              Container(width: 2, height: 40, color: Colors.grey[300]),
          ],
        ),
        const SizedBox(width: 12),
        // Content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  TrendaTimezone.format(
                    event.timestamp,
                    pattern: 'MMM d, h:mm a',
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (event.note != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.note!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialSection(BuildContext context) {
    // Calculate vendor payment (what rider paid to vendor)
    final vendorPayment = order.subtotal - (vendorCommission ?? 0);
    final totalCommission = (vendorCommission ?? 0) + (deliveryCommission ?? 0);
    final riderEarnings = order.shippingFee - (deliveryCommission ?? 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💰 Financial Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // COD Collection
          if (order.paymentMethod == 'cod') ...[
            _financialRow(
              'COD Collected from Customer',
              '₱${order.total.toStringAsFixed(2)}',
              icon: Icons.payments,
              color: Colors.green,
            ),
            const SizedBox(height: 8),
          ],

          // Vendor Payment
          _financialRow(
            'Paid to Vendor',
            '₱${vendorPayment.toStringAsFixed(2)}',
            icon: Icons.store,
            color: Colors.orange,
          ),
          const SizedBox(height: 8),

          const Divider(),
          const SizedBox(height: 8),

          // Commission Breakdown
          _financialRow(
            'Vendor Commission',
            '-₱${(vendorCommission ?? 0).toStringAsFixed(2)}',
            subtext: _getVendorCommissionRate(),
            isDeduction: true,
          ),
          const SizedBox(height: 8),
          _financialRow(
            'Delivery Commission',
            '-₱${(deliveryCommission ?? 0).toStringAsFixed(2)}',
            subtext: _getDeliveryCommissionRate(),
            isDeduction: true,
          ),

          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),

          // Totals
          _financialRow(
            'Total Commission Owed',
            '₱${totalCommission.toStringAsFixed(2)}',
            icon: Icons.account_balance_wallet,
            color: Colors.red,
            isBold: true,
          ),
          const SizedBox(height: 8),
          _financialRow(
            'Rider Earnings (Delivery Fee)',
            '₱${riderEarnings.toStringAsFixed(2)}',
            icon: Icons.monetization_on,
            color: Colors.teal,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _financialRow(
    String label,
    String value, {
    IconData? icon,
    Color? color,
    String? subtext,
    bool isDeduction = false,
    bool isBold = false,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color ?? Colors.grey[600]),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (subtext != null)
                Text(
                  subtext,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isDeduction ? Colors.red : (color ?? Colors.black),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Helper Methods
  // ============================================================

  List<TimelineEvent> _getTimelineEvents() {
    final events = <TimelineEvent>[];

    // Order created
    events.add(
      TimelineEvent(
        title: 'Order Placed',
        timestamp: order.createdAt,
        icon: Icons.shopping_cart,
        color: Colors.blue,
      ),
    );

    // Parse status history for timeline events
    for (final history in order.statusHistory) {
      final event = _mapStatusToEvent(
        history.status,
        history.timestamp,
        history.note,
      );
      if (event != null) {
        events.add(event);
      }
    }

    // Add delivered timestamp if available and not in history
    if (order.deliveredAt != null) {
      final hasDelivered = events.any(
        (e) => e.title.toLowerCase().contains('delivered'),
      );
      if (!hasDelivered) {
        events.add(
          TimelineEvent(
            title: 'Delivered',
            timestamp: order.deliveredAt!,
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        );
      }
    }

    // Sort by timestamp
    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return events;
  }

  TimelineEvent? _mapStatusToEvent(
    String status,
    DateTime timestamp,
    String? note,
  ) {
    switch (status.toLowerCase()) {
      case 'pending':
        return TimelineEvent(
          title: 'Order Confirmed',
          timestamp: timestamp,
          icon: Icons.pending_actions,
          color: Colors.orange,
          note: note,
        );
      case 'ready_for_pickup':
      case 'processing':
        return TimelineEvent(
          title: 'Ready for Pickup',
          timestamp: timestamp,
          icon: Icons.inventory_2,
          color: Colors.purple,
          note: note,
        );
      case 'rider_assigned':
      case 'assigned':
        return TimelineEvent(
          title: 'Rider Assigned',
          timestamp: timestamp,
          icon: Icons.person_pin,
          color: Colors.indigo,
          note: note,
        );
      case 'picked_up':
      case 'in_transit':
        return TimelineEvent(
          title: 'Picked Up from Vendor',
          timestamp: timestamp,
          icon: Icons.local_shipping,
          color: Colors.teal,
          note: note,
        );
      case 'out_for_delivery':
        return TimelineEvent(
          title: 'Out for Delivery',
          timestamp: timestamp,
          icon: Icons.delivery_dining,
          color: Colors.cyan,
          note: note,
        );
      case 'arrived':
        return TimelineEvent(
          title: 'Arrived at Customer',
          timestamp: timestamp,
          icon: Icons.location_on,
          color: Colors.blue,
          note: note,
        );
      case 'delivered':
        return TimelineEvent(
          title: 'Delivered Successfully',
          timestamp: timestamp,
          icon: Icons.check_circle,
          color: Colors.green,
          note: note,
        );
      case 'cancelled':
        return TimelineEvent(
          title: 'Cancelled',
          timestamp: timestamp,
          icon: Icons.cancel,
          color: Colors.red,
          note: note ?? order.cancelReason,
        );
      default:
        return null;
    }
  }

  String? _calculateDeliveryDuration() {
    // Find pickup and delivery times
    DateTime? pickupTime;
    DateTime? deliveryTime;

    for (final history in order.statusHistory) {
      final status = history.status.toLowerCase();
      if (status == 'picked_up' || status == 'in_transit') {
        pickupTime = history.timestamp;
      }
      if (status == 'delivered') {
        deliveryTime = history.timestamp;
      }
    }

    // Fallback to deliveredAt
    deliveryTime ??= order.deliveredAt;

    if (pickupTime == null || deliveryTime == null) return null;

    final duration = deliveryTime.difference(pickupTime);
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} min';
    } else {
      final hours = duration.inHours;
      final mins = duration.inMinutes % 60;
      return '${hours}h ${mins}m';
    }
  }

  String _getVendorCommissionRate() {
    return 'Platform fee';
  }

  String _getDeliveryCommissionRate() {
    return 'Delivery fee commission';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'in_transit':
      case 'picked_up':
        return Colors.blue;
      case 'ready_for_pickup':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  String _formatStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
  }
}

/// Timeline event model
class TimelineEvent {
  final String title;
  final DateTime timestamp;
  final IconData icon;
  final Color color;
  final String? note;

  TimelineEvent({
    required this.title,
    required this.timestamp,
    required this.icon,
    required this.color,
    this.note,
  });
}
