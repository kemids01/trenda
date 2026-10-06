// lib/features/orders/presentation/widgets/order_status_badge.dart
// One badge for an order's status, wherever it appears.
//
// The three order cards each had their own switch over the status string, so
// the same order could be named differently depending on which tab it was in.
// Wording and tone now come from utils/order_presentation.dart; this only
// decides how a tone looks.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../utils/order_presentation.dart';

/// The colour each tone wears. Chosen to hold up on both themes.
({Color fg, Color bg}) orderToneColors(OrderTone tone, Brightness brightness) {
  final dark = brightness == Brightness.dark;

  Color base;
  switch (tone) {
    case OrderTone.waiting:
      base = const Color(0xFFB45309);
    case OrderTone.inProgress:
      base = const Color(0xFF1E4FA3);
    case OrderTone.arriving:
      base = const Color(0xFF157347);
    case OrderTone.done:
      base = const Color(0xFF157347);
    case OrderTone.stopped:
      base = const Color(0xFFDC2626);
  }

  return (
    fg: dark ? Color.lerp(base, Colors.white, 0.45)! : base,
    bg: base.withValues(alpha: dark ? 0.18 : 0.10),
  );
}

class OrderStatusBadge extends StatelessWidget {
  final String status;
  final bool compact;

  const OrderStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final view = orderStatusView(status);
    final colors = orderToneColors(view.tone, Theme.of(context).brightness);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        view.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.fg,
          fontSize: compact ? 10 : 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Shared empty state for the order tabs. The three lists each had their own
/// near-identical copy, and none of them offered a way out of the screen.
class OrdersEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const OrdersEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 90),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      size: 34,
                      color: scheme.onSurface.withValues(alpha: 0.35)),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.storefront_rounded, size: 18),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A line item's picture on an order card.
class OrderItemThumb extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const OrderItemThumb({super.key, this.imageUrl, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = imageUrl?.trim() ?? '';

    final fallback = Container(
      width: size,
      height: size,
      color: scheme.onSurface.withValues(alpha: 0.05),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: size * 0.42,
        color: scheme.onSurface.withValues(alpha: 0.3),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            ),
    );
  }
}
