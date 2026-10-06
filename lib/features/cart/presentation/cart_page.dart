// lib/features/cart/presentation/cart_page.dart
// The basket, grouped by shop.
//
// Trenda is multi-vendor and municipality-scoped: a basket holding three shops
// is three pickups, and checkout prices each one. A flat list hid that, so the
// cart now heads each group with the shop's own signboard and house colour —
// the same shopfront language as the Stores street and the store page.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_frontend/features/cart/models/cart_model.dart';
import 'package:trenda_frontend/features/core/widgets/frontend_official_ad_slot.dart';
import 'package:trenda_frontend/features/core/widgets/official_tag.dart';
import 'package:trenda_frontend/features/home/utils/home_rails.dart';
import 'package:trenda_frontend/features/home/utils/official_store_filters.dart';
import '../../checkout/utils/store_grouping.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/error_handler.dart';
import '../../stores/utils/storefront_style.dart';
import '../providers/cart_provider.dart';
import '../utils/cart_lines.dart';
import '../widgets/quantity_input.dart';
import 'package:trenda_shared/core/taps/taps.dart';

/// Runs one cart write and, if it fails, tells the shopper why (the server's own
/// words when it gave any). The steppers and the empty-basket button used to fire
/// and forget, so a refused change looked like a button that did nothing.
Future<void> _cartWrite(
  BuildContext context,
  WidgetRef ref,
  Future<bool> Function(CartNotifier cart) write,
) async {
  // Captured before the await: the line may be gone from the tree afterwards.
  final messenger = ScaffoldMessenger.of(context);
  final cart = ref.read(cartProvider.notifier);
  if (await write(cart)) return;
  messenger.showSnackBar(SnackBar(
    content: Text(cart.lastError ?? "Couldn't update your cart"),
    backgroundColor: Colors.red,
  ));
}

