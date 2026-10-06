// lib/widgets/ad_transparency_modal.dart
// "Why am I seeing this ad?" disclosure modal

import 'package:flutter/material.dart';
import 'package:trenda_shared/data/ads_repository.dart';

/// Ad transparency modal for GDPR/Privacy compliance
class AdTransparencyModal extends StatelessWidget {
  final Map<String, dynamic> adData;
  final VoidCallback? onClose;

  const AdTransparencyModal({
    super.key,
    required this.adData,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final targetingReasons = _getTargetingReasons();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Why am I seeing this ad?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose ?? () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),

          const Divider(height: 24),

          // Advertiser info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    (adData['vendorName'] ?? 'Ad')[0].toUpperCase(),
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This ad is from',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        adData['vendorName'] ?? 'A Trenda Vendor',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Targeting reasons
          const Text(
            'This ad was shown to you because:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          ...targetingReasons.map((reason) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      reason['icon'] as IconData,
                      size: 18,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        reason['text'] as String,
                        style: TextStyle(
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 16),

          // Privacy note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.privacy_tip_outlined,
                    color: Colors.amber[700], size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'We do not share your personal information with advertisers.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[900],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _hideAd(context),
                  icon: const Icon(Icons.visibility_off, size: 18),
                  label: const Text('Hide this ad'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reportAd(context),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Report ad'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Manage preferences
          Center(
            child: TextButton(
              onPressed: () => _managePreferences(context),
              child: const Text('Manage ad preferences'),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getTargetingReasons() {
    final reasons = <Map<String, dynamic>>[];
    final targeting = adData['targeting'] as Map<String, dynamic>? ?? {};

    // Location-based
    if (targeting['municipality'] != null ||
        targeting['locationBased'] == true) {
      reasons.add({
        'icon': Icons.location_on_outlined,
        'text':
            'You are in or near ${targeting['municipality'] ?? 'the target area'}',
      });
    }

    // Category interest
    if (targeting['category'] != null) {
      reasons.add({
        'icon': Icons.category_outlined,
        'text': 'You\'ve shown interest in ${targeting['category']} products',
      });
    }

    // Recent activity
    if (targeting['recentlyViewed'] == true) {
      reasons.add({
        'icon': Icons.history,
        'text': 'Based on products you recently viewed',
      });
    }

    // Purchase history
    if (targeting['purchaseHistory'] == true) {
      reasons.add({
        'icon': Icons.shopping_bag_outlined,
        'text': 'Based on your purchase history',
      });
    }

    // Default reason
    if (reasons.isEmpty) {
      reasons.add({
        'icon': Icons.storefront_outlined,
        'text': 'This is a promoted product from a local vendor',
      });
      reasons.add({
        'icon': Icons.people_outline,
        'text': 'Shown to users in your area',
      });
    }

    return reasons;
  }

  void _hideAd(BuildContext context) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You won\'t see this ad again'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _reportAd(BuildContext context) {
    Navigator.pop(context);

    // Map UI labels → backend enum values
    final reasons = {
      'Misleading or scam': 'misleading',
      'Inappropriate content': 'inappropriate_content',
      'Spam': 'spam',
      'Offensive': 'offensive',
      'Fraud / suspicious': 'fraud',
      'Other': 'other',
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Ad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.entries
              .map((e) => _buildReportOption(ctx, e.key, e.value))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildReportOption(BuildContext context, String label, String reason) {
    final adId = adData['_id'] ?? adData['id'] ?? '';
    return ListTile(
      title: Text(label),
      onTap: () async {
        Navigator.pop(context);
        if (adId.toString().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to report — ad ID missing'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        try {
          await AdsRepository().reportAd(adId.toString(), reason: reason);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Thank you. Our team will review this ad.'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            final msg = e.toString();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg.contains('already reported')
                    ? 'You have already reported this ad'
                    : 'Failed to report ad. Please try again.'),
                backgroundColor: msg.contains('already reported')
                    ? Colors.orange
                    : Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    );
  }

  void _managePreferences(BuildContext context) {
    Navigator.pop(context);
    // Navigate to ad preferences page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ad preferences coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show the modal
  static void show(BuildContext context, Map<String, dynamic> adData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdTransparencyModal(adData: adData),
    );
  }
}
