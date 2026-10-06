// lib/features/checkout/presentation/dynamic_fee_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/checkout_provider.dart';

/// Displays admin-configured dynamic fee thresholds as a motivational banner.
/// All text, thresholds, and labels come from DB. If disabled or no data → renders nothing.
class DynamicFeeBanner extends ConsumerWidget {
  final double orderTotal;
  final String municipality;

  const DynamicFeeBanner({
    super.key,
    required this.orderTotal,
    required this.municipality,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (municipality.isEmpty) return const SizedBox.shrink();

    final feesAsync = ref.watch(municipalityFeesProvider(municipality));

    return feesAsync.when(
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        if (!data.dynamicFees.enabled) return const SizedBox.shrink();
        if (data.dynamicFees.thresholds.isEmpty) return const SizedBox.shrink();

        return _buildBanner(context, data, ref);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBanner(
      BuildContext context, MunicipalityFeesResponse data, WidgetRef ref) {
    final thresholds = data.dynamicFees.thresholds;
    final guidance = data.customerGuidance;

    // Sort thresholds by maxOrderValue ascending
    final sorted = List<FeeThreshold>.from(thresholds)
      ..sort((a, b) {
        final aVal = a.maxOrderValue ?? double.infinity;
        final bVal = b.maxOrderValue ?? double.infinity;
        return aVal.compareTo(bVal);
      });

    // Find current tier and next tier
    FeeThreshold? currentTier;
    FeeThreshold? nextTier;

    for (int i = 0; i < sorted.length; i++) {
      final threshold = sorted[i];
      final maxVal = threshold.maxOrderValue ?? double.infinity;

      if (orderTotal <= maxVal) {
        nextTier = threshold;
        break;
      }
      currentTier = threshold;
    }

    // If we've passed all thresholds, we're at the max tier
    final isMaxTier = nextTier == null && currentTier != null;
    if (isMaxTier) {
      // Show achieved state
      return _buildAchievedBanner(context, currentTier, guidance);
    }

    if (nextTier == null) return const SizedBox.shrink();
    if (nextTier.label.isEmpty) return const SizedBox.shrink();

    final targetValue = nextTier.maxOrderValue;
    if (targetValue == null) return const SizedBox.shrink();

    final remaining = targetValue - orderTotal;
    final progress = (orderTotal / targetValue).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade50, Colors.teal.shade100],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.discount, color: Colors.teal.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '₱${remaining.toStringAsFixed(0)} more to unlock: ${nextTier.label}',
                  style: TextStyle(
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (guidance.feeExplanation.isNotEmpty)
                GestureDetector(
                  onTap: () => _showGuidanceSheet(context, guidance),
                  child: Icon(Icons.info_outline,
                      size: 18, color: Colors.teal.shade400),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.teal.shade100,
              color: Colors.teal.shade600,
              minHeight: 6,
            ),
          ),
          // Show multiplier hints
          if (nextTier.deliveryFeeMultiplier < 1.0) ...[
            const SizedBox(height: 6),
            Text(
              '${((1 - nextTier.deliveryFeeMultiplier) * 100).toStringAsFixed(0)}% off delivery fees at this tier',
              style: TextStyle(
                fontSize: 11,
                color: Colors.teal.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAchievedBanner(
      BuildContext context, FeeThreshold tier, CustomerGuidance guidance) {
    if (tier.label.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '✨ ${tier.label}',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          if (guidance.feeExplanation.isNotEmpty)
            GestureDetector(
              onTap: () => _showGuidanceSheet(context, guidance),
              child: Icon(Icons.info_outline,
                  size: 18, color: Colors.green.shade400),
            ),
        ],
      ),
    );
  }

  void _showGuidanceSheet(BuildContext context, CustomerGuidance guidance) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Fee Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (guidance.feeExplanation.isNotEmpty) ...[
              Text(guidance.feeExplanation,
                  style: const TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 16),
            ],
            if (guidance.tooltips.deliveryFee.isNotEmpty) ...[
              _buildTooltipRow(Icons.local_shipping, 'Delivery Fee',
                  guidance.tooltips.deliveryFee),
              const SizedBox(height: 8),
            ],
            if (guidance.tooltips.platformFee.isNotEmpty) ...[
              _buildTooltipRow(Icons.storefront, 'Platform Fee',
                  guidance.tooltips.platformFee),
              const SizedBox(height: 8),
            ],
            if (guidance.tooltips.freeDelivery.isNotEmpty) ...[
              _buildTooltipRow(Icons.card_giftcard, 'Free Delivery',
                  guidance.tooltips.freeDelivery),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltipRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              Text(description,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
