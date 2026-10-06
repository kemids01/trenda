// lib/features/orders/presentation/refund_request_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/app_colors.dart';
import '../data/orders_repository.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class RefundRequestPage extends ConsumerStatefulWidget {
  final String orderId;
  final String orderNumber;
  final double orderTotal;
  final List<Map<String, dynamic>> items;

  const RefundRequestPage({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.orderTotal,
    required this.items,
  });

  @override
  ConsumerState<RefundRequestPage> createState() => _RefundRequestPageState();
}

class _RefundRequestPageState extends ConsumerState<RefundRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  String _refundType = 'full';
  String _refundReason = 'damaged';
  final List<String> _selectedItems = [];
  bool _isSubmitting = false;

  final List<Map<String, String>> _refundReasons = [
    {'value': 'damaged', 'label': 'Item arrived damaged'},
    {'value': 'wrong_item', 'label': 'Received wrong item'},
    {'value': 'not_as_described', 'label': 'Item not as described'},
    {'value': 'quality_issue', 'label': 'Quality issues'},
    {'value': 'missing_item', 'label': 'Missing items in order'},
    {'value': 'other', 'label': 'Other reason'},
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitRefundRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_refundType == 'partial' && _selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select items for partial refund'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await OrdersRepository().requestRefund(
        orderId: widget.orderId,
        reason: _refundReason,
        description: _reasonController.text,
        refundType: _refundType,
        itemIds: _refundType == 'partial' ? _selectedItems : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refund request submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit refund: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Refund'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Order Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order ${widget.orderNumber}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: ₱${widget.orderTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Refund Type Selection
            const Text(
              'Refund Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Full Refund'),
                    subtitle: Text('₱${widget.orderTotal.toStringAsFixed(2)}'),
                    value: 'full',
                    groupValue: _refundType,
                    onChanged: (v) => setState(() => _refundType = v!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Partial Refund'),
                    subtitle: const Text('Select specific items'),
                    value: 'partial',
                    groupValue: _refundType,
                    onChanged: (v) => setState(() => _refundType = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Item Selection for Partial Refund
            if (_refundType == 'partial') ...[
              const Text(
                'Select Items to Refund',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: widget.items.map((item) {
                    final itemId = item['id']?.toString() ?? '';
                    final isSelected = _selectedItems.contains(itemId);
                    return CheckboxListTile(
                      title: Text(item['name'] ?? 'Unknown Item'),
                      subtitle: Text(
                        'Qty: ${item['quantity']} × ₱${item['price']}',
                      ),
                      value: isSelected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedItems.add(itemId);
                          } else {
                            _selectedItems.remove(itemId);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Reason Selection
            const Text(
              'Reason for Refund',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<String>(
                  initialValue: _refundReason,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                  items: _refundReasons.map((reason) {
                    return DropdownMenuItem(
                      value: reason['value'],
                      child: Text(reason['label']!),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _refundReason = v!),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Additional Details
            const Text(
              'Additional Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Please describe the issue in detail...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please provide details about the issue';
                }
                if (v.trim().length < 20) {
                  return 'Please provide more details (at least 20 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : () => TapGuard.run('refund_request.submitRefundRequest', _submitRefundRequest),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit Refund Request',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 16),

            // Note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Refund requests are typically processed within 3-5 business days. You will be notified once your request is reviewed.',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 13,
                      ),
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
}
