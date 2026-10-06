// trenda_shared/lib/data/products_repository.dart - FIXED & SIMPLIFIED
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:trenda_shared/core/config.dart';
import 'base_repository.dart';
import '../models/product_model.dart';
import '../models/bundle_model.dart';

// ============================================================================
// RESULT CLASSES
// ============================================================================

class ProductsFetchResult {
  final List<ProductModel> products;
  final int total;
  final int page;
  final int totalPages;

  ProductsFetchResult({
    required this.products,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}

/// One category chip on a browse page: its name and how many products it holds.
class BrowseCategoryCount {
  final String name;
  final int count;
  const BrowseCategoryCount(this.name, this.count);
}

/// One page of `GET /api/products/browse` (the paged "All items" / "On sale"
/// grids). [categories] comes with page 1 only — counted over the mode's
/// products before the category chip — and is empty on later pages.
class BrowsePageResult {
  final List<ProductModel> products;
  final int total;
  final int page;
  final int totalPages;
  final List<BrowseCategoryCount> categories;

  const BrowsePageResult({
    required this.products,
    required this.total,
    required this.page,
    required this.totalPages,
    this.categories = const [],
  });

  bool get hasMore => page < totalPages;

  /// Parses the endpoint's body: `data` (products), `pagination`, `categories`.
  factory BrowsePageResult.fromJson(Map<String, dynamic> body, {int page = 1}) {
    final data = body['data'];
    if (data is! List) throw Exception('Invalid product data format');
    final pagination = body['pagination'] as Map<String, dynamic>?;
    final cats = body['categories'];
    return BrowsePageResult(
      products: data.map((e) => ProductModel.fromJson(e as Map<String, dynamic>)).toList(),
      total: (pagination?['total'] as num?)?.toInt() ?? data.length,
      page: (pagination?['page'] as num?)?.toInt() ?? page,
      totalPages: (pagination?['pages'] as num?)?.toInt() ?? 1,
      categories: cats is List
          ? [
              for (final c in cats)
                if (c is Map && c['name'] is String)
                  BrowseCategoryCount(c['name'] as String, (c['count'] as num?)?.toInt() ?? 0),
            ]
          : const [],
    );
  }
}

class BundlesFetchResult {
  final List<ProductBundle> bundles;
  final int total;
  final int page;
  final int totalPages;

  BundlesFetchResult({
    required this.bundles,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}

/// Helper function for MIME type detection
String _getMimeType(String path) {
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'heic':
    case 'heif':
      return 'image/heic';
    default:
      return 'image/jpeg';
  }
}

class ProductsRepository extends BaseRepository {
  ProductsRepository({super.baseUrl});

  /// PUBLIC: one page of the "All items" / "On sale" grid. Filtering, the
  /// category chip, sorting and paging all run on the server
  /// (`GET /api/products/browse`). [sort] is the server key — shuffle,
  /// newest, priceLow, priceHigh, popular, discount; [seed] fixes the shuffle.
  Future<BrowsePageResult> fetchBrowseProducts({
    int page = 1,
    int limit = 40,
    String? municipality,
    bool onSale = false,
    String? category,
    String sort = 'shuffle',
    int seed = 0,
  }) async {
    return retryRequest(() async {
      final uri = Uri.parse('$baseUrl/api/products/browse').replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        'sort': sort,
        'seed': seed.toString(),
        if (onSale) 'onSale': 'true',
        if (category != null) 'category': category,
        if (municipality != null) 'municipality': municipality,
      });
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(AppConfig.connectTimeout);
      return BrowsePageResult.fromJson(parsePublicResponse(response), page: page);
    });
  }

  // ✅ PUBLIC: Fetch products without authentication (for guest users)
  Future<ProductsFetchResult> fetchPublicProducts({
    int page = 1,
    int limit = 20,
    String? search,
    String? category,
    String? municipality,
    bool? featured,
    bool includeClosedStores = false, // Show products from closed stores
    // Store-category group key (Shop tab category pages): only products of
    // stores in that group.
    String? storeCategory,
  }) async {
    return retryRequest(() async {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null) 'search': search,
        if (category != null) 'category': category,
        if (storeCategory != null) 'storeCategory': storeCategory,
        if (municipality != null) 'municipality': municipality,
        if (featured != null) 'featured': featured.toString(),
        if (includeClosedStores) 'includeClosedStores': 'true',
        'status': 'active', // Only show active products to public
      };

      final uri = Uri.parse(
        '$baseUrl/api/products',
      ).replace(queryParameters: queryParams);

      final headers = {'Accept': 'application/json'};

      final response = await http
          .get(uri, headers: headers)
          .timeout(AppConfig.connectTimeout);

      final body = parsePublicResponse(response);

      final dataList = body['data'];
      if (dataList == null || dataList is! List) {
        throw Exception('Invalid product data format');
      }

      final products = dataList
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();

      final pagination = body['pagination'] as Map<String, dynamic>?;

      return ProductsFetchResult(
        products: products,
        total: pagination?['total'] as int? ?? products.length,
        page: pagination?['page'] as int? ?? page,
        totalPages:
            (pagination?['pages'] ?? pagination?['totalPages'] ?? 1) as int,
      );
    });
  }

  // ✅ PUBLIC: Fetch Official Trenda Store products (no authentication).
  // Backend: GET /api/official-store/products → ApiResponse.paginated →
  //   { success, data: [ ...products ], pagination: {...} }   (data is a FLAT array;
  //   pagination is a SIBLING top-level field). Older/alternate handlers may nest as
  //   { data: { products: [...], pagination } } — tolerate BOTH. Each product is a
  //   normal Product shape (maps to ProductModel). Returns the same ProductsFetchResult.
  Future<ProductsFetchResult> fetchOfficialStoreProducts({
    String? municipality,
    String? category,
    String? search,
    int limit = 50,
    int page = 1,
  }) async {
    return retryRequest(() async {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null) 'search': search,
        if (category != null) 'category': category,
        if (municipality != null) 'municipality': municipality,
      };

      final uri = Uri.parse(
        '$baseUrl/api/official-store/products',
      ).replace(queryParameters: queryParams);

      final headers = {'Accept': 'application/json'};

      final response = await http
          .get(uri, headers: headers)
          .timeout(AppConfig.connectTimeout);

      final body = parsePublicResponse(response);

      // Tolerate both shapes:
      //   flat:   { data: [ ...products ], pagination: {...} }   (ApiResponse.paginated)
      //   nested: { data: { products: [...], pagination: {...} } }
      final data = body['data'];
      final List<dynamic> productList;
      final Map<String, dynamic>? pagination;
      if (data is List) {
        productList = data;
        pagination = body['pagination'] as Map<String, dynamic>?;
      } else if (data is Map<String, dynamic>) {
        final nested = data['products'];
        if (nested is! List) {
          throw Exception('Invalid official-store product data format');
        }
        productList = nested;
        pagination = (data['pagination'] ?? body['pagination'])
            as Map<String, dynamic>?;
      } else {
        throw Exception('Invalid official-store data format');
      }

      final products = productList
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();

      return ProductsFetchResult(
        products: products,
        total: pagination?['total'] as int? ?? products.length,
        page: pagination?['page'] as int? ?? page,
        totalPages:
            (pagination?['pages'] ?? pagination?['totalPages'] ?? 1) as int,
      );
    });
  }

  // ✅ FIXED: Single unified fetch method (requires authentication)
  Future<ProductsFetchResult> fetchProducts({
    int page = 1,
    int limit = 20,
    String? search,
    String? category,
    String? status,
    bool? featured,
    String? municipality, // NEW: Municipality filter
    bool vendorOnly = false, // ✅ Flag to fetch only vendor's products
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null) 'search': search,
        if (category != null) 'category': category,
        if (status != null) 'status': status,
        if (featured != null) 'featured': featured.toString(),
        if (municipality != null) 'municipality': municipality, // NEW
      };

      // ✅ Use correct endpoint based on context
      final endpoint = vendorOnly ? '/api/vendor/products' : '/api/products';
      final uri = Uri.parse(
        '$baseUrl$endpoint',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      final products = (body['data'] as List)
          .map((e) => ProductModel.fromJson(e))
          .toList();

      return ProductsFetchResult(
        products: products,
        total: body['pagination']?['total'] ?? products.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  // ✅ Convenience method for vendor products
  Future<ProductsFetchResult> fetchMyProducts({
    int page = 1,
    int limit = 20,
    String? status,
  }) {
    return fetchProducts(
      page: page,
      limit: limit,
      status: status,
      vendorOnly: true,
    );
  }

  // ✅ Create product - FIXED endpoint
  Future<ProductModel> createProduct(
    Map<String, dynamic> data, {
    List<File>? images,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      // ✅ Always use vendor endpoint for creation
      final uri = Uri.parse('$baseUrl/api/vendor/products');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token';

      // Add fields
      data.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      // Add images with explicit content type for mobile compatibility
      if (images != null) {
        for (final file in images) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'images',
              file.path,
              contentType: MediaType.parse(_getMimeType(file.path)),
            ),
          );
        }
      }

      final streamedRes = await request.send();
      final response = await http.Response.fromStream(streamedRes);
      final body = parseResponse(response);

      return ProductModel.fromJson(body['data']);
    });
  }

  // ✅ Update product - FIXED endpoint
  Future<ProductModel> updateProduct(
    String id,
    Map<String, dynamic> data, {
    List<File>? newImages,
    List<String>? removeImages,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      // ✅ Always use vendor endpoint for updates
      final uri = Uri.parse('$baseUrl/api/vendor/products/$id');
      final request = http.MultipartRequest('PUT', uri)
        ..headers['Authorization'] = 'Bearer $token';

      // Add fields
      data.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      if (removeImages != null) {
        request.fields['removeImages'] = jsonEncode(removeImages);
      }

      // Add new images with explicit content type for mobile compatibility
      if (newImages != null) {
        for (final file in newImages) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'images',
              file.path,
              contentType: MediaType.parse(_getMimeType(file.path)),
            ),
          );
        }
      }

      final streamedRes = await request.send();
      final response = await http.Response.fromStream(streamedRes);
      final body = parseResponse(response);

      return ProductModel.fromJson(body['data']);
    });
  }

  /// Delete single product
  Future<bool> deleteProduct(String productId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/products/$productId');

      final response = await http
          .delete(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
      return true;
    });
  }

  // ============================================================================
  // PENDING PRODUCTS (Staff-Assisted Product Creation)
  // ============================================================================

  /// Fetch pending products (drafts created by staff awaiting vendor approval)
  Future<ProductsFetchResult> fetchPendingProducts({
    int page = 1,
    int limit = 20,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {'page': page.toString(), 'limit': limit.toString()};

      final uri = Uri.parse(
        '$baseUrl/api/vendor/products/pending',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      final products = (body['data'] as List)
          .map((e) => ProductModel.fromJson(e))
          .toList();

      return ProductsFetchResult(
        products: products,
        total: body['pagination']?['total'] ?? products.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  /// Confirm a pending product (changes status from draft to active)
  Future<ProductModel> confirmProduct(String productId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/products/$productId/confirm');

      final response = await http
          .put(uri, headers: headers(token))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ProductModel.fromJson(body['data']);
    });
  }

  /// Reject a pending product (deletes it)
  Future<bool> rejectProduct(String productId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/products/$productId/reject');

      final response = await http
          .delete(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
      return true;
    });
  }

  // ============================================================================
  // PENDING EDITS (Staff edits requiring vendor approval)
  // ============================================================================

  /// Get products with pending edit changes from staff
  Future<List<ProductModel>> fetchProductsWithPendingEdits() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/products/pending-edits');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final list = body['data'] as List? ?? [];
      return list.map((json) => ProductModel.fromJson(json)).toList();
    });
  }

  /// Confirm/approve a pending edit from staff
  Future<ProductModel> confirmEdit(String productId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse(
        '$baseUrl/api/vendor/products/$productId/confirm-edit',
      );

      final response = await http
          .put(uri, headers: headers(token))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ProductModel.fromJson(body['data']);
    });
  }

  /// Reject/discard a pending edit from staff
  Future<bool> rejectEdit(String productId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse(
        '$baseUrl/api/vendor/products/$productId/reject-edit',
      );

      final response = await http
          .delete(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
      return true;
    });
  }

  /// Get product by ID (public - no authentication required)
  Future<ProductModel> getPublicProductById(String productId) async {
    return retryRequest(() async {
      final uri = Uri.parse('$baseUrl/api/products/$productId');

      // Token when signed in, so the view counts as this shopper on the seller's
      // Visitors card; the endpoint stays public.
      final headers = await optionalAuthHeaders();

      final response = await http
          .get(uri, headers: headers)
          .timeout(AppConfig.connectTimeout);

      final body = parsePublicResponse(response);
      // API returns nested structure: {"data": {"message": "...", "data": {...product...}}}
      final productData = body['data'];
      if (productData is Map<String, dynamic> &&
          productData.containsKey('data')) {
        return ProductModel.fromJson(productData['data']);
      }
      return ProductModel.fromJson(productData);
    });
  }

  /// Get product by ID (authenticated)
  Future<ProductModel> getProductById(String productId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/products/$productId');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ProductModel.fromJson(body['data']);
    });
  }

  /// Bulk update product status
  Future<List<String>> bulkUpdateProductStatus({
    required List<String> productIds,
    required String status,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/products/bulk/status');

      final response = await http
          .patch(
            uri,
            headers: headers(token),
            body: jsonEncode({'productIds': productIds, 'status': status}),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return List<String>.from(body['data']?['updatedIds'] ?? []);
    });
  }

  /// Bulk delete products
  Future<List<String>> bulkDeleteProducts(List<String> productIds) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/products/bulk/delete');

      final response = await http
          .delete(
            uri,
            headers: headers(token),
            body: jsonEncode({'productIds': productIds}),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return List<String>.from(body['data']?['deletedIds'] ?? []);
    });
  }

  // ============================================================================
  // BUNDLES (PUBLIC)
  // ============================================================================

  /// Fetch public bundles
  Future<BundlesFetchResult> fetchPublicBundles({
    int page = 1,
    int limit = 20,
    String? search,
    String? vendorId,
    String? minPrice,
    String? maxPrice,
    String? sort,
  }) async {
    return retryRequest(() async {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null) 'search': search,
        if (vendorId != null) 'vendorId': vendorId,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
        if (sort != null) 'sort': sort,
      };

      final uri = Uri.parse(
        '$baseUrl/api/bundles',
      ).replace(queryParameters: queryParams);

      final headers = {'Accept': 'application/json'};

      final response = await http
          .get(uri, headers: headers)
          .timeout(AppConfig.connectTimeout);

      final body = parsePublicResponse(response);
      final dataList = body['data'];
      if (dataList == null || dataList is! List) {
        throw Exception('Invalid bundle data format');
      }

      final bundles = dataList
          .map((e) => ProductBundle.fromJson(e as Map<String, dynamic>))
          .toList();

      final pagination = body['pagination'] as Map<String, dynamic>?;

      return BundlesFetchResult(
        bundles: bundles,
        total: pagination?['total'] as int? ?? bundles.length,
        page: pagination?['page'] as int? ?? page,
        totalPages:
            (pagination?['pages'] ?? pagination?['totalPages'] ?? 1) as int,
      );
    });
  }

  /// Get bundle by ID (public)
  Future<ProductBundle> getPublicBundleById(String bundleId) async {
    return retryRequest(() async {
      final uri = Uri.parse('$baseUrl/api/bundles/$bundleId');
      final headers = {'Accept': 'application/json'};

      final response = await http
          .get(uri, headers: headers)
          .timeout(AppConfig.connectTimeout);

      final body = parsePublicResponse(response);
      return ProductBundle.fromJson(body['data']);
    });
  }

  // ============================================================================
  // VARIANT MANAGEMENT
  // ============================================================================

  /// Get variants for a product
  Future<List<ProductVariant>> getVariants(String productId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/products/$productId/variants');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return (body['data'] as List)
          .map((e) => ProductVariant.fromJson(e))
          .toList();
    });
  }

  /// Add variant to product
  Future<ProductVariant> addVariant(
    String productId,
    Map<String, dynamic> data,
  ) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/products/$productId/variants');

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ProductVariant.fromJson(body['data']);
    });
  }

  /// Update variant
  Future<ProductVariant> updateVariant(
    String productId,
    String variantId,
    Map<String, dynamic> data,
  ) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse(
        '$baseUrl/api/vendor/products/$productId/variants/$variantId',
      );

      final response = await http
          .put(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ProductVariant.fromJson(body['data']);
    });
  }

  /// Delete variant
  Future<bool> deleteVariant(String productId, String variantId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse(
        '$baseUrl/api/vendor/products/$productId/variants/$variantId',
      );

      final response = await http
          .delete(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
      return true;
    });
  }
}
