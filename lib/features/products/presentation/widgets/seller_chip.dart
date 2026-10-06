// lib/features/products/presentation/widgets/seller_chip.dart
// The shop this item came from, drawn as a miniature storefront: the same
// signboard and house colour the customer saw on the Stores street and on the
// store page, so the journey reads as one place.

import 'package:flutter/material.dart';
import '../../../stores/utils/storefront_style.dart';
import '../../utils/seller_label.dart';

class SellerChip extends StatelessWidget {
  /// Seed for the house colour — the vendor id, matching the street card.
  final String seed;
  final String storeName;
  final bool isOfficial;
  final bool isResale;

  /// Maker credited on a resold listing.
  final String? originalVendorStoreName;
  final VoidCallback onVisit;
  final VoidCallback? onChat;

  const SellerChip({
    super.key,
    required this.seed,
    required this.storeName,
    required this.onVisit,
    this.isOfficial = false,
    this.isResale = false,
    this.originalVendorStoreName,
    this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final house = isOfficial
        ? const Color(0xFFC79A3C) // Official Trenda wears brass, not an awning.
        : awningPaletteFor(seed, brightness: theme.brightness).stripe;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: house.withValues(alpha: 0.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Awning strip — a sliver of the shopfront.
          Container(height: 5, color: house.withValues(alpha: 0.85)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                _signboard(house),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SOLD BY',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: scheme.onSurface.withValues(alpha: 0.42),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sellerRoleLabel(
                          isOfficial: isOfficial,
                          isResale: isResale,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: house,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (onChat != null) ...[
                  _iconAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    tooltip: 'Message the shop',
                    color: house,
                    onPressed: onChat!,
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton(
                  onPressed: onVisit,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: house,
                    side: BorderSide(color: house.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Visit',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),

          // A resold listing credits whoever actually makes the thing.
          if (isResale &&
              originalVendorStoreName != null &&
              originalVendorStoreName!.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.04),
                border: Border(
                  top: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 15,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Originally from ',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                          TextSpan(
                            text: originalVendorStoreName!.trim(),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _signboard(Color house) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: house.withValues(alpha: 0.35), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        storeMonogram(storeName),
        style: TextStyle(
          color: house,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 34,
      width: 34,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 16, color: color),
        style: IconButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
