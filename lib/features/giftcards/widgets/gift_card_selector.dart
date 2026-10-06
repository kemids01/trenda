// trenda_frontend/lib/features/giftcards/widgets/gift_card_selector.dart
//
// Checkout: pick a claimed gift card to pay for the items.
//
// ⚠️ The figure shown here MUST match what the server charges. It applies min(balance,
// subtotal − discount) and never touches the delivery fee, so the customer always hands the rider
// cash at the door. See trenda_backend/docs/GIFT_CARDS.md §4.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/gift_card_support.dart';
import '../providers/gift_card_provider.dart';

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);

class GiftCardSelector extends ConsumerWidget {
  /// Goods subtotal — the only thing a gift card can pay for.
  final double subtotal;

  /// Coupon discount already applied to the goods.
  final double discount;

  /// Full order total including delivery, for the cash-due line.
  final double total;

  const GiftCardSelector({
    super.key,
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(spendableGiftCardsProvider);
    final selectedCode = ref.watch(selectedGiftCardCodeProvider);
    final theme = Theme.of(context);

    return cardsAsync.when(
      // A checkout must never be blocked by this panel: if the cards cannot be loaded, the
      // customer simply pays the normal way.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (cards) {
        if (cards.isEmpty) return const SizedBox.shrink();

        final selected = cards.where((c) => c.code == selectedCode).firstOrNull;
        final applied = selected?.appliedTo(subtotal: subtotal, discount: discount) ?? 0.0;
        final due = cashDue(total: total, applied: applied);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.card_giftcard, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Gift card', style: theme.textTheme.titleSmall),
                    const Spacer(),
                    if (selected != null)
                      TextButton(
                        onPressed: () =>
                            ref.read(selectedGiftCardCodeProvider.notifier).state = null,
                        child: const Text('Remove'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final card in cards)
                  RadioListTile<String?>(
                    value: card.code,
                    // ignore: deprecated_member_use
                    groupValue: selectedCode,
                    // ignore: deprecated_member_use
                    onChanged: (v) =>
                        ref.read(selectedGiftCardCodeProvider.notifier).state = v,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(card.code, style: theme.textTheme.bodyMedium),
                    subtitle: Text(
                      '${_peso.format(card.balance)} available',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (selected != null) ...[
                  const Divider(height: 18),
                  _Line(
                    label: 'Gift card pays',
                    value: '−${_peso.format(applied)}',
                    emphasis: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 4),
                  _Line(
                    label: 'Cash due on delivery',
                    value: _peso.format(due),
                    bold: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gift cards pay for items only. The delivery fee is always paid in cash.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? emphasis;
  const _Line({
    required this.label,
    required this.value,
    this.bold = false,
    this.emphasis,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: emphasis,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(value, style: style),
      ],
    );
  }
}
