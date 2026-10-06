// lib/features/home/utils/food_catalogue.dart
// Pure rules for the Food tab's "All restaurant food" grid. It filters the same
// whole-city product list the All items / On sale grids use, so there is one
// catalogue and one in-stock rule, not a second query that could disagree.
import 'package:trenda_shared/models/product_model.dart';
import '../../products/utils/catalogue_browse.dart' show browsableProducts;

/// The category vendors pick in Add Product. Matches trenda_shared
/// `AppConfig.productCategories` and the backend `Product.category` enum.
const String kRestaurantFoodCategory = 'Restaurant Food';

bool isRestaurantFood(ProductModel p) =>
    p.category.trim().toLowerCase() == kRestaurantFoodCategory.toLowerCase();

/// Every in-stock Restaurant Food product, name order (ties by id so the grid
/// never reshuffles on an unrelated rebuild).
List<ProductModel> restaurantFood(List<ProductModel> products) {
  final list = browsableProducts(products).where(isRestaurantFood).toList()
    ..sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });
  return list;
}

String? _sub(ProductModel p) {
  final s = p.subcategory?.trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Filter chips, built from what vendors actually listed (e.g. "Meals",
/// "Drinks"): most items first, then alphabetical. Case-insensitive, so
/// "drinks" and "Drinks" are one chip, shown as first seen.
List<String> foodSubcategories(List<ProductModel> food) {
  final counts = <String, int>{};
  final display = <String, String>{};
  for (final p in food) {
    final s = _sub(p);
    if (s == null) continue;
    final key = s.toLowerCase();
    counts[key] = (counts[key] ?? 0) + 1;
    display.putIfAbsent(key, () => s);
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return [for (final k in keys) display[k]!];
}

/// [subcategory] null = every item.
List<ProductModel> filterFoodBySubcategory(
    List<ProductModel> food, String? subcategory) {
  if (subcategory == null) return food;
  final want = subcategory.toLowerCase();
  return food.where((p) => _sub(p)?.toLowerCase() == want).toList();
}
