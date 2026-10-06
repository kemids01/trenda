// lib/features/home/presentation/widgets/shop_dock.dart
// The shop dock — a search field with the QR-scan and cart buttons beside it,
// docked directly above the bottom navigation bar.
//
// It is shown ONLY on the shopping tabs (Shop, Trenda, Food); the other tabs
// have nothing to search or add to a cart, so the dock is not built there.
//
// On every tab the field is a doorway to ONE search page (products, stores and
// ads — features/search/presentation/search_page.dart), opened in the tab's own
// scope: Shop → Everything, Trenda → Official, Food → Food. (Trenda used to
// filter its own grid in place; that left stores and ads unsearchable.)
// QR: Trenda opens the Official product scanner, the others the general
// barcode/store scanner.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../cart/providers/cart_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../search/presentation/visual_search_sheet.dart';
import '../../../search/providers/search_everything_provider.dart' show SearchScope;
import 'official_qr_scan.dart';

/// Which shopping surface the dock is serving.
enum ShopDockMode {
  shop(SearchScope.all, 'Search products, stores and ads'),
  trenda(SearchScope.official, 'Search Official Trenda'),
  food(SearchScope.food, 'Search food and restaurants');

  final SearchScope scope;
  final String hint;
  const ShopDockMode(this.scope, this.hint);
}

const Color _kGoldDark = Color(0xFFB8860B);

class ShopDock extends ConsumerStatefulWidget {
  final ShopDockMode mode;

  const ShopDock({super.key, required this.mode});

  @override
  ConsumerState<ShopDock> createState() => _ShopDockState();
}

class _ShopDockState extends ConsumerState<ShopDock> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isTrenda = widget.mode == ShopDockMode.trenda;
    final accent = isTrenda ? _kGoldDark : scheme.primary;
    final cartAsync = ref.watch(cartProvider);

    return Material(
      color: dark ? const Color(0xFF141922) : Colors.white,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          child: Row(
            children: [
              Expanded(
                child: _tapToSearch(scheme),
              ),
              const SizedBox(width: 8),
              _DockButton(
                icon: Icons.camera_alt_rounded,
                tooltip: 'Visual Camera Search',
                accent: accent,
                onPressed: () => VisualSearchSheet.show(context),
              ),
              const SizedBox(width: 8),
              _DockButton(
                icon: Icons.qr_code_scanner_rounded,
                tooltip: isTrenda ? 'Scan product QR' : 'Scan barcode or store QR',
                accent: accent,
                onPressed: () => isTrenda
                    ? scanOfficialQr(context)
                    : context.push(Routes.scanner),
              ),
              const SizedBox(width: 8),
              _DockButton(
                icon: Icons.shopping_cart_outlined,
                tooltip: 'Cart',
                accent: accent,
                badgeCount: cartAsync.maybeWhen(
                  data: (cart) => cart.itemCount,
                  orElse: () => 0,
                ),
                onPressed: () => context.push('/cart'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The search page owns the query, history and results — so this is a
  /// doorway to it (in this tab's scope), not a second field that would fight it.
  Widget _tapToSearch(ColorScheme scheme) {
    return InkWell(
      onTap: () => context.push(Routes.search, extra: {'scope': widget.mode.scope.param}),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: scheme.onSurface.withValues(alpha: 0.09)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                size: 19, color: scheme.onSurface.withValues(alpha: 0.45)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                widget.mode.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// A square action button sized to match the dock's search field, with an
/// optional count badge (the cart).
class _DockButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color accent;
  final int badgeCount;
  final VoidCallback onPressed;

  const _DockButton({
    required this.icon,
    required this.tooltip,
    required this.accent,
    required this.onPressed,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      width: 44,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Badge(
          label: Text('$badgeCount'),
          isLabelVisible: badgeCount > 0,
          child: Icon(icon, size: 21),
        ),
        style: IconButton.styleFrom(
          backgroundColor: accent.withValues(alpha: 0.11),
          foregroundColor: accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: accent.withValues(alpha: 0.22)),
          ),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
