// lib/features/home/presentation/widgets/shop_stores_row.dart
// The "Stores" block at the top of a Shop-tab page (the store-category pages
// and Palengke): a titled, swipeable row of store cards. Each page puts its
// Official ad slot right under it. One widget so both pages look the same.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/stores_provider.dart';
import 'shop_card_grid.dart' show kShopStoreCardDetailsHeight;
import 'shop_store_card.dart';

/// Width of a store card in the row.
const double kShopStoresRowCardWidth = 150;

/// A section heading: icon, title and an optional count pill.
class ShopSectionTitle extends StatelessWidget {
  const ShopSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 17, color: accent),
          const SizedBox(width: 7),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                trailing!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A muted one-line note (empty or error state).
class ShopNote extends StatelessWidget {
  const ShopNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
}

/// "Stores" title + the swipeable store row, from an async store list.
class ShopStoresRow extends StatelessWidget {
  const ShopStoresRow({
    super.key,
    required this.stores,
    required this.accent,
    required this.emptyText,
  });

  final AsyncValue<List<StoreData>> stores;
  final Color accent;

  /// Shown when the list loads empty, e.g. "No Palengke stores in your city yet."
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShopSectionTitle(
          icon: Icons.storefront_rounded,
          title: 'Stores',
          accent: accent,
          trailing: stores.maybeWhen(
            data: (s) => s.isEmpty ? null : '${s.length}',
            orElse: () => null,
          ),
        ),
        stores.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const ShopNote('Could not load the stores.'),
          data: (list) => list.isEmpty
              ? ShopNote(emptyText)
              : SizedBox(
                  height: kShopStoresRowCardWidth + kShopStoreCardDetailsHeight,
                  child: ListView.separated(
                    key: const ValueKey('shop-stores-row'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) => ShopStoreCard(
                      store: list[i],
                      width: kShopStoresRowCardWidth,
                      onTap: () => context.push('/store/${list[i].id}'),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
