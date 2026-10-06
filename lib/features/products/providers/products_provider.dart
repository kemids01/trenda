import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/data/products_repository.dart';
import 'package:trenda_shared/models/product_model.dart';
import 'package:trenda_shared/core/config.dart';
import '../../core/providers/municipality_provider.dart';

/// ---------------------------------------------------------------------------
/// 🛒 PRODUCT DETAILS (fetch a single product by ID)
/// ---------------------------------------------------------------------------
final productDetailsProvider =
    FutureProvider.family<ProductModel?, String>((ref, productId) async {
  final repo = ref.watch(productsRepositoryProvider);
  final result = await repo.getPublicProductById(productId);
  return result;
});

/// ---------------------------------------------------------------------------
/// 🏪 Repository Provider
/// ---------------------------------------------------------------------------
final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(baseUrl: AppConfig.backendBaseUrl);
});

/// ---------------------------------------------------------------------------
/// 🌍 PUBLIC PRODUCTS — visible to everyone (even guests)
/// ---------------------------------------------------------------------------
/// 🌍 Public products for non-logged-in users (with municipality filter)
///
/// ⚠️ This is a SINGLE PAGE, not a stream: the Shop tab's rails and the
/// "All items" / "On sale" grids all shuffle, facet and sort it client-side,
/// and every one of those needs the whole set — a shuffled first page is not a
/// shuffle. So the cap is what "all items" actually means. [kPublicProductsLimit]
/// is sized well above any city's live catalogue (prod: 17); past it the grids
/// silently show a subset, and the fix is real pagination plus server-side
/// ordering, not a bigger number.
const int kPublicProductsLimit = 500;

final publicProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final repo = ref.watch(productsRepositoryProvider);
  final municipality = ref.watch(municipalityProvider);

  final result = await repo.fetchPublicProducts(
    limit: kPublicProductsLimit,
    municipality: municipality, // Filter by municipality
  );
  return result.products;
});

/// Public products in the given categories (comma-separated, any of them),
/// fetched SERVER-side. Pages that show one slice of the catalogue (Palengke,
/// the Food tab) must use this, not filter [publicProductsProvider]: that page
/// is capped at [kPublicProductsLimit], and once the city's catalogue passed it
/// (prod 2026-10-01: 886 products) the newest 500 held no fresh produce, meat
/// or restaurant food at all — both pages went empty.
final categoryProductsProvider =
    FutureProvider.family<List<ProductModel>, String>((ref, categories) async {
  final repo = ref.watch(productsRepositoryProvider);
  final municipality = ref.watch(municipalityProvider);
  final result = await repo.fetchPublicProducts(
    limit: kPublicProductsLimit,
    municipality: municipality,
    category: categories,
  );
  return result.products;
});

/// ---------------------------------------------------------------------------
/// 🧾 ALL ACTIVE PRODUCTS (for logged-in customers)
/// ---------------------------------------------------------------------------
final productsListProvider = FutureProvider<List<ProductModel>>((ref) async {
  final repo = ref.watch(productsRepositoryProvider);
  final municipality = ref.watch(municipalityProvider);

  final result = await repo.fetchProducts(
    status: 'active',
    limit: 20,
    municipality: municipality, // Filter by municipality
  );
  return result.products;
});

/// ---------------------------------------------------------------------------
/// 🏷️ FEATURED PRODUCTS (for homepage banners or sections)
/// ---------------------------------------------------------------------------
final featuredProductsProvider =
    FutureProvider<List<ProductModel>>((ref) async {
  final repo = ref.watch(productsRepositoryProvider);
  final municipality = ref.watch(municipalityProvider);

  final result = await repo.fetchPublicProducts(
    featured: true,
    limit: 10,
    municipality: municipality, // Filter by municipality
  );
  return result.products;
});

// /// ---------------------------------------------------------------------------
// /// 🧩 ADMIN PRODUCTS (for admin dashboard & vendor management)
// /// ---------------------------------------------------------------------------
// final adminProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
//   final repo = ref.watch(productsRepositoryProvider);
//   final result = await repo.fetchProducts(
//     admin: true, // ✅ backend will use /admin/products
//     limit: 50,
//     sort: 'recent',
//   );
//   return result.products;
// });

/// ---------------------------------------------------------------------------
/// 🔗 SIMILAR PRODUCTS (based on category)
/// ---------------------------------------------------------------------------
final similarProductsProvider =
    FutureProvider.family<List<ProductModel>, ProductModel>(
        (ref, product) async {
  final repo = ref.watch(productsRepositoryProvider);
  final municipality = ref.watch(municipalityProvider);

  final result = await repo.fetchPublicProducts(
    category: product.category,
    limit: 10,
    municipality: municipality,
  );

  // Filter out the current product
  return result.products.where((p) => p.id != product.id).take(6).toList();
});
