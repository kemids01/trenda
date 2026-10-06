// lib/features/products/presentation/comparison_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_shared/trenda_shared.dart';
import '../../../design_system/design_system.dart';
import '../providers/comparison_provider.dart';
import '../utils/price_display.dart';

class ComparisonPage extends ConsumerWidget {
  const ComparisonPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparison = ref.watch(comparisonProvider);
    final notifier = ref.read(comparisonProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Compare (${comparison.count})'),
        actions: [
          if (comparison.count > 0)
            TextButton(
              onPressed: () => notifier.clearAll(),
              child: const Text('Clear All'),
            ),
        ],
      ),
      body: comparison.isEmpty
          ? _buildEmptyState(context)
          : _buildComparisonTable(context, comparison.products, notifier),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.compare_arrows,
            size: 80,
            color: AppColors.textTertiary,
          ),
          AppSpacing.verticalMD,
          Text(
            'No products to compare',
            style: AppTypography.titleLarge,
          ),
          AppSpacing.verticalXS,
          Text(
            'Add products from the product page',
            style: AppTypography.asSecondary(AppTypography.bodyMedium),
          ),
          AppSpacing.verticalLG,
          ElevatedButton.icon(
            onPressed: () => context.go('/main'),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('Browse Products'),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(
    BuildContext context,
    List<ProductModel> products,
    ComparisonNotifier notifier,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Product images and names row
          _buildProductHeaderRow(products, notifier),
          const Divider(),

          // Comparison rows
          _buildPriceRow(products),
          _buildComparisonRow('Rating', products,
              (p) => '${p.averageRating.toStringAsFixed(1)} ⭐'),
          _buildComparisonRow(
              'Stock',
              products,
              (p) => p.totalStock > 0
                  ? '${p.totalStock} available'
                  : 'Out of stock'),
          _buildComparisonRow('Category', products, (p) => p.category),
          _buildComparisonRow('Brand', products, (p) => p.brand ?? 'N/A'),

          AppSpacing.verticalLG,

          // Add to cart buttons
          _buildActionRow(context, products),
        ],
      ),
    );
  }

  Widget _buildProductHeaderRow(
      List<ProductModel> products, ComparisonNotifier notifier) {
    return Container(
      padding: AppSpacing.paddingMD,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label column
          SizedBox(
            width: 80,
            child: Text('Product', style: AppTypography.titleSmall),
          ),
          // Product columns
          ...products.map((product) => Expanded(
                child: _buildProductHeader(product, notifier),
              )),
          // Empty columns if less than max
          ...List.generate(
            maxCompareProducts - products.length,
            (_) => const Expanded(child: SizedBox()),
          ),
        ],
      ),
    );
  }

  Widget _buildProductHeader(
      ProductModel product, ComparisonNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: AppSpacing.borderRadiusMD,
                child: Image.network(
                  product.images.isNotEmpty ? product.images.first : '',
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 100,
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  onPressed: () => notifier.removeProduct(product.id),
                  icon: const Icon(Icons.close, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(24, 24),
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.verticalXS,
          Text(
            product.name,
            style: AppTypography.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    String label,
    List<ProductModel> products,
    String Function(ProductModel) getValue,
  ) {
    return Container(
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTypography.asSecondary(AppTypography.bodySmall),
            ),
          ),
          ...products.map((product) => Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Text(
                    getValue(product),
                    style: AppTypography.bodyMedium,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )),
          ...List.generate(
            maxCompareProducts - products.length,
            (_) => const Expanded(child: SizedBox()),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(List<ProductModel> products) {
    return Container(
      padding: AppSpacing.paddingMD,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              'Price',
              style: AppTypography.asSecondary(AppTypography.bodySmall),
            ),
          ),
          ...products.map((product) => Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Column(
                    children: [
                      PriceComparisonWidget(
                        originalPrice:
                            product.compareAtPrice ?? product.basePrice,
                        currentPrice: product.basePrice,
                      ),
                      if (pricingUnitSuffix(product.pricingUnit).isNotEmpty)
                        Text(
                          pricingUnitSuffix(product.pricingUnit),
                          style: AppTypography.asSecondary(
                              AppTypography.bodySmall),
                        ),
                    ],
                  ),
                ),
              )),
          ...List.generate(
            maxCompareProducts - products.length,
            (_) => const Expanded(child: SizedBox()),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, List<ProductModel> products) {
    return Padding(
      padding: AppSpacing.paddingMD,
      child: Row(
        children: [
          const SizedBox(width: 80),
          ...products.map((product) => Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: ElevatedButton(
                    onPressed: () => context.push('/product/${product.id}'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('View'),
                  ),
                ),
              )),
          ...List.generate(
            maxCompareProducts - products.length,
            (_) => const Expanded(child: SizedBox()),
          ),
        ],
      ),
    );
  }
}

/// Comparison FAB widget
class ComparisonFAB extends ConsumerWidget {
  const ComparisonFAB({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(comparisonCountProvider);

    if (count == 0) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      onPressed: () => context.push('/compare'),
      icon: const Icon(Icons.compare_arrows),
      label: Text('Compare ($count)'),
    );
  }
}

/// Compare button for product cards
class CompareButton extends ConsumerWidget {
  final ProductModel product;
  final bool showLabel;

  const CompareButton({
    super.key,
    required this.product,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparison = ref.watch(comparisonProvider);
    final notifier = ref.read(comparisonProvider.notifier);
    final isSelected = comparison.contains(product.id);
    final isFull = comparison.isFull;

    if (showLabel) {
      return OutlinedButton.icon(
        onPressed: isFull && !isSelected
            ? null
            : () => notifier.toggleProduct(product),
        icon: Icon(
          isSelected ? Icons.check : Icons.compare_arrows,
          size: 18,
        ),
        label: Text(isSelected ? 'Added' : 'Compare'),
        style: OutlinedButton.styleFrom(
          foregroundColor: isSelected ? AppColors.success : null,
          side: BorderSide(
            color: isSelected ? AppColors.success : AppColors.border,
          ),
        ),
      );
    }

    return IconButton(
      onPressed:
          isFull && !isSelected ? null : () => notifier.toggleProduct(product),
      icon: Icon(
        isSelected ? Icons.compare : Icons.compare_arrows_outlined,
        color: isSelected ? AppColors.success : null,
      ),
      tooltip: isSelected ? 'Remove from compare' : 'Add to compare',
    );
  }
}
