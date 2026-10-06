// trenda_shared/lib/data/products_repository_extensions.dart
// Helper methods to bridge the product form with the repository

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../models/product_model.dart';
import 'products_repository.dart';

extension ProductsRepositoryExtensions on ProductsRepository {
  /// Create a product with all form fields
  Future<ProductModel> createProductWithDetails({
    required String name,
    String? description,
    String? shortDescription,
    required double basePrice,
    double? compareAtPrice,
    double? cost,
    required int totalStock,
    required String category,
    String? subcategory,
    required String vendorId,
    List<String> tags = const [],
    List<File>? images,
    String? brand,
    String? manufacturer,
    bool featured = false,
    bool freeShipping = false,
    double? weight,
    ProductDimensions? dimensions,
    bool hasVariants = false,
    List<ProductVariant> variants = const [],
    ProductLocation? location,
    double deliveryRadius = 10.0,
    bool pickupAvailable = true,
    bool deliveryAvailable = true,
    String status = 'draft',
  }) async {
    // Build the data map
    final data = <String, dynamic>{
      'name': name,
      'basePrice': basePrice,
      'totalStock': totalStock,
      'category': category,
      'vendor': vendorId,
      'status': status,
      'featured': featured,
      'freeShipping': freeShipping,
      'hasVariants': hasVariants,
      'deliveryRadius': deliveryRadius,
      'pickupAvailable': pickupAvailable,
      'deliveryAvailable': deliveryAvailable,
    };

    // Add optional fields
    if (description != null) data['description'] = description;
    if (shortDescription != null) data['shortDescription'] = shortDescription;
    if (compareAtPrice != null) data['compareAtPrice'] = compareAtPrice;
    if (cost != null) data['cost'] = cost;
    if (subcategory != null) data['subcategory'] = subcategory;
    if (brand != null) data['brand'] = brand;
    if (manufacturer != null) data['manufacturer'] = manufacturer;
    if (weight != null) data['weight'] = weight;
    
    // Add complex objects as JSON strings
    if (tags.isNotEmpty) data['tags'] = jsonEncode(tags);
    if (dimensions != null) data['dimensions'] = jsonEncode(dimensions.toJson());
    if (variants.isNotEmpty) {
      data['variants'] = jsonEncode(variants.map((v) => v.toJson()).toList());
    }
    if (location != null) data['location'] = jsonEncode(location.toJson());

    // Use the base repository method
    return createProduct(data, images: images);
  }

  /// Update a product with all form fields
  Future<ProductModel> updateProductWithDetails({
    required String productId,
    String? name,
    String? description,
    String? shortDescription,
    double? basePrice,
    double? compareAtPrice,
    double? cost,
    int? totalStock,
    String? category,
    String? subcategory,
    List<String>? tags,
    String? brand,
    String? manufacturer,
    bool? featured,
    String? status,
    bool? freeShipping,
    double? weight,
    ProductDimensions? dimensions,
    bool? hasVariants,
    List<ProductVariant>? variants,
    ProductLocation? location,
    double? deliveryRadius,
    bool? pickupAvailable,
    bool? deliveryAvailable,
    List<File>? newImages,
    List<String>? removeImages,
  }) async {
    // Build the data map with only provided fields
    final data = <String, dynamic>{};

    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (shortDescription != null) data['shortDescription'] = shortDescription;
    if (basePrice != null) data['basePrice'] = basePrice;
    if (compareAtPrice != null) data['compareAtPrice'] = compareAtPrice;
    if (cost != null) data['cost'] = cost;
    if (totalStock != null) data['totalStock'] = totalStock;
    if (category != null) data['category'] = category;
    if (subcategory != null) data['subcategory'] = subcategory;
    if (brand != null) data['brand'] = brand;
    if (manufacturer != null) data['manufacturer'] = manufacturer;
    if (featured != null) data['featured'] = featured;
    if (status != null) data['status'] = status;
    if (freeShipping != null) data['freeShipping'] = freeShipping;
    if (weight != null) data['weight'] = weight;
    if (hasVariants != null) data['hasVariants'] = hasVariants;
    if (deliveryRadius != null) data['deliveryRadius'] = deliveryRadius;
    if (pickupAvailable != null) data['pickupAvailable'] = pickupAvailable;
    if (deliveryAvailable != null) data['deliveryAvailable'] = deliveryAvailable;

    // Add complex objects as JSON strings
    if (tags != null) data['tags'] = jsonEncode(tags);
    if (dimensions != null) data['dimensions'] = jsonEncode(dimensions.toJson());
    if (variants != null) {
      data['variants'] = jsonEncode(variants.map((v) => v.toJson()).toList());
    }
    if (location != null) data['location'] = jsonEncode(location.toJson());

    // Use the base repository method
    return updateProduct(
      productId,
      data,
      newImages: newImages,
      removeImages: removeImages,
    );
  }

  /// Fetch a single product by ID
  Future<ProductModel> fetchProductById(String productId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/products/$productId');
      
      final response = await http.get(
        uri,
        headers: headers(token, json: false),
      ).timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ProductModel.fromJson(body['data']);
    });
  }

  /// Delete a product
  Future<void> deleteProduct(String productId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/products/$productId');
      
      final response = await http.delete(
        uri,
        headers: headers(token, json: false),
      ).timeout(AppConfig.connectTimeout);

      parseResponse(response);
    });
  }

  /// Bulk update product status
  Future<void> bulkUpdateStatus({
    required List<String> productIds,
    required String status,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/products/bulk-update');
      
      final response = await http.post(
        uri,
        headers: headers(token),
        body: jsonEncode({
          'productIds': productIds,
          'status': status,
        }),
      ).timeout(AppConfig.connectTimeout);

      parseResponse(response);
    });
  }

  /// Toggle product featured status
  Future<ProductModel> toggleFeatured(String productId, bool featured) async {
    return updateProductWithDetails(
      productId: productId,
      featured: featured,
    );
  }

  /// Update product stock
  Future<ProductModel> updateStock(String productId, int stock) async {
    return updateProductWithDetails(
      productId: productId,
      totalStock: stock,
    );
  }

  /// Duplicate a product
  Future<ProductModel> duplicateProduct(
    String productId,
    String newName,
  ) async {
    // First fetch the original product
    final original = await fetchProductById(productId);
    
    // Create a new product with similar details
    return createProductWithDetails(
      name: newName,
      description: original.description,
      shortDescription: original.shortDescription,
      basePrice: original.basePrice,
      compareAtPrice: original.compareAtPrice,
      cost: original.cost,
      totalStock: 0, // Start with 0 stock
      category: original.category,
      subcategory: original.subcategory,
      vendorId: original.vendorId,
      tags: original.tags,
      brand: original.brand,
      manufacturer: original.manufacturer,
      featured: false,
      freeShipping: original.freeShipping,
      weight: original.weight,
      dimensions: original.dimensions,
      hasVariants: original.hasVariants,
      variants: original.variants,
      location: original.location,
      deliveryRadius: original.deliveryRadius,
      pickupAvailable: original.pickupAvailable,
      deliveryAvailable: original.deliveryAvailable,
      status: 'draft',
    );
  }
}
