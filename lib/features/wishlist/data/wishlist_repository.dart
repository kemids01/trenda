// lib/features/wishlist/data/wishlist_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/data/base_repository.dart';
import 'package:trenda_shared/core/config.dart';
import 'package:trenda_shared/models/product_model.dart';

class WishlistRepository extends BaseRepository {
  WishlistRepository({super.baseUrl});

  /// Get user's wishlist
  Future<List<ProductModel>> getWishlist() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/customer/wishlist');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      // Backend returns { success: true, data: { items: [products] } }
      final items = body['data']?['items'] ?? body['data'] ?? [];

      // ✅ Filter out invalid/deleted products that could cause UI bugs
      final products = <ProductModel>[];
      for (final item in items as List) {
        try {
          // Skip null items
          if (item == null) continue;

          // Skip products without essential data
          if (item['_id'] == null && item['id'] == null) continue;
          if (item['name'] == null || (item['name'] as String).isEmpty)
            continue;

          // Skip deleted products
          if (item['isDeleted'] == true) continue;

          products.add(ProductModel.fromJson(item));
        } catch (e) {
          // Skip products that fail to parse
          continue;
        }
      }

      return products;
    });
  }

  /// Add product to wishlist
  Future<void> addToWishlist(String productId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/customer/wishlist/add');

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({'productId': productId}),
          )
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
    });
  }

  /// Remove product from wishlist
  Future<void> removeFromWishlist(String productId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/customer/wishlist/remove/$productId');

      final response = await http
          .delete(uri, headers: headers(token))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
    });
  }

  /// Move wishlist item to cart
  Future<void> moveToCart(String productId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri =
          Uri.parse('$baseUrl/api/customer/wishlist/move-to-cart/$productId');

      final response = await http
          .post(uri, headers: headers(token))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
    });
  }

  /// Check if product is in wishlist
  Future<bool> isInWishlist(String productId) async {
    try {
      final wishlist = await getWishlist();
      return wishlist.any((product) => product.id == productId);
    } catch (e) {
      return false;
    }
  }
}
