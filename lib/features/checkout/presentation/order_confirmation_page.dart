// lib/features/checkout/presentation/order_confirmation_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_frontend/features/core/widgets/frontend_official_ad_slot.dart';
import '../../orders/providers/orders_provider.dart';
import '../../stores/utils/advance_order_notice.dart';
import '../../stores/widgets/advance_order_notice.dart';

/// What a split checkout means for the shopper.
String splitCheckoutMessage(int orderCount) =>
    'Your cart had items from $orderCount stores, so it was placed as $orderCount orders. '
    'Each store is delivered by its own rider — track them in My Orders.';

class OrderConfirmationPage extends ConsumerWidget {
  final String orderId;

  /// How many orders the checkout was placed as — one per store (or Official warehouse), each
  /// delivered by its own rider. [orderId] is the first of them.
  final int orderCount;

  const OrderConfirmationPage({super.key, required this.orderId, this.orderCount = 1});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Invalidate orders providers to refresh list and counts after checkout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The tabs and the counts all derive from myOrdersProvider.
      ref.invalidate(myOrdersProvider);
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const FrontendOfficialAdSlot(slotId: 'frontend.order_success.top'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
              // Success Animation
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 120,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // Success Message
              const Text(
                'Order Placed Successfully!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Text(
                'Order #$orderId',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),

              // Description
              Text(
                'Thank you for your order! We\'ll send you a confirmation email shortly.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              if (orderCount > 1) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.two_wheeler, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          splitCheckoutMessage(orderCount),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Placed while the store was closed: say when it will be picked up.
              if (ref.watch(orderDetailsProvider(orderId)).valueOrNull
                  case final order? when isAwaitingStoreOpening(order)) ...[
                const SizedBox(height: 20),
                AdvanceOrderNotice(
                  title: 'Waiting for the store to open',
                  message: awaitingStoreMessage(order.advanceOrder!),
                ),
              ],
              const SizedBox(height: 48),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Several orders → My Orders lists them all; one → straight to it.
                    context.go(orderCount > 1 ? '/orders' : '/orders/$orderId');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Track Order',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    context.go('/main');
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Continue Shopping',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
