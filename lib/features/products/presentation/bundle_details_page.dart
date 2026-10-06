import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trenda_shared/models/bundle_model.dart';
import 'package:go_router/go_router.dart';
import '../providers/bundles_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../auth/data/providers.dart';
import '../../../../design_system/app_colors.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class BundleDetailsPage extends ConsumerStatefulWidget {
  final String bundleId;

  const BundleDetailsPage({super.key, required this.bundleId});

  @override
  ConsumerState<BundleDetailsPage> createState() => _BundleDetailsPageState();
}

class _BundleDetailsPageState extends ConsumerState<BundleDetailsPage> {
  int _quantity = 1;

  final List<Color> _brandGradient = [
    AppColors.secondary,
    AppColors.secondaryDark,
  ];

  @override
  Widget build(BuildContext context) {
    final bundleAsync = ref.watch(bundleDetailsProvider(widget.bundleId));
    final authState = ref.watch(authNotifierProvider);
    final isLoggedIn = authState.user != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: bundleAsync.when(
        data: (bundle) {
          if (bundle == null) {
            return const Center(child: Text('Bundle not found'));
          }

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(bundle),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  child: Column(
                    children: [
                      _buildBundleHeaderBox(bundle),
                      const SizedBox(height: 16),
                      _buildItemsList(bundle),
                      const SizedBox(height: 16),
                      _buildQuantitySelector(bundle),
                      const SizedBox(height: 16),
                      if (bundle.description != null) ...[
                        _buildSection(
                          title: 'Description',
                          content: Text(
                            bundle.description!,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                height: 1.5,
                                fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
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
      bottomNavigationBar: bundleAsync.whenOrNull(
        data: (bundle) =>
            bundle != null ? _buildBottomBar(bundle, isLoggedIn) : null,
      ),
    );
  }

  Widget _buildSliverAppBar(ProductBundle bundle) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: _brandGradient[1],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: bundle.imageUrl ??
                  'https://via.placeholder.com/600x400?text=Bundle',
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppColors.surfaceVariant,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => const Icon(
                  Icons.broken_image,
                  size: 50,
                  color: AppColors.textTertiary),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
    );
  }

  Widget _buildBundleHeaderBox(ProductBundle bundle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _brandGradient[0].withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'BUNDLE DEAL',
              style: TextStyle(
                color: _brandGradient[1],
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            bundle.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${bundle.bundlePrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _brandGradient[1],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '₱${bundle.originalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    decoration: TextDecoration.lineThrough,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'SAVE ₱${bundle.savings.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (bundle.stock <= 0)
            const Row(
              children: [
                Icon(Icons.remove_circle_outline,
                    color: AppColors.outOfStock, size: 16),
                SizedBox(width: 4),
                Text(
                  'Out of Stock',
                  style: TextStyle(
                      color: AppColors.outOfStock, fontWeight: FontWeight.bold),
                ),
              ],
            )
          else if (bundle.stock < 5)
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.lowStock, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Only ${bundle.stock} left!',
                  style: const TextStyle(
                      color: AppColors.lowStock, fontWeight: FontWeight.w600),
                ),
              ],
            )
          else
            const Row(
              children: [
                Icon(Icons.check_circle_outline,
                    color: AppColors.inStock, size: 16),
                SizedBox(width: 4),
                Text(
                  'In Stock',
                  style: TextStyle(
                      color: AppColors.inStock, fontWeight: FontWeight.w600),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildItemsList(ProductBundle bundle) {
    return _buildSection(
      title: 'Included Items',
      content: Column(
        children: bundle.items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: item.productImage ?? '',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.surfaceVariant,
                      child: const Icon(Icons.image,
                          size: 24, color: AppColors.textTertiary),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName ?? 'Unknown Product',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Qty: ${item.quantity}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(ProductBundle bundle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Quantity',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          AllowRapidTaps(
              child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 20),
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                  onPressed:
                      _quantity > 1 ? () => setState(() => _quantity--) : null,
                  color: AppColors.textSecondary,
                ),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    '$_quantity',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                  onPressed: _quantity < bundle.stock
                      ? () => setState(() => _quantity++)
                      : null,
                  color: _brandGradient[1],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ProductBundle bundle, bool isLoggedIn) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: (bundle.stock > 0 && isLoggedIn)
              ? () => TapGuard.run('bundle_details.add@421', () async {
                  // Add to cart
                  final cart = ref.read(cartProvider.notifier);
                  final added = await cart.addBundleToCart(
                    bundle.id,
                    quantity: _quantity,
                  );
                  if (!added) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(cart.lastError ??
                              "Couldn't add this to your cart"),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return;
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Added to cart'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    context.pop();
                  }
                })
              : (!isLoggedIn ? () => context.push('/auth/login') : null),
          style: ElevatedButton.styleFrom(
            backgroundColor: _brandGradient[1],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Text(
            isLoggedIn
                ? (bundle.stock > 0
                    ? 'Add to Cart - ₱${(bundle.bundlePrice * _quantity).toStringAsFixed(2)}'
                    : 'Out of Stock')
                : 'Login to Buy',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
