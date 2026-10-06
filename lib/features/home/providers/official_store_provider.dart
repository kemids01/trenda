import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/models/product_model.dart';
import '../../products/providers/products_provider.dart';
import '../../core/providers/municipality_provider.dart';

/// ---------------------------------------------------------------------------
/// 🏛️ OFFICIAL TRENDA STORE PRODUCTS (municipality-scoped, public)
/// ---------------------------------------------------------------------------
/// Mirrors [publicProductsProvider] but hits the LIVE Official Trenda Store
/// endpoint (`/api/official-store/products`) via the shared repository. Every
/// product returned here is an official Trenda product.
final officialStoreProductsProvider =
    FutureProvider<List<ProductModel>>((ref) async {
  final repo = ref.watch(productsRepositoryProvider);
  final municipality = ref.watch(municipalityProvider);

  final result = await repo.fetchOfficialStoreProducts(
    municipality: municipality,
    limit: 50,
  );
  return result.products;
});

/// ---------------------------------------------------------------------------
/// 🔎 TRENDA HUB SEARCH QUERY
/// ---------------------------------------------------------------------------
/// The Trenda tab's live catalogue query. It lives in a provider rather than in
/// the tab's own state because the search field was moved out of the page and
/// into the shop dock above the bottom navigation bar.
final officialHubSearchProvider = StateProvider<String>((ref) => '');
