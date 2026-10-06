// trenda_frontend/lib/features/orders/presentation/widgets/cancel_order_button.dart
// Cancel order button widget for orders before pickup
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/models/order_model.dart';
import '../../providers/orders_provider.dart';
import '../../utils/order_presentation.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class CancelOrderButton extends ConsumerStatefulWidget {
  final OrderModel order;
  final VoidCallback? onCancelled;

  const CancelOrderButton({
    super.key,
    required this.order,
    this.onCancelled,
  });

  @override
  ConsumerState<CancelOrderButton> createState() => _CancelOrderButtonState();
}

class _CancelOrderButtonState extends ConsumerState<CancelOrderButton> {
  bool _isCancelling = false;

  // The same rule as the order list and the server (pending/confirmed only).
  // This copy also allowed 'processing', which the server refuses — the customer
  // was offered a button that could only fail.
  bool get _canCancel => canCancelOrder(widget.order.status);

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text(
          'Are you sure you want to cancel this order? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      await ref.read(orderActionsProvider).cancelOrder(
            widget.order.id,
            'Customer requested cancellation',
          );

      // Refresh order details
      ref.invalidate(orderDetailsProvider(widget.order.id));
      ref.invalidate(myOrdersProvider); // the list + counts still showed it active

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: Colors.orange,
          ),
        );
        widget.onCancelled?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canCancel) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: OutlinedButton.icon(
        onPressed: _isCancelling ? null : () => TapGuard.run('cancel_order_button.cancelOrder', _cancelOrder),
        icon: _isCancelling
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cancel_outlined, color: Colors.red),
        label: Text(_isCancelling ? 'Cancelling...' : 'Cancel Order'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
