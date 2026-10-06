// lib/features/vendors/providers/vendor_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/models/product_model.dart';
import '../../products/providers/products_provider.dart';

/// Vendor details model
class VendorDetails {
  final String id;
  final String? storeName;
  final String? logo;
  final String? description;
  final double rating;
  final int productCount;
  final int followerCount;

  const VendorDetails({
    required this.id,
    this.storeName,
    this.logo,
    this.description,
    this.rating = 0.0,
    this.productCount = 0,
    this.followerCount = 0,
  });
}

/// Fetch vendor details from products - derives info from vendor's products
final vendorDetailsProvider =
    FutureProvider.family<VendorDetails?, String>((ref, vendorId) async {
  final products = await ref.watch(vendorProductsProvider(vendorId).future);

  if (products.isEmpty) {
    return VendorDetails(id: vendorId);
  }

  final product = products.first;
  final avgRating = products.isNotEmpty
      ? products.map((p) => p.averageRating).reduce((a, b) => a + b) /
          products.length
      : 0.0;

  return VendorDetails(
    id: vendorId,
    storeName: product.storeName ?? product.vendorName,
    rating: avgRating,
    productCount: products.length,
  );
});

/// Fetch all products from a vendor - includes closed stores
final vendorProductsProvider =
    FutureProvider.family<List<ProductModel>, String>((ref, vendorId) async {
  final repo = ref.watch(productsRepositoryProvider);

  // Fetch products including from closed stores (for store detail page)
  final result = await repo.fetchPublicProducts(
    limit: 100,
    includeClosedStores: true, // Show products even if store is closed
  );

  // Filter client-side by vendorId
  return result.products.where((p) => p.vendorId == vendorId).toList();
});
