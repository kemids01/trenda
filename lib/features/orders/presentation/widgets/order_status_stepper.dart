// trenda_frontend/lib/features/orders/presentation/widgets/order_status_stepper.dart
// Inline order-status stepper (read-only progress) — copied from the vendor app so the customer,
// vendor, and admin order steppers are visually identical. Highlights the order's CURRENT status
// across the lifecycle pending → confirmed → processing → ready_to_ship → pickup_started →
// in_transit/out_for_delivery → delivered. Terminal states (returned/cancelled) render standalone.
import 'package:flutter/material.dart';

class OrderStatusStep {
  final String status;
  final String label;
  final IconData icon;
  const OrderStatusStep({required this.status, required this.label, required this.icon});
}

/// The canonical forward lifecycle used by the stepper.
const List<OrderStatusStep> kOrderLifecycle = [
  OrderStatusStep(status: 'pending', label: 'Pending', icon: Icons.schedule),
  OrderStatusStep(status: 'confirmed', label: 'Confirmed', icon: Icons.check_circle_outline),
  OrderStatusStep(status: 'processing', label: 'Processing', icon: Icons.inventory_2_outlined),
  OrderStatusStep(status: 'ready_to_ship', label: 'Ready', icon: Icons.local_shipping_outlined),
  OrderStatusStep(status: 'pickup_started', label: 'Pickup', icon: Icons.moped_outlined),
  OrderStatusStep(status: 'out_for_delivery', label: 'In transit', icon: Icons.navigation_outlined),
  OrderStatusStep(status: 'delivered', label: 'Delivered', icon: Icons.task_alt),
];

Color orderStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Colors.orange;
    case 'confirmed':
      return Colors.blue;
    case 'processing':
      return Colors.purple;
    case 'ready_to_ship':
      return Colors.indigo;
    case 'pickup_started':
      return Colors.teal;
    case 'in_transit':
    case 'out_for_delivery':
    case 'shipped':
      return Colors.cyan;
    case 'delivered':
      return Colors.green;
    case 'returned':
      return Colors.deepOrange;
    case 'cancelled':
    case 'failed':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

/// Normalize backend statuses to the nearest lifecycle step index (−1 = terminal/off-lifecycle).
int lifecycleIndex(String status) {
  final s = status.toLowerCase();
  final direct = kOrderLifecycle.indexWhere((e) => e.status == s);
  if (direct >= 0) return direct;
  if (s == 'shipped' || s == 'in_transit' || s == 'arriving_at_customer') {
    return kOrderLifecycle.indexWhere((e) => e.status == 'out_for_delivery');
  }
  return -1;
}

/// Read-only horizontal progress stepper for a single order's current [status].
class OrderStatusStepper extends StatelessWidget {
  const OrderStatusStepper({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    if (s == 'cancelled' || s == 'returned' || s == 'failed' || s == 'refunded') {
      final c = orderStatusColor(s);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(s == 'returned' ? Icons.assignment_return : Icons.cancel, size: 16, color: c),
          const SizedBox(width: 8),
          Text(s[0].toUpperCase() + s.substring(1),
              style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      );
    }
    final current = lifecycleIndex(s);
    return SizedBox(
      height: 62,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        itemCount: kOrderLifecycle.length,
        itemBuilder: (_, i) {
          final step = kOrderLifecycle[i];
          final done = current >= 0 && i < current;
          final active = current >= 0 && i == current;
          final color = active ? orderStatusColor(step.status) : (done ? Colors.green : Colors.grey);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: active ? 34 : 28,
                      height: active ? 34 : 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
                        border: Border.all(color: color, width: active ? 2.5 : 1.5),
                      ),
                      child: Icon(done ? Icons.check : step.icon, size: active ? 17 : 14, color: color),
                    ),
                    const SizedBox(height: 3),
                    Text(step.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: active ? FontWeight.bold : FontWeight.w500,
                            color: color)),
                  ],
                ),
              ),
              if (i < kOrderLifecycle.length - 1)
                Container(
                  width: 12,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  color: done ? Colors.green : Colors.grey.shade300,
                ),
            ],
          );
        },
      ),
    );
  }
}
