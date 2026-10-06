// lib/features/vendors/providers/vendor_category_provider.dart
// ============================================================================
// VENDOR CATEGORY PROVIDER - FOR CUSTOMER VIEW
// ============================================================================

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/trenda_shared.dart';

/// Model for public category view
class VendorCategoryItem {
  final String id;
  final String name;
  final String? description;
  final String? image;
  final int productCount;
  final List<ProductSummaryItem> featuredProducts;

  VendorCategoryItem({
    required this.id,
    required this.name,
    this.description,
    this.image,
    this.productCount = 0,
    this.featuredProducts = const [],
  });

  factory VendorCategoryItem.fromJson(Map<String, dynamic> json) {
    return VendorCategoryItem(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      image: json['image'],
      productCount: json['productCount'] ?? 0,
      featuredProducts: (json['featuredProducts'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((p) => ProductSummaryItem.fromJson(p))
              .toList() ??
          [],
    );
  }
}

/// Lightweight product summary for carousel display
class ProductSummaryItem {
  final String id;
  final String name;
  final String? slug;
  final List<String> images;
  final double basePrice;
  final double? salePrice;
  final String status;
  final int soldCount;
  final double rating;
  final String pricingUnit;

  /// Units on hand: variants summed when the product has them, else
  /// totalStock — the same rule as the shared ProductModel.stock.
  final int stock;

  ProductSummaryItem({
    required this.id,
    required this.name,
    this.slug,
    this.images = const [],
    required this.basePrice,
    this.salePrice,
    this.status = 'active',
    this.soldCount = 0,
    this.rating = 0.0,
    this.pricingUnit = 'each',
    this.stock = 0,
  });

  String? get primaryImage => images.isNotEmpty ? images.first : null;
  double get displayPrice => salePrice ?? basePrice;
  bool get hasDiscount => salePrice != null && salePrice! < basePrice;

  factory ProductSummaryItem.fromJson(Map<String, dynamic> json) {
    return ProductSummaryItem(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'],
      images: (json['images'] as List<dynamic>?)?.cast<String>() ?? [],
      basePrice: (json['basePrice'] ?? 0).toDouble(),
      salePrice: json['salePrice']?.toDouble(),
      status: json['status'] ?? 'active',
      soldCount: json['soldCount'] ?? json['totalSold'] ?? json['sales'] ?? 0,
      rating: (json['rating'] ?? json['averageRating'] ?? 0).toDouble(),
      pricingUnit: json['pricingUnit'] ?? 'each',
      stock: _stockFromJson(json),
    );
  }

  static int _stockFromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    final variants = json['variants'];
    if (json['hasVariants'] == true && variants is List && variants.isNotEmpty) {
      return variants.fold<int>(
          0, (sum, v) => sum + (v is Map ? asInt(v['stock']) : 0));
    }
    return asInt(json['totalStock'] ?? json['stock'] ?? 0);
  }
}

/// Fetch public categories for a vendor
final vendorCategoriesProvider =
    FutureProvider.family<List<VendorCategoryItem>, String>(
  (ref, vendorId) async {
    if (vendorId.isEmpty) return [];

    try {
      final uri = Uri.parse(
          '${AppConfig.backendBaseUrl}/api/vendors/$vendorId/categories');
      final response =
          await http.get(uri, headers: {'Accept': 'application/json'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['categories'] != null) {
          return (data['categories'] as List)
              .map((c) => VendorCategoryItem.fromJson(c))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching vendor categories: $e');
      return [];
    }
  },
);

/// Parameters for fetching category products
typedef CategoryProductsParams = ({String vendorId, String categoryId});

/// Fetch products for a specific category
final categoryProductsProvider =
    FutureProvider.family<List<ProductModel>, CategoryProductsParams>(
  (ref, params) async {
    if (params.categoryId.isEmpty || params.vendorId.isEmpty) return [];

    try {
      // Use the public route: /api/vendors/:vendorId/categories/:id
      final uri = Uri.parse(
          '${AppConfig.backendBaseUrl}/api/vendors/${params.vendorId}/categories/${params.categoryId}');
      final response =
          await http.get(uri, headers: {'Accept': 'application/json'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['category'] != null) {
          // Extract products from the category response
          final category = data['category'];
          final products = category['products'] as List<dynamic>? ?? [];
          return products
              .whereType<Map<String, dynamic>>()
              .map((p) => ProductModel.fromJson(p))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching category products: $e');
      return [];
    }
  },
);
