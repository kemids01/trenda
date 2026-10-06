// trenda_frontend/lib/features/orders/presentation/widgets/rate_delivery_dialog.dart
// Rating dialog for completed deliveries - Connected to backend API
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trenda_shared/core/config.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class RateDeliveryDialog extends ConsumerStatefulWidget {
  final String orderId;
  final VoidCallback? onRated;

  const RateDeliveryDialog({
    super.key,
    required this.orderId,
    this.onRated,
  });

  @override
  ConsumerState<RateDeliveryDialog> createState() => _RateDeliveryDialogState();

  /// Show rating dialog
  static Future<void> show(BuildContext context, String orderId,
      {VoidCallback? onRated}) {
    return showDialog(
      context: context,
      builder: (_) => RateDeliveryDialog(orderId: orderId, onRated: onRated),
    );
  }
}

class _RateDeliveryDialogState extends ConsumerState<RateDeliveryDialog> {
  int _deliveryRating = 0;
  int _productRating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  final List<String> _selectedTags = [];

  final List<_TagOption> _positiveTags = [
    _TagOption('fast_delivery', '🚀 Fast Delivery'),
    _TagOption('polite_rider', '😊 Polite Rider'),
    _TagOption('good_packaging', '📦 Good Packaging'),
    _TagOption('fresh_food', '🥗 Fresh Food'),
    _TagOption('accurate_order', '✅ Accurate Order'),
  ];

  final List<_TagOption> _negativeTags = [
    _TagOption('slow_delivery', '🐢 Slow Delivery'),
    _TagOption('rude_rider', '😡 Rude Rider'),
    _TagOption('damaged_packaging', '💔 Damaged Packaging'),
    _TagOption('cold_food', '🥶 Cold Food'),
    _TagOption('wrong_items', '❌ Wrong Items'),
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_deliveryRating == 0 || _productRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please rate both delivery and product')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final token = await user.getIdToken();
      final dio = Dio();

      await dio.post(
        '${AppConfig.backendBaseUrl}/api/ratings/delivery',
        data: {
          'orderId': widget.orderId,
          'deliveryRating': _deliveryRating,
          'productRating': _productRating,
          'comment': _commentController.text.trim(),
          'tags': _selectedTags,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onRated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to submit: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final averageRating = (_deliveryRating + _productRating) / 2;
    final isPositive = averageRating >= 4;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Rate Your Experience',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Delivery Rating
                const Text('Delivery Service',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildStarRating(
                  rating: _deliveryRating,
                  onChanged: (val) => setState(() => _deliveryRating = val),
                ),
                const SizedBox(height: 20),

                // Product Rating
                const Text('Product Quality',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildStarRating(
                  rating: _productRating,
                  onChanged: (val) => setState(() => _productRating = val),
                ),
                const SizedBox(height: 20),

                // Tags (show based on rating)
                if (_deliveryRating > 0 && _productRating > 0) ...[
                  Text(
                    isPositive ? 'What did you like?' : 'What went wrong?',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        (isPositive ? _positiveTags : _negativeTags).map((tag) {
                      final isSelected = _selectedTags.contains(tag.id);
                      return FilterChip(
                        label: Text(tag.label),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTags.add(tag.id);
                            } else {
                              _selectedTags.remove(tag.id);
                            }
                          });
                        },
                        selectedColor: isPositive
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // Comment
                TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Leave a comment (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Later'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : () => TapGuard.run('rate_delivery.submitRating', _submitRating),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Submit'),
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

  Widget _buildStarRating({
    required int rating,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return IconButton(
          onPressed: () => onChanged(starValue),
          icon: Icon(
            starValue <= rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 36,
          ),
        );
      }),
    );
  }
}

class _TagOption {
  final String id;
  final String label;
  _TagOption(this.id, this.label);
}
