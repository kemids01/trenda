// lib/features/products/presentation/product_details_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:trenda_shared/models/product_model.dart';
import 'package:trenda_shared/core/trenda_qr.dart';
import 'package:trenda_shared/widgets/map_pin_button.dart';
import 'package:trenda_frontend/features/core/widgets/frontend_official_ad_slot.dart';
import 'package:go_router/go_router.dart';
import '../providers/products_provider.dart';
import '../utils/price_display.dart';
import '../widgets/product_card_parts.dart';
import '../../installment/widgets/installment_calculator.dart';
import 'widgets/product_specs_section.dart';

import '../../cart/providers/cart_provider.dart';
import '../../auth/data/providers.dart';
import '../../core/router/app_router.dart';
import '../providers/recently_viewed_provider.dart';
import '../providers/comparison_provider.dart';
import '../../reviews/providers/reviews_provider.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../../core/providers/municipality_provider.dart';
import '../../stores/widgets/closed_store_dialog.dart';
import '../../home/utils/official_store_filters.dart';
import '../../home/providers/official_store_provider.dart';
import '../../home/presentation/widgets/official_product_card.dart';
import 'package:share_plus/share_plus.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/utils/chat_errors.dart';
import '../../stores/utils/storefront_style.dart';
import '../utils/seller_label.dart';
import 'widgets/product_gallery.dart';
import 'widgets/seller_chip.dart';
import '../../cart/widgets/quantity_input.dart';
import '../../home/providers/flash_sale_provider.dart';
import '../../home/presentation/widgets/flash_sale_band.dart';
import 'package:trenda_shared/core/timezone.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/swipe_down_to_dismiss.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class ProductDetailsPage extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailsPage({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  dynamic _selectedVariant;
  int _quantity = 1;
  bool _isAddingToCart = false;
  bool _descriptionOpen = false;

  /// The seller's house colour — the same awning the shop wears on the Stores
  /// street and on its store page, so an item stays visibly tied to its shop.
  /// Official Trenda products wear brass instead.
  Color _houseColor(ProductModel product) {
    if (isOfficialProduct(product)) return const Color(0xFFC79A3C);
    final seed = product.vendorId.isNotEmpty
        ? product.vendorId
        : (product.storeName ?? product.id);
    return awningPaletteFor(seed, brightness: Theme.of(context).brightness)
        .stripe;
  }

  /// Set once per build from the product on screen, so the accents throughout
  /// the page follow the seller instead of the hardcoded blue this page used
  /// for every product regardless of who was selling it.
  Color _house = const Color(0xFF2563EB);

  /// The live flash deal on the product on screen, if any.
  ({FlashSale sale, FlashItem item})? _deal;

  List<Color> get _brandGradient =>
      [_house, Color.lerp(_house, Colors.black, 0.24)!];

  /// The page's list — SwipeDownToDismiss watches it to pull only from the top.
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pull down from the top to close (route: swipeDismissiblePage in app_router.dart).
    return SwipeDownToDismiss(
      controller: _scroll,
      builder: (context, physics) => _buildPage(context, physics),
    );
  }

  Widget _buildPage(BuildContext context, ScrollPhysics physics) {
    final productAsync = ref.watch(productDetailsProvider(widget.productId));
    final authState = ref.watch(authNotifierProvider);
    final isLoggedIn = authState.user != null;

    return Scaffold(
      body: productAsync.when(
        data: (product) {
          if (product == null) {
            return const Center(child: Text('Product not found'));
          }

          // Auto-select first variant if product has variants and none selected
          if (product.hasVariants &&
              _selectedVariant == null &&
              product.variants.isNotEmpty) {
            // Auto-select if only one variant, or first available variant
            final availableVariants =
                product.variants.where((v) => v.stock > 0).toList();
            if (availableVariants.length == 1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _selectedVariant == null) {
                  setState(() => _selectedVariant = availableVariants.first);
                }
              });
            }
          }

          // Track this product as recently viewed
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(recentlyViewedProvider.notifier).addProduct(product);
          });

          _house = _houseColor(product);
          // ⚡ A live flash deal on this product (same feed as the Shop tab band).
          // Display only — the cart and checkout re-price on the server.
          _deal = ref.watch(flashSaleFeedProvider).valueOrNull?.dealFor(product.id);

          return CustomScrollView(
            controller: _scroll,
            physics: physics,
            slivers: [
              _buildSliverAppBar(product),
              const SliverToBoxAdapter(
                child: FrontendOfficialAdSlot(
                    slotId: 'frontend.product.details_top'),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isOfficialProduct(product)) ...[
                        _buildOfficialBanner(),
                        const SizedBox(height: 6),
                      ],
                      if (_deal != null) ...[
                        FlashDealStrip(
                          sale: _deal!.sale,
                          item: _deal!.item,
                          onEnded: () => ref.invalidate(flashSaleFeedProvider),
                        ),
                        const SizedBox(height: 6),
                      ],
                      // Name, price, stock, options and quantity in ONE card —
                      // everything needed to buy sits above the fold.
                      _buildProductHeaderBox(product),
                      const SizedBox(height: 6),
                      _buildDescription(product),
                      const SizedBox(height: 6),
                      // 🧾 Big-ticket specifications (empty for non-spec listings)
                      ProductSpecsSection(product: product),
                      // 💳 Installment Calculator
                      InstallmentCalculatorWidget(product: product),
                      const SizedBox(height: 6),
                      _buildExpandableSection(
                        title: 'Vendor',
                        content: _buildVendorInfo(product),
                        compact: true,
                      ),
                      const SizedBox(height: 6),
                      _buildExpandableSection(
                        title: 'Delivery',
                        content: _buildShippingInfo(product),
                        compact: true,
                      ),
                      const SizedBox(height: 6),
                      _buildReviewsSection(product),
                      if (isOfficialProduct(product)) ...[
                        const SizedBox(height: 12),
                        _buildRelatedOfficial(product),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      bottomNavigationBar: productAsync.whenOrNull(
        data: (product) =>
            product != null ? _buildBottomBar(product, isLoggedIn) : null,
      ),
    );
  }

  Widget _buildSliverAppBar(ProductModel product) {
    final house = _houseColor(product);

    // Compact round action buttons over the photo.
    return Theme(
      data: Theme.of(context).copyWith(
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            iconSize: 19,
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(34, 34),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
      child: _sliverAppBar(product, house),
    );
  }

  Widget _sliverAppBar(ProductModel product, Color house) {
    return SliverAppBar(
      expandedHeight: 240,
      toolbarHeight: 50,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: ProductGallery(
          images: product.images,
          accent: house,
          heroTag: 'product-${product.id}',
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      actions: [
        _buildCompareToggle(product),
        _buildCompareBadge(),
        if (isOfficialProduct(product))
          Container(
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: 'Show QR',
              icon: const Icon(Icons.qr_code_2, color: Colors.white),
              onPressed: () => _showOfficialQr(product),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share this product',
            onPressed: () => _shareProduct(product),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: WishlistButton(product: product),
        ),
      ],
    );
  }

  /// Shareable QR for an official product (scannable in the Trenda customer app → /product/:id).
  void _showOfficialQr(ProductModel product) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Product QR', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: QrImageView(
                data: TrendaQr.build(TrendaQrKind.product, product.id),
                size: 220,
                gapless: true,
              ),
            ),
            const SizedBox(height: 10),
            Text(product.name,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Scan in the Trenda app to open this product.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildCompareToggle(ProductModel product) {
    final isSelected = ref.watch(comparisonProvider).contains(product.id);
    return Container(
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          isSelected ? Icons.compare_arrows : Icons.compare_arrows_outlined,
          color: Colors.white,
        ),
        tooltip: isSelected ? 'Remove from compare' : 'Add to compare',
        onPressed: () {
          final comparison = ref.read(comparisonProvider);
          if (!isSelected && comparison.isFull) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Compare list is full (max 4)')),
            );
            return;
          }
          ref.read(comparisonProvider.notifier).toggleProduct(product);
        },
      ),
    );
  }

  Widget _buildCompareBadge() {
    final count = ref.watch(comparisonCountProvider);
    if (count == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        tooltip: 'View comparison',
        onPressed: () => context.push('/compare'),
        icon: Badge(
          label: Text('$count'),
          child: const Icon(Icons.compare, color: Colors.white),
        ),
      ),
    );
  }

  Color _cardBorder(ThemeData theme) => theme.brightness == Brightness.dark
      ? Colors.white12
      : Colors.black.withValues(alpha: 0.06);

  Widget _buildProductHeaderBox(ProductModel product) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rated = product.totalReviews > 0 && product.averageRating > 0;
    final muted = scheme.onSurface.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _house.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    product.category.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _house,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // An unreviewed product says so instead of showing "0.0 (0)".
              if (rated) ...[
                const Icon(Icons.star_rounded,
                    color: Color(0xFFE9A227), size: 14),
                const SizedBox(width: 2),
                Text(
                  product.averageRating.toStringAsFixed(1),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '(${product.totalReviews})',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ] else
                Text(
                  'No reviews yet',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            product.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: scheme.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: '₱${_getCurrentPrice().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: _house,
                    ),
                    children: [
                      TextSpan(
                        text: pricingUnitSuffix(product.pricingUnit),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_deal != null) ...[
                const SizedBox(width: 6),
                Text(
                  '₱${_deal!.item.regularPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    decoration: TextDecoration.lineThrough,
                    color: scheme.onSurface.withValues(alpha: 0.38),
                  ),
                ),
                const SizedBox(width: 5),
                DiscountTag(percent: _deal!.item.discountPercent, scale: 0.8),
              ] else if (product.compareAtPrice != null) ...[
                const SizedBox(width: 6),
                Text(
                  '₱${product.compareAtPrice!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    decoration: TextDecoration.lineThrough,
                    color: scheme.onSurface.withValues(alpha: 0.38),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-${product.discountPercentage}%',
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              _stockPill(product),
            ],
          ),
          if (product.hasVariants) ...[
            const SizedBox(height: 8),
            _buildVariantSelector(product),
          ],
          Divider(height: 16, color: theme.dividerColor),
          _buildQuantitySelector(product),
        ],
      ),
    );
  }

  Widget _stockPill(ProductModel product) {
    late final IconData icon;
    late final String label;
    late final Color color;

    // An inquiry listing or untracked product has no count worth printing.
    if (!showsStockCount(product)) {
      icon = Icons.check_circle_outline_rounded;
      label = 'Available';
      color = stockLevelColor(context, StockLevel.plenty);
    } else {
      // The real count, worded as on the cards — the selected variant's when
      // one is picked, and never more than a live flash deal has left.
      final s = stockCountLabel(_stockCount(product),
          lowThreshold: product.lowStockThreshold);
      label = s.label;
      color = stockLevelColor(context, s.level);
      icon = switch (s.level) {
        StockLevel.out => Icons.remove_shopping_cart_outlined,
        StockLevel.low => Icons.inventory_2_outlined,
        StockLevel.plenty => Icons.check_circle_outline_rounded,
      };
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantSelector(ProductModel product) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: product.variants.map((variant) {
        final isSelected = _selectedVariant?.id == variant.id;
        final isOutOfStock = variant.stock <= 0;
        return GestureDetector(
          onTap: isOutOfStock
              ? null
              : () {
                  setState(() {
                    _selectedVariant = isSelected ? null : variant;
                    // A smaller shelf must not keep a quantity it can't fill.
                    final stock = _getAvailableStock();
                    if (stock > 0 && _quantity > stock) _quantity = stock;
                  });
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected
                  ? _house.withValues(alpha: 0.1)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? _house
                    : scheme.onSurface.withValues(alpha: 0.15),
                width: isSelected ? 1.4 : 1,
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              variant.name,
              style: TextStyle(
                fontSize: 11.5,
                color: isSelected
                    ? _brandGradient[1]
                    : scheme.onSurface
                        .withValues(alpha: isOutOfStock ? 0.3 : 0.85),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                decoration: isOutOfStock ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Typed quantity with the running total beside it, so the shopper sees
  /// what they will pay before tapping Add to Cart.
  Widget _buildQuantitySelector(ProductModel product) {
    final scheme = Theme.of(context).colorScheme;
    final maxStock = _getAvailableStock();
    return Row(
      children: [
        Text(
          'Qty',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 8),
        QuantityInput(
          value: _quantity,
          max: maxStock > 0 ? maxStock : null,
          enabled: !product.isOutOfStock,
          accent: _house,
          onDraft: (q) => setState(() => _quantity = q),
          onChanged: (q) => setState(() => _quantity = q),
          onLimit: (max) => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text('Only $max available'),
              duration: const Duration(seconds: 2),
            )),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Total',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              '₱${_lineTotal().toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Description as a short preview that opens in place — a long one used to
  /// push the whole page below the fold.
  Widget _buildDescription(ProductModel product) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = (product.description ?? '').trim();
    if (text.isEmpty) return const SizedBox.shrink();
    final long = text.length > 160 || '\n'.allMatches(text).length > 2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: Text(
              text,
              maxLines: _descriptionOpen || !long ? null : 3,
              overflow: _descriptionOpen || !long
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.75),
                height: 1.4,
                fontSize: 12,
              ),
            ),
          ),
          if (long)
            GestureDetector(
              onTap: () => setState(() => _descriptionOpen = !_descriptionOpen),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _descriptionOpen ? 'Show less' : 'Read more',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _house,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required Widget content,
    bool isExpanded = false,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder(theme)),
      ),
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        dense: true,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        expandedAlignment: Alignment.topLeft,
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [content],
      ),
    );
  }

  // 🏛️ Official Trenda Store parity banner (shown when the product is official).
  Widget _buildOfficialBanner() {
    const gold = kOfficialGold;
    const goldDark = kOfficialGoldDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(colors: [goldDark, gold]),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Official Trenda Store',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                SizedBox(height: 2),
                Text('Genuine product — sold & shipped directly by Trenda',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🏛️ Related official products (same category, excluding the current item).
  Widget _buildRelatedOfficial(ProductModel product) {
    final async = ref.watch(officialStoreProductsProvider);
    final related = async.maybeWhen(
      data: (list) => list
          .where((p) => p.id != product.id && p.category == product.category)
          .take(10)
          .toList(),
      orElse: () => const <ProductModel>[],
    );
    if (related.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('More from the Official Store',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: kOfficialGoldDark)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: related.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(
              width: 170,
              child: OfficialProductCard(product: related[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVendorInfo(ProductModel product) {
    final chip = SellerChip(
      seed: product.vendorId.isNotEmpty ? product.vendorId : product.id,
      storeName: product.storeName ?? 'Store',
      isOfficial: isOfficialProduct(product),
      isResale: product.resellerInfo?.isResale == true,
      originalVendorStoreName: product.resellerInfo?.originalVendorStoreName,
      onVisit: () => context.push('/store/${product.vendorId}'),
      // SellerChip already hides its chat button when onChat is null.
      onChat: _canChat(product) ? () => _startChat(product) : null,
    );

    // The shop's location sits UNDER the seller chip rather than inside it:
    // SellerChip is shared by other surfaces that have no pin, and it stays generic.
    if (product.storePin == null) return chip;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chip,
        const SizedBox(height: 10),
        MapPinButton(location: product.storePin),
      ],
    );
  }

  /// Whether this product offers a Chat button. The server decides for a vendor
  /// (tier gate); Official Trenda never does — no one reads its inbox yet, and its
  /// detail can arrive from an endpoint that sends no `chatEnabled` (the model
  /// then defaults to true).
  bool _canChat(ProductModel product) =>
      product.chatEnabled &&
      product.vendorId.isNotEmpty &&
      !isOfficialProduct(product);

  /// Message the shop selling this item. The two chat buttons on this page used
  /// to be `onPressed: () {}` — they looked live and did nothing.
  Future<void> _startChat(ProductModel product) async {
    if (product.vendorId.isEmpty) return;
    try {
      final conv = await ref.read(chatControllerProvider).startConversation(
            vendorId: product.vendorId,
            // The chat opens with this item pinned above the thread.
            productId: product.id.isEmpty ? null : product.id,
          );
      if (mounted) context.push('/chat/${conv.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyChatError(e))),
        );
      }
    }
  }

  /// Share button was also a no-op ("// Implement share").
  void _shareProduct(ProductModel product) {
    final url = 'https://trenda.ph/product/${product.id}';
    Share.share(
      '${product.name} — ₱${_getCurrentPrice().toStringAsFixed(2)} on Trenda\n$url',
      subject: product.name,
    );
  }

  Widget _buildShippingInfo(ProductModel product) {
    final scheme = Theme.of(context).colorScheme;
    final house = _houseColor(product);
    final municipality = ref.watch(municipalityProvider);
    final promises = deliveryPromises(
      freeShipping: product.freeShipping,
      municipality: municipality,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final promise in promises)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  promise.assured
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 17,
                  color: promise.assured
                      ? house
                      : scheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    promise.text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: scheme.onSurface.withValues(
                        alpha: promise.assured ? 0.8 : 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildReviewsSection(ProductModel product) {
    final theme = Theme.of(context);
    final compactText = TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      minimumSize: const Size(0, 28),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      foregroundColor: _brandGradient[1],
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Reviews',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
              const SizedBox(width: 2),
              Text(
                '${product.averageRating.toStringAsFixed(1)} (${product.totalReviews})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _brandGradient[1],
                ),
              ),
              const Spacer(),
              TextButton(
                style: compactText,
                onPressed: () => _onWriteReview(product),
                child: const Text('Write'),
              ),
              TextButton(
                style: compactText,
                onPressed: () {
                  // Navigate to all reviews page (product name for the header).
                  context.push('/product/${product.id}/reviews',
                      extra: product.name);
                },
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Actual reviews from API — a two-review preview; "See all" has the rest.
          Consumer(
            builder: (context, ref, child) {
              final scheme = Theme.of(context).colorScheme;
              final muted = scheme.onSurface.withValues(alpha: 0.5);
              final reviewsAsync =
                  ref.watch(productReviewsProvider(product.id));
              return reviewsAsync.when(
                data: (reviewsResult) {
                  if (reviewsResult.reviews.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(0, 2, 0, 4),
                      child: Text('No reviews yet. Be the first!',
                          style: TextStyle(color: muted, fontSize: 11.5)),
                    );
                  }
                  final previewReviews = reviewsResult.reviews.take(2).toList();
                  return Column(
                    children: [
                      for (final review in previewReviews)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor:
                                    _brandGradient[0].withValues(alpha: 0.2),
                                child: Text(
                                  // userName is never null but can be
                                  // '' — substring(0, 1) threw on it.
                                  review.userName.trim().isEmpty
                                      ? 'A'
                                      : review.userName.trim()[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _brandGradient[1],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            review.userName.trim().isEmpty
                                                ? 'Anonymous'
                                                : review.userName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11.5,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        ...List.generate(
                                          5,
                                          (i) => Icon(
                                            i < review.rating
                                                ? Icons.star_rounded
                                                : Icons.star_border_rounded,
                                            size: 11,
                                            color: Colors.amber,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDate(review.createdAt),
                                          style: TextStyle(
                                              fontSize: 10, color: muted),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      review.comment,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.75),
                                        height: 1.35,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('Failed to load reviews',
                      style: TextStyle(color: muted, fontSize: 11.5)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _onWriteReview(ProductModel product) {
    final isLoggedIn = ref.read(authNotifierProvider).user != null;
    if (!isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to write a review')),
      );
      return;
    }
    _showWriteReviewDialog(product);
  }

  void _showWriteReviewDialog(ProductModel product) {
    double rating = 5.0;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Write a Review',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Rate ${product.name}:',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                    onPressed: () => setModalState(() => rating = index + 1.0),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 4,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Share your experience (max 200 chars)...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '${commentController.text.length}/200',
                ),
                onChanged: (val) => setModalState(() {}),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => TapGuard.run('product_details.submit@1269', () async {
                    if (commentController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please write a comment')),
                      );
                      return;
                    }

                    // Show loading
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Submitting review...')),
                    );

                    // Submit review via API
                    final reviewActions = ref.read(reviewsActionsProvider);
                    final result = await reviewActions.submitReview(
                      productId: product.id,
                      rating: rating.toInt(),
                      comment: commentController.text.trim(),
                    );

                    if (result != null) {
                      // Refresh product data to show updated rating
                      ref.invalidate(productDetailsProvider(product.id));
                      ref.invalidate(productReviewsProvider(product.id));

                      if (mounted) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Review submitted! Thank you for your feedback.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Failed to submit review. Please try again.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandGradient[0],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Submit Review',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ProductModel product, bool isLoggedIn) {
    final isBrowsingOther = ref.watch(isBrowsingOtherMunicipalityProvider);
    final browsingMuni = ref.watch(municipalityProvider) ?? '';

    // ✅ CROSS-MUNICIPALITY BLOCK: Show browse-only state
    if (isBrowsingOther) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Info banner
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This product is from $browsingMuni. '
                        'Ordering is only available in your home area.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_canChat(product)) ...[
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, size: 20),
                        constraints:
                            const BoxConstraints(minHeight: 40, minWidth: 40),
                        padding: EdgeInsets.zero,
                        tooltip: 'Message the shop',
                        onPressed: () => TapGuard.run('product_details.startChat', () => _startChat(product)),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.explore, size: 18),
                        label: const Text(
                          'Browse Only',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_canChat(product)) ...[
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  constraints:
                      const BoxConstraints(minHeight: 40, minWidth: 40),
                  padding: EdgeInsets.zero,
                  tooltip: 'Message the shop',
                  onPressed: () => TapGuard.run('product_details.startChat', () => _startChat(product)),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _brandGradient),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: _brandGradient[0].withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _canAddToCart() && !_isAddingToCart
                      ? () => TapGuard.run('product_details.addToCart', () => _addToCart(product, isLoggedIn))
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isAddingToCart
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          product.hasVariants && _selectedVariant == null
                              ? 'Select an Option'
                              : 'Add to Cart · ₱${_lineTotal().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                product.hasVariants && _selectedVariant == null
                                    ? Colors.white70
                                    : Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Logic Helpers ---

  double _getCurrentPrice() {
    if (_selectedVariant != null) {
      return _selectedVariant!.price;
    }
    if (_deal != null) return _deal!.item.flashPrice;
    return ref
            .read(productDetailsProvider(widget.productId))
            .value
            ?.basePrice ??
        0;
  }

  /// Unit price × the quantity in the box — what Add to Cart will put in the
  /// basket (delivery is priced at checkout).
  double _lineTotal() => _getCurrentPrice() * _quantity;

  /// Units on hand, for the stock pill. Unlike [_getAvailableStock] it ignores
  /// a flash deal's per-customer limit — that caps one basket, not the shelf.
  int _stockCount(ProductModel product) {
    if (_selectedVariant != null) return _selectedVariant!.stock;
    final deal = _deal;
    final stock = product.stock;
    return deal != null && deal.item.stockLeft < stock
        ? deal.item.stockLeft
        : stock;
  }

  int _getAvailableStock() {
    if (_selectedVariant != null) {
      return _selectedVariant!.stock;
    }
    final stock = ref
            .read(productDetailsProvider(widget.productId))
            .value
            ?.totalStock ??
        0;
    // A flash deal caps what can be bought at the flash price.
    final deal = _deal;
    if (deal != null && deal.item.perCustomerLimit > 0) {
      return [stock, deal.item.stockLeft, deal.item.perCustomerLimit].reduce((a, b) => a < b ? a : b);
    }
    return deal != null && deal.item.stockLeft < stock ? deal.item.stockLeft : stock;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      return DateFormat('d/M/y').formatPh(date);
    }
  }

  bool _canAddToCart() {
    final product = ref.read(productDetailsProvider(widget.productId)).value;
    if (product == null) return false;
    if (product.isOutOfStock) return false;
    if (product.hasVariants && _selectedVariant == null) return false;
    return _quantity <= _getAvailableStock();
  }

  Future<void> _addToCart(ProductModel product, bool isLoggedIn) async {
    // ✅ SAFETY NET: Block cross-municipality ordering
    final isBrowsingOther = ref.read(isBrowsingOtherMunicipalityProvider);
    if (isBrowsingOther) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ordering is only available in your home municipality.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // ✅ CLOSED-STORE GUARD: warn (advance order) or block before adding; server re-enforces at checkout.
    final closedAction = closedStoreAction(
      isOpen: product.storeStatus?.isOpen,
      canOrder: product.storeStatus?.canOrder,
    );
    if (closedAction == ClosedStoreAction.blocked) {
      if (!mounted) return;
      await showStoreClosedBlockedDialog(
        context,
        storeName: product.storeName,
        nextOpenTime: product.storeStatus?.nextOpenTime,
        nextOpenDay: product.storeStatus?.nextOpenDay,
        nextOpenAt: product.storeStatus?.nextOpenAt,
      );
      return;
    } else if (closedAction == ClosedStoreAction.advanceOrder) {
      if (!mounted) return;
      final proceed = await showClosedStoreDialog(
        context,
        storeName: product.storeName,
        reopening: reopeningLine(
          day: product.storeStatus?.nextOpenDay,
          time: product.storeStatus?.nextOpenAt,
          legacy: product.storeStatus?.nextOpenTime,
        ),
      );
      if (!proceed) return;
    }

    if (!isLoggedIn) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('Login Required'),
                content: const Text('Please login to add items to your cart.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push(Routes.login);
                      },
                      child: const Text('Login')),
                ],
              ));
      return;
    }

    setState(() => _isAddingToCart = true);

    try {
      final cart = ref.read(cartProvider.notifier);
      final added = await cart.addToCart(
        product,
        quantity: _quantity,
        variantId: _selectedVariant
            ?.id, // ✅ Pass variant ID for products with variants
      );

      if (!added) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(cart.lastError ?? "Couldn't add this to your cart"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }
}
