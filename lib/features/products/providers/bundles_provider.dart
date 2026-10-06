import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/models/bundle_model.dart';
import 'products_provider.dart'; // To access productsRepositoryProvider

/// ---------------------------------------------------------------------------
/// 📦 BUNDLE DETAILS (fetch a single bundle by ID)
/// ---------------------------------------------------------------------------
final bundleDetailsProvider =
    FutureProvider.family<ProductBundle?, String>((ref, bundleId) async {
  final repo = ref.watch(productsRepositoryProvider);
  final result = await repo.getPublicBundleById(bundleId);
  return result;
});

/// ---------------------------------------------------------------------------
/// 🌍 PUBLIC BUNDLES — visible to everyone
/// ---------------------------------------------------------------------------
final publicBundlesProvider = FutureProvider<List<ProductBundle>>((ref) async {
  final repo = ref.watch(productsRepositoryProvider);
  // Optional: access filter providers like municipality if needed

  final result = await repo.fetchPublicBundles(
    limit: 20,
    // municipality: municipality, // Backend support needed if we want loc filtering
  );
  return result.bundles;
});
