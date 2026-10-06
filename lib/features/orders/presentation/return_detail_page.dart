// lib/features/orders/presentation/return_detail_page.dart
// Customer return/exchange detail page with timeline tracking

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../design_system/app_colors.dart';
import '../data/orders_repository.dart';
import 'package:trenda_shared/core/timezone.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class ReturnDetailPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> returnData;

  const ReturnDetailPage({super.key, required this.returnData});

  @override
  ConsumerState<ReturnDetailPage> createState() => _ReturnDetailPageState();
}

class _ReturnDetailPageState extends ConsumerState<ReturnDetailPage> {
  bool _isCancelling = false;

  Map<String, dynamic> get data => widget.returnData;
  String get status => data['status'] ?? 'requested';
  bool get isExchange => (data['type'] ?? 'return') == 'exchange';
  String get returnId => data['_id'] ?? data['id'] ?? '';

  @override
  Widget build(BuildContext context) {
    final returnNumber = data['returnNumber'] ?? '';
    final orderNumber = data['orderNumber'] ?? '';
    final totalRefund = (data['totalRefund'] ?? 0).toDouble();
    final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final createdAt =
        DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now();
    final customerNotes = data['customerNotes'] as String?;
    final vendorNotes = data['vendorNotes'] as String?;
    final rejectionReason = data['rejectionReason'] as String?;
    final images = (data['images'] as List?)?.cast<String>() ?? [];
    final deliveryTask =
        data['deliveryTask'] as Map<String, dynamic>?;
    final timeline = data['timeline'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(isExchange ? 'Exchange Details' : 'Return Details'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isExchange ? Icons.swap_horiz : Icons.assignment_return,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          returnNumber.isNotEmpty ? returnNumber : 'Return Request',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _StatusBadge(status: status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Order: $orderNumber • ${DateFormat.yMMMd().add_jm().formatPh(createdAt)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.shopping_bag_outlined,
                        label: '${items.length} items',
                      ),
                      const SizedBox(width: 10),
                      _InfoChip(
                        icon: isExchange ? Icons.swap_horiz : Icons.payments,
                        label: isExchange
                            ? 'Same Product'
                            : '₱${totalRefund.toStringAsFixed(2)}',
                      ),
                      const SizedBox(width: 10),
                      _InfoChip(
                        icon:
                            isExchange ? Icons.autorenew : Icons.currency_exchange,
                        label: isExchange ? 'Exchange' : 'Refund',
                        color: isExchange ? Colors.green : Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Municipality display
            Builder(builder: (ctx) {
              final order = data['order'];
              Map? addr;
              if (order is Map) addr = order['shippingAddress'] as Map?;
              addr ??= data['shippingAddress'] as Map?;
              final muni = addr?['municipality'] ?? addr?['city'] ?? '';
              final brgy = addr?['barangay'] ?? '';
              if (muni.toString().isEmpty) return const SizedBox(height: 8);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withAlpha(12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.withAlpha(30)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_city, size: 16, color: Colors.teal[600]),
                      const SizedBox(width: 8),
                      Text('$muni${brgy.toString().isNotEmpty ? " • $brgy" : ""}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal[700])),
                    ],
                  ),
                ),
              );
            }),

            // Refund tracking (I5)
            if (!isExchange && status == 'completed' && data['refund'] is Map) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: Colors.green),
                          const SizedBox(width: 6),
                          const Text('Refund Processed',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if ((data['refund'] as Map)['transactionId'] != null)
                        Text('Transaction: ${(data['refund'] as Map)['transactionId']}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      Text('Amount: ₱${totalRefund.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Timeline stepper
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TimelineStepper(
                status: status,
                isExchange: isExchange,
                timeline: timeline,
              ),
            ),

            const SizedBox(height: 20),

            // Delivery task info (when available)
            if (deliveryTask != null)
              _DeliveryTaskSection(task: deliveryTask, isExchange: isExchange),

            // Items list
            _SectionCard(
              title: 'Items',
              icon: Icons.shopping_cart_outlined,
              children: items.map((item) => _ItemTile(item: item)).toList(),
            ),

            // Notes & reason
            if (customerNotes != null && customerNotes.isNotEmpty)
              _SectionCard(
                title: 'Your Notes',
                icon: Icons.notes,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(customerNotes,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  ),
                ],
              ),

            if (vendorNotes != null && vendorNotes.isNotEmpty)
              _SectionCard(
                title: 'Vendor Response',
                icon: Icons.store,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(vendorNotes,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  ),
                ],
              ),

            if (rejectionReason != null && rejectionReason.isNotEmpty)
              _SectionCard(
                title: 'Rejection Reason',
                icon: Icons.cancel_outlined,
                iconColor: Colors.red,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(rejectionReason,
                              style: TextStyle(fontSize: 13, color: Colors.red[800])),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            // Proof images
            if (images.isNotEmpty)
              _SectionCard(
                title: 'Proof Images',
                icon: Icons.photo_library,
                children: [
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: images.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            images[index],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            // Exchange product info
            if (isExchange) ...[
              _SectionCard(
                title: 'Exchange Product',
                icon: Icons.swap_horiz,
                iconColor: Colors.green,
                children: [
                  if (data['exchangeProduct'] != null) ...[
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                            image: data['exchangeProduct']['productImage'] != null
                                ? DecorationImage(
                                    image: NetworkImage(
                                        data['exchangeProduct']['productImage']),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: data['exchangeProduct']['productImage'] == null
                              ? Icon(Icons.shopping_bag,
                                  size: 24, color: Colors.grey.shade400)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['exchangeProduct']['productName'] ?? 'Replacement product',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (data['exchangeProduct']['variant'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Variant: ${data['exchangeProduct']['variant']}',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Qty: ${data['exchangeProduct']['quantity'] ?? 1}',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (data['exchangeProduct']['notes'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          data['exchangeProduct']['notes'],
                          style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600),
                        ),
                      ),
                  ] else
                    Row(
                      children: [
                        Icon(Icons.hourglass_top,
                            size: 16, color: Colors.orange.shade400),
                        const SizedBox(width: 8),
                        Text(
                          'Replacement product details pending',
                          style: TextStyle(
                              fontSize: 13, color: Colors.orange.shade600),
                        ),
                      ],
                    ),
                ],
              ),
            ],

            // Refund info
            if (!isExchange && status == 'completed')
              _SectionCard(
                title: 'Refund Information',
                icon: Icons.account_balance_wallet,
                iconColor: Colors.green,
                children: [
                  _DetailRow('Refund Amount', '₱${totalRefund.toStringAsFixed(2)}'),
                  if (data['refundMethod'] != null)
                    _DetailRow('Method',
                        (data['refundMethod'] as String).replaceAll('_', ' ')),
                  if (data['transactionId'] != null)
                    _DetailRow('Transaction ID', data['transactionId']),
                ],
              ),

            // Cancel button
            if (status == 'requested' || status == 'pending_review')
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isCancelling ? null : () => TapGuard.run('return_detail.cancelReturn', _cancelReturn),
                    icon: _isCancelling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: Text(_isCancelling ? 'Cancelling...' : 'Cancel Return'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelReturn() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Return?'),
        content: const Text(
            'Are you sure you want to cancel this return request? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Return'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Return'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      await OrdersRepository().cancelReturn(returnId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }
}

// =============================================================================
// TIMELINE STEPPER
// =============================================================================

class _TimelineStepper extends StatelessWidget {
  final String status;
  final bool isExchange;
  final Map<String, dynamic>? timeline;

  const _TimelineStepper({
    required this.status,
    required this.isExchange,
    this.timeline,
  });

  @override
  Widget build(BuildContext context) {
    final steps = isExchange ? _exchangeSteps() : _returnSteps();
    final currentIndex = steps.indexWhere((s) => s['status'] == status);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Status Timeline',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            ...steps.asMap().entries.map((entry) {
              final i = entry.key;
              final step = entry.value;
              final isActive = i <= currentIndex;
              final isCurrent = i == currentIndex;
              final isLast = i == steps.length - 1;
              final isRejected = status == 'rejected' || status == 'cancelled';
              final stepDate = _getStepDate(step['timelineKey'] as String?);

              Color dotColor;
              if (isRejected && isCurrent) {
                dotColor = Colors.red;
              } else if (isActive) {
                dotColor = Colors.green;
              } else {
                dotColor = Colors.grey[300]!;
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dot + line
                    SizedBox(
                      width: 32,
                      child: Column(
                        children: [
                          Container(
                            width: isCurrent ? 18 : 14,
                            height: isCurrent ? 18 : 14,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                              border: isCurrent
                                  ? Border.all(
                                      color: dotColor.withAlpha(80), width: 3)
                                  : null,
                            ),
                            child: isActive && !isCurrent
                                ? const Icon(Icons.check,
                                    size: 10, color: Colors.white)
                                : null,
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: isActive
                                    ? Colors.green.withAlpha(60)
                                    : Colors.grey[200],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step['label'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    isCurrent ? FontWeight.w700 : FontWeight.w500,
                                color: isActive
                                    ? Colors.grey[900]
                                    : Colors.grey[400],
                              ),
                            ),
                            if (step['subtitle'] != null)
                              Text(
                                step['subtitle'] as String,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500]),
                              ),
                            if (stepDate != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  DateFormat.yMMMd().add_jm().formatPh(stepDate),
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[400]),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  DateTime? _getStepDate(String? key) {
    if (key == null || timeline == null) return null;
    final value = timeline![key];
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  List<Map<String, dynamic>> _returnSteps() => [
        {
          'status': 'requested',
          'label': 'Return Requested',
          'subtitle': 'Waiting for vendor review',
          'timelineKey': 'requested'
        },
        {
          'status': 'approved',
          'label': 'Approved',
          'subtitle': 'Vendor approved your return',
          'timelineKey': 'approved'
        },
        {
          'status': 'pickup_scheduled',
          'label': 'Pickup Scheduled',
          'subtitle': 'Rider assigned for pickup',
          'timelineKey': 'pickupScheduled'
        },
        {
          'status': 'picked_up',
          'label': 'Picked Up',
          'subtitle': 'Rider collected the item',
          'timelineKey': 'pickedUp'
        },
        {
          'status': 'received',
          'label': 'Received by Vendor',
          'subtitle': 'Item returned to vendor',
          'timelineKey': 'received'
        },
        {
          'status': 'refund_processing',
          'label': 'Refund Processing',
          'subtitle': 'Your refund is being processed',
          'timelineKey': 'refundProcessed'
        },
        {
          'status': 'completed',
          'label': 'Completed',
          'subtitle': 'Refund credited',
          'timelineKey': 'completed'
        },
      ];

  List<Map<String, dynamic>> _exchangeSteps() => [
        {
          'status': 'requested',
          'label': 'Exchange Requested',
          'subtitle': 'Waiting for vendor review',
          'timelineKey': 'requested'
        },
        {
          'status': 'approved',
          'label': 'Approved',
          'subtitle': 'Vendor approved the exchange',
          'timelineKey': 'approved'
        },
        {
          'status': 'pickup_scheduled',
          'label': 'Rider Assigned',
          'subtitle': 'Original rider assigned for pickup',
          'timelineKey': 'pickupScheduled'
        },
        {
          'status': 'picked_up',
          'label': 'Item Picked Up',
          'subtitle': 'Rider collected your item',
          'timelineKey': 'pickedUp'
        },
        {
          'status': 'received',
          'label': 'Delivered to Vendor',
          'subtitle': 'Item returned to vendor',
          'timelineKey': 'received'
        },
        {
          'status': 'inspecting',
          'label': 'Replacement Pickup',
          'subtitle': 'Rider picking up replacement',
          'timelineKey': 'inspected'
        },
        {
          'status': 'completed',
          'label': 'Replacement Delivered',
          'subtitle': 'You received the replacement!',
          'timelineKey': 'completed'
        },
      ];
}

// =============================================================================
// DELIVERY TASK SECTION
// =============================================================================

class _DeliveryTaskSection extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool isExchange;

  const _DeliveryTaskSection({required this.task, required this.isExchange});

  @override
  Widget build(BuildContext context) {
    final riderName = task['riderName'] ?? 'Unassigned';
    final taskStatus = task['status'] ?? 'pending';
    final pickupFee = (task['pickupFee'] ?? 0).toDouble();
    final deliveryFee = (task['deliveryFee'] ?? 0).toDouble();
    final totalFee = (task['totalFee'] ?? 0).toDouble();
    final paidBy = (task['paidBy'] ?? 'vendor').toString().replaceAll('_', ' ');

    return _SectionCard(
      title: 'Delivery Task',
      icon: Icons.delivery_dining,
      iconColor: Colors.indigo,
      children: [
        _DetailRow('Rider', riderName),
        _DetailRow('Task Status', taskStatus.toString().replaceAll('_', ' ')),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(),
        ),
        _DetailRow('Pickup Fee', '₱${pickupFee.toStringAsFixed(2)}'),
        if (isExchange)
          _DetailRow('Delivery Fee', '₱${deliveryFee.toStringAsFixed(2)}'),
        _DetailRow('Total Fee', '₱${totalFee.toStringAsFixed(2)}'),
        _DetailRow('Paid By', paidBy),
      ],
    );
  }
}

// =============================================================================
// SHARED WIDGETS
// =============================================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: iconColor ?? AppColors.primary),
                  const SizedBox(width: 8),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            ...children,
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Flexible(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final reason = (item['reason'] ?? '').toString().replaceAll('_', ' ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
              color: Colors.grey[50],
              image: item['productImage'] != null
                  ? DecorationImage(
                      image: NetworkImage(item['productImage']),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: item['productImage'] == null
                ? Icon(Icons.image, size: 20, color: Colors.grey[400])
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['productName'] ?? 'Product',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Qty: ${item['quantity'] ?? 1} • $reason',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Text(
            '₱${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Color _color() {
    switch (status) {
      case 'requested':
      case 'pending_review':
        return Colors.orange;
      case 'approved':
      case 'pickup_scheduled':
      case 'picked_up':
      case 'in_transit':
      case 'received':
      case 'inspecting':
      case 'refund_processing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: c)),
        ],
      ),
    );
  }
}
