// trenda_frontend/lib/features/orders/presentation/widgets/order_eta_card.dart
// Real-time ETA display widget for active orders
import 'package:flutter/material.dart';
import 'package:trenda_shared/models/order_model.dart';

class OrderETACard extends StatelessWidget {
  final OrderModel order;

  const OrderETACard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    // Only show ETA for orders in transit
    if (!_shouldShowETA(order.status)) {
      return const SizedBox.shrink();
    }

    final etaInfo = _calculateETA(order);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              etaInfo.icon,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etaInfo.title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  etaInfo.time,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  etaInfo.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (order.status == 'out_for_delivery' ||
              order.status == 'arriving_at_customer')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_bike, size: 16, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _shouldShowETA(String status) {
    return [
      'confirmed',
      'processing',
      'ready_to_ship',
      'shipped',
      'pickup_started',
      'out_for_delivery',
      'arriving_at_customer',
    ].contains(status.toLowerCase());
  }

  _ETAInfo _calculateETA(OrderModel order) {
    switch (order.status.toLowerCase()) {
      case 'confirmed':
        return _ETAInfo(
          title: 'Estimated Preparation',
          time: '15-20 min',
          subtitle: 'Vendor is preparing your order',
          icon: Icons.restaurant,
        );
      case 'processing':
        return _ETAInfo(
          title: 'Preparing Your Order',
          time: '10-15 min',
          subtitle: 'Almost ready for pickup',
          icon: Icons.inventory_2_outlined,
        );
      case 'ready_to_ship':
        return _ETAInfo(
          title: 'Ready for Pickup',
          time: '5-10 min',
          subtitle: 'Waiting for rider assignment',
          icon: Icons.local_shipping_outlined,
        );
      case 'shipped':
      case 'pickup_started':
        return _ETAInfo(
          title: 'Rider En Route to Vendor',
          time: '10-15 min',
          subtitle: 'Rider is picking up your order',
          icon: Icons.delivery_dining,
        );
      case 'out_for_delivery':
        return _ETAInfo(
          title: 'Arriving Soon',
          time: '5-15 min',
          subtitle: 'Rider is on the way to you',
          icon: Icons.directions_bike,
        );
      case 'arriving_at_customer':
        return _ETAInfo(
          title: 'Almost There!',
          time: '1-2 min',
          subtitle: 'Rider is at your location',
          icon: Icons.location_on,
        );
      default:
        return _ETAInfo(
          title: 'Processing',
          time: '...',
          subtitle: '',
          icon: Icons.hourglass_empty,
        );
    }
  }
}

class _ETAInfo {
  final String title;
  final String time;
  final String subtitle;
  final IconData icon;

  _ETAInfo({
    required this.title,
    required this.time,
    required this.subtitle,
    required this.icon,
  });
}
