// lib/features/home/providers/shop_category_provider.dart
// Data for a Shop tab category page (/shop-category/<group>): the stores in
// that store-category group, and their products.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/models/product_model.dart';
import 'package:trenda_shared/models/store_category.dart' show storeMatchesCategory;

import '../../core/providers/municipality_provider.dart';
import '../../products/providers/products_provider.dart';
import '../../products/utils/catalogue_browse.dart'
    show kPalengkeCategoryParam, palengkeProducts;
import '../../stores/utils/store_carousel.dart' show carouselDeck;
import 'stores_provider.dart';

/// Most products a category page loads. A category has a handful of stores, so
/// this is far above what one holds; past it the page simply shows the first
/// [kShopCategoryProductLimit].
const int kShopCategoryProductLimit = 200;

/// The city's stores in [group] — primary group or any secondary subcategory in
/// it (the shared storeMatchesCategory rule) — featured first, then open, then
/// closed, each once.
List<StoreData> storesInCategory(Map<String, List<StoreData>> stores, String group) =>
    carouselDeck(
      featured: stores['featured'] ?? const [],
      open: stores['open'] ?? const [],
      closed: stores['closed'] ?? const [],
    ).where((s) => storeMatchesCategory(s.storeCategory, group: group)).toList();

final shopCategoryStoresProvider =
    Provider.autoDispose.family<AsyncValue<List<StoreData>>, String>(
  (ref, group) =>
      ref.watch(publicStoresProvider).whenData((m) => storesInCategory(m, group)),
);

/// The products of those stores, filtered on the server (`?storeCategory=`), so
/// a category page never depends on the Shop tab's capped all-products page.
final shopCategoryProductsProvider =
    FutureProvider.autoDispose.family<List<ProductModel>, String>((ref, group) async {
  final repo = ref.watch(productsRepositoryProvider);
  final municipality = ref.watch(municipalityProvider);
  final result = await repo.fetchPublicProducts(
    limit: kShopCategoryProductLimit,
    municipality: municipality,
    storeCategory: group,
  );
  return result.products;
});

/// The city's stores that sell at least one of [products] (matched by vendor
/// uid), in the same featured → open → closed order, each once. Palengke uses
/// it: its stores are whoever lists fresh produce or meat & seafood, not one
/// store-category group.
List<StoreData> storesSelling(
    Map<String, List<StoreData>> stores, List<ProductModel> products) {
  final vendors = {for (final p in products) p.vendorId};
  return carouselDeck(
    featured: stores['featured'] ?? const [],
    open: stores['open'] ?? const [],
    closed: stores['closed'] ?? const [],
  ).where((s) => vendors.contains(s.id)).toList();
}

/// The Palengke page's stores: those selling its fresh-market products.
final palengkeStoresProvider =
    Provider.autoDispose<AsyncValue<List<StoreData>>>((ref) {
  final stores = ref.watch(publicStoresProvider);
  final products = ref.watch(categoryProductsProvider(kPalengkeCategoryParam));
  if (stores.hasError) return AsyncValue.error(stores.error!, stores.stackTrace!);
  if (products.hasError) return AsyncValue.error(products.error!, products.stackTrace!);
  final s = stores.valueOrNull; final p = products.valueOrNull;
  if (s == null || p == null) return const AsyncValue.loading();
  return AsyncValue.data(storesSelling(s, palengkeProducts(p)));
});