/// Ticks or unticks [ids] for checkout. Unticked lines stay in the cart.
void _setSelected(WidgetRef ref, Iterable<String> ids, bool selected) {
  final notifier = ref.read(deselectedCartItemsProvider.notifier);
  final next = {...notifier.state};
  selected ? next.removeAll(ids) : next.addAll(ids);
  notifier.state = next;
}

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cartAsync = ref.watch(cartProvider);
    final items = cartAsync.valueOrNull?.items ?? const <CartItem>[];

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF0E1116)
          : const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Your Cart'),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, ref),
              child: Text(
                'Clear',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: AsyncBuilder(
        asyncValue: cartAsync,
        onRetry: () => ref.read(cartProvider.notifier).loadCart(),
        emptyMessage: 'Your cart is empty',
        builder: (cart) {
          if (cart.items.isEmpty) {
            return EmptyDisplay(
              title: 'Your cart is empty',
              message: 'Browse the shops near you and add something to it',
              icon: Icons.shopping_basket_outlined,
              onAction: () => context.go('/main'),
              actionLabel: 'Start shopping',
            );
          }

          final groups = groupItemsByStore(cart.items);
          final selected =
              ref.watch(checkoutCartProvider).valueOrNull ?? cart;
          final blockerSummary = cartBlockerSummary(selected.items);
          final allSelected = selected.items.length == cart.items.length;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 16),
                  children: [
                    const FrontendOfficialAdSlot(slotId: 'frontend.cart.top'),
                    if (blockerSummary != null) ...[
                      const SizedBox(height: 8),
                      _BlockerBanner(message: blockerSummary),
                    ],
                    const SizedBox(height: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _setSelected(
                          ref, cart.items.map((i) => i.id), !allSelected),
                      child: Row(
                        children: [
                          Checkbox(
                            value: allSelected
                                ? true
                                : (selected.items.isEmpty ? false : null),
                            tristate: true,
                            onChanged: (_) => _setSelected(
                                ref, cart.items.map((i) => i.id), !allSelected),
                          ),
                          Text(
                            'Select all (${cart.items.length})',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final group in groups) ...[
                      _StoreGroupCard(group: group),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              CartSummary(cart: selected),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty your cart?'),
        content: const Text('Everything in it will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Empty cart'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await _cartWrite(context, ref, (cart) => cart.clearCart());
    }
  }
}

// ============================================================================
// ONE SHOP'S ITEMS
// ============================================================================

class _StoreGroupCard extends ConsumerWidget {
  final StoreGroup group;

  const _StoreGroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final first = group.items.first;
    final official =
        isOfficialStore(vendorId: first.vendorId, storeName: first.storeName);
    final house = official
        ? const Color(0xFFC79A3C)
        : awningPaletteFor(
            group.vendorId.isNotEmpty ? group.vendorId : group.storeName,
            brightness: theme.brightness,
          ).stripe;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white12
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Awning strip — a sliver of this shop's front.
          Container(height: 4, color: house.withValues(alpha: 0.85)),
          InkWell(
            onTap: group.vendorId.isEmpty
                ? null
                : () => context.push('/store/${group.vendorId}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 7, 8, 7),
              child: Row(
                children: [
                  Builder(builder: (context) {
                    final excluded = ref.watch(deselectedCartItemsProvider);
                    final ids = group.items.map((i) => i.id);
                    final off = ids.where(excluded.contains).length;
                    final value = off == 0
                        ? true
                        : (off == group.items.length ? false : null);
                    return Checkbox(
                      value: value,
                      tristate: true,
                      activeColor: house,
                      onChanged: (_) => _setSelected(ref, ids, value != true),
                    );
                  }),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: house.withValues(alpha: 0.4),
                        width: 1.4,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      storeMonogram(group.storeName),
                      style: TextStyle(
                        color: house,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          '${group.itemCount} '
                          '${group.itemCount == 1 ? 'item' : 'items'} · '
                          '${shelfPrice(group.subtotal)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (official) const OfficialTag(compact: true),
                  if (group.vendorId.isNotEmpty)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: scheme.onSurface.withValues(alpha: 0.3),
                    ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          for (var i = 0; i < group.items.length; i++) ...[
            CartItemCard(item: group.items[i], accent: house),
            if (i != group.items.length - 1)
              Divider(
                height: 1,
                indent: 80,
                color: theme.dividerColor,
              ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// ONE LINE
// ============================================================================

class CartItemCard extends ConsumerStatefulWidget {
  final CartItem item;
  final Color accent;

  const CartItemCard({
    super.key,
    required this.item,
    this.accent = const Color(0xFF2563EB),
  });

  @override
  ConsumerState<CartItemCard> createState() => _CartItemCardState();
}

class _CartItemCardState extends ConsumerState<CartItemCard> {
  CartItem get item => widget.item;
  Color get accent => widget.accent;

  /// The quantity being typed, so the line total follows the digits before
  /// they reach the server. Null = show the saved quantity.
  int? _draft;

  @override
  void didUpdateWidget(CartItemCard old) {
    super.didUpdateWidget(old);
    if (old.item.quantity != item.quantity) _draft = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = cartLineStatus(item);
    final qty = _draft ?? item.quantity;
    final lineTotal = _draft == null ? item.subtotal : item.price * qty;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        color: scheme.error,
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 24),
      ),
      onDismissed: (_) => _remove(context, ref),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 9, 8, 9),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Checkbox(
                    value: !ref
                        .watch(deselectedCartItemsProvider)
                        .contains(item.id),
                    activeColor: accent,
                    visualDensity: VisualDensity.compact,
                    onChanged: (v) => _setSelected(ref, [item.id], v ?? false),
                  ),
                ),
                _photo(context),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                height: 1.25,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, size: 15),
                              tooltip: 'Remove',
                              color: scheme.onSurface.withValues(alpha: 0.45),
                              padding: EdgeInsets.zero,
                              onPressed: () => TapGuard.run('cart.remove', () => _remove(context, ref)),
                            ),
                          ),
                        ],
                      ),

                      // The variant the shopper actually chose. The cart parsed
                      // this and never showed it, so two sizes of one product
                      // were indistinguishable in the basket.
                      if ((item.variantName ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.onSurface.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.variantName!.trim(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                      ],

                      if (item.onModel == 'Bundle') ...[
                        const SizedBox(height: 3),
                        _tag('BUNDLE', const Color(0xFF6B3A6E)),
                      ],

                      const SizedBox(height: 6),
                      Row(
                        children: [
                          QuantityInput(
                            value: item.quantity,
                            max: item.stock > 0 ? item.stock : null,
                            accent: accent,
                            onDraft: (q) => setState(() => _draft = q),
                            onLimit: (max) => _showLimit(context, max),
                            onChanged: (q) => _cartWrite(context, ref,
                                (cart) => cart.updateQuantity(item.id, q)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Line total — follows the typed quantity, so
                                // the bill is visible before it is committed.
                                Text(
                                  '₱${lineTotal.toStringAsFixed(2)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                if (qty > 1)
                                  Text(
                                    '₱${item.price.toStringAsFixed(2)} each',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!status.isFine) ...[
              const SizedBox(height: 10),
              _issueRow(context, ref, status),
            ],
          ],
        ),
      ),
    );
  }

  Widget _photo(BuildContext context) {
    final plate = Container(
      width: 60,
      height: 60,
      color: accent.withValues(alpha: 0.08),
      child: Icon(Icons.image_outlined,
          size: 20, color: accent.withValues(alpha: 0.4)),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: item.image.trim().isEmpty
          ? plate
          : CachedNetworkImage(
              imageUrl: item.image,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              placeholder: (_, __) => plate,
              errorWidget: (_, __, ___) => plate,
            ),
    );
  }

  /// A typed or stepped quantity past the shelf is cut down; say why.
  void _showLimit(BuildContext context, int max) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Only $max left at this shop'),
        duration: const Duration(seconds: 2),
      ));
  }

  Widget _issueRow(BuildContext context, WidgetRef ref, CartLineStatus status) {
    final message = cartLineMessage(status);
    final color = status.blocksCheckout
        ? const Color(0xFFDC2626)
        : const Color(0xFFB45309);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            status.blocksCheckout
                ? Icons.error_outline_rounded
                : Icons.schedule_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message.label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          if (message.action != null)
            TextButton(
              onPressed: () => TapGuard.run('cart.remove', () async {
                if (status.issue == CartLineIssue.outOfStock) {
                  await _remove(context, ref);
                } else {
                  _cartWrite(context, ref,
                      (cart) => cart.updateQuantity(item.id, status.available));
                }
              }),
              style: TextButton.styleFrom(
                foregroundColor: color,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
              ),
              child: Text(
                message.action!,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }

  /// Removing is one swipe or one tap away, so it needs a way back — the cart
  /// used to drop an item with no undo at all.
  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(cartProvider.notifier);
    final product = item.product;
    final quantity = item.quantity;

    final removed = await notifier.removeFromCart(item.id);
    if (!context.mounted) return;

    messenger.hideCurrentSnackBar();
    if (!removed) {
      // It used to say "removed" (with Undo) even when the server refused.
      messenger.showSnackBar(SnackBar(
        content: Text(notifier.lastError ?? "Couldn't remove this item"),
        backgroundColor: Colors.red,
      ));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('${item.name} removed'),
        duration: const Duration(seconds: 4),
        // Undo needs the product object to re-add; a bundle line cannot be
        // restored through addToCart, so it is offered only where it works.
        action: product == null
            ? null
            : SnackBarAction(
                label: 'Undo',
                onPressed: () => notifier.addToCart(
                  product,
                  quantity: quantity,
                  variantId: item.variantId,
                ),
              ),
      ),
    );
  }
}

// ============================================================================
// SUMMARY
// ============================================================================

class CartSummary extends ConsumerWidget {
  final CartModel cart;

  const CartSummary({super.key, required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final blocked = blockedLines(cart.items);
    final canCheckout = blocked.isEmpty && cart.items.isNotEmpty;
    final shops = groupItemsByStore(cart.items).length;
    final units = cart.items.fold<int>(0, (sum, i) => sum + i.quantity);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.4 : 0.08,
            ),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$units ${units == 1 ? 'item' : 'items'}'
                          '${shops > 1 ? ' from $shops shops' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₱${cart.subtotal.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          'Delivery calculated at checkout',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: scheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: canCheckout
                          ? () => context.push(Routes.checkout)
                          : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Checkout',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 17),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (!canCheckout) ...[
                const SizedBox(height: 8),
                Text(
                  cart.items.isEmpty
                      ? 'Tick the items you want to check out'
                      : 'Sort out the flagged items to continue',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// BASKET-WIDE WARNING
// ============================================================================

class _BlockerBanner extends StatelessWidget {
  final String message;

  const _BlockerBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 17, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
