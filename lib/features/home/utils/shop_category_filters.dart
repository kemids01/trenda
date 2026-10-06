// lib/features/home/utils/shop_category_filters.dart
// The chips on a Shop category page: All · On sale · one per subcategory the
// page's products actually carry (most stocked first). Pure.
import 'package:trenda_shared/models/product_model.dart';

const String kCategoryChipAll = 'All';
const String kCategoryChipOnSale = 'On sale';

bool _onSale(ProductModel p) => p.discountPercentage > 0;

/// Chip labels for [products]: All, On sale (only when something is), then
/// the subcategories by how many products carry them, ties alphabetical.
List<String> categoryChips(List<ProductModel> products) {
  final counts = <String, int>{};
  for (final p in products) {
    final s = (p.subcategory ?? '').trim();
    if (s.isEmpty) continue;
    counts[s] = (counts[s] ?? 0) + 1;
  }
  final subs = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.toLowerCase().compareTo(b.toLowerCase());
    });
  return [
    kCategoryChipAll,
    if (products.any(_onSale)) kCategoryChipOnSale,
    ...subs,
  ];
}

/// The products a chip shows.
List<ProductModel> filterByCategoryChip(List<ProductModel> products, String chip) {
  if (chip == kCategoryChipAll) return products;
  if (chip == kCategoryChipOnSale) return products.where(_onSale).toList();
  return products.where((p) => (p.subcategory ?? '').trim() == chip).toList();
}
