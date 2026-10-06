// lib/widgets/price_comparison.dart
import 'package:flutter/material.dart';

/// Displays an official product's price with an optional strike-through comparison.
/// When [currentPrice] < [originalPrice], shows the struck original, the emphasized
/// current price, and a savings-% badge. Otherwise just the price. Pure display.
class PriceComparisonWidget extends StatelessWidget {
  final num originalPrice;
  final num currentPrice;
  final String currency;
  final TextStyle? currentStyle;

  const PriceComparisonWidget({
    super.key,
    required this.originalPrice,
    required this.currentPrice,
    this.currency = '₱',
    this.currentStyle,
  });

  bool get _onSale => currentPrice < originalPrice && originalPrice > 0;
  int get _percent => _onSale ? (((originalPrice - currentPrice) / originalPrice) * 100).round() : 0;
  String _fmt(num v) => '$currency${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = Text(
      _fmt(currentPrice),
      style: currentStyle ??
          theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
    );
    if (!_onSale) return current;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        current,
        Text(
          _fmt(originalPrice),
          style: theme.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough, color: theme.hintColor),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(4)),
          child: Text('-$_percent%',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
