// trenda_shared/lib/chat/chat_product_card.dart
// The product a chat is about, drawn the same way in the customer and vendor apps:
// pinned above the thread, and inline wherever the customer asked about an item.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatChatPrice(double price) =>
    NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(price);

/// A thread-width product card. [label] is the small caption above the name
/// ("ASKING ABOUT" pinned, "PRODUCT" inline).
class ChatProductCard extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double? price;
  final String label;
  final VoidCallback? onTap;

  /// Pinned: a full-width strip under the app bar. Inline: a rounded card in
  /// the thread, sized like a bubble.
  final bool pinned;

  const ChatProductCard({
    super.key,
    required this.name,
    this.imageUrl,
    this.price,
    this.label = 'PRODUCT',
    this.onTap,
    this.pinned = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: pinned ? 44 : 56,
            height: pinned ? 44 : 56,
            child: (imageUrl != null && imageUrl!.isNotEmpty)
                ? Image.network(imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(scheme))
                : _placeholder(scheme),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: pinned ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (!pinned && price != null) ...[
                const SizedBox(height: 2),
                Text(
                  formatChatPrice(price!),
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: scheme.primary),
                ),
              ],
            ],
          ),
        ),
        if (pinned && price != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              formatChatPrice(price!),
              style:
                  TextStyle(fontWeight: FontWeight.w800, color: scheme.primary),
            ),
          ),
        if (onTap != null)
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      ],
    );

    if (pinned) {
      return Material(
        color: scheme.surfaceContainerLow,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: content,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Material(
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.inventory_2_outlined,
            size: 20, color: scheme.onSurfaceVariant),
      );
}
