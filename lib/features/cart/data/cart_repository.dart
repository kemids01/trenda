// lib/features/cart/data/cart_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/core/logger.dart';
import '../../core/utils/network_utils.dart';
import '../models/cart_model.dart';

class CartRepository {
  final String baseUrl;

  CartRepository({required this.baseUrl});

  Future<CartModel> getCart() async {
    try {
      final res = await NetworkUtils.authenticatedRequest(
        (token) => http.get(
          Uri.parse('$baseUrl/api/cart'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      // ✅ If no response (guest mode or auth failed), return empty cart gracefully
      if (res == null) {
        AppLogger.debug(
            'Cart: Not authenticated, returning empty cart', 'Cart');
        return CartModel.empty();
      }

      if (res.statusCode == 401) {
        // Token expired or invalid - let UI know
        AppLogger.debug('Cart: Auth token invalid (401)', 'Cart');
        return CartModel.empty();
      }

      if (res.statusCode != 200) {
        AppLogger.error('Cart: Failed to load (${res.statusCode})', null);
        return CartModel.empty();
      }

      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] != null) {
        return CartModel.fromJson(body['data']);
      }

      return CartModel.empty();
    } catch (e) {
      AppLogger.error('getCart error', e);
      return CartModel.empty();
    }
  }

  Future<void> addToCart({
    required String productId,
    required int quantity,
    String? variantId,
  }) async {
    _ensureOk(
      await NetworkUtils.postJson(
        '$baseUrl/api/cart/add',
        {
          'productId': productId,
          'quantity': quantity,
          if (variantId != null) 'variantId': variantId,
        },
      ),
      "Couldn't add this to your cart",
    );
  }

  Future<void> updateCartItem(String itemId, int quantity) async {
    _ensureOk(
      await NetworkUtils.putJson(
        '$baseUrl/api/cart/item/$itemId',
        {'quantity': quantity},
      ),
      "Couldn't change the quantity",
    );
  }

  Future<void> removeFromCart(String itemId) async {
    _ensureOk(
      await NetworkUtils.deleteJson('$baseUrl/api/cart/item/$itemId'),
      "Couldn't remove this item",
    );
  }

  Future<void> clearCart() async {
    _ensureOk(
      await NetworkUtils.deleteJson('$baseUrl/api/cart/clear'),
      "Couldn't empty your cart",
    );
  }

  /// Add multiple items from a previous order (reorder functionality).
  ///
  /// Keeps going past an item the server refuses (sold out since) and throws at
  /// the end naming how many did not make it, so one gone item does not stop the
  /// rest being re-added.
  Future<void> addItemsFromOrder(List<Map<String, dynamic>> items) async {
    var failed = 0;
    CartException? last;
    for (final item in items) {
      try {
        await addToCart(
          productId: item['productId'],
          quantity: item['quantity'],
          variantId: item['variantId'],
        );
      } on CartException catch (e) {
        failed++;
        last = e;
      }
    }
    if (failed == items.length && last != null) throw last;
    if (failed > 0) {
      throw CartException(
          '$failed of ${items.length} items could not be added: ${last!.message}');
    }
  }

  /// ⚠️ The NetworkUtils helpers return the response (or null) and never throw on
  /// a refusal. Every cart write used to ignore it, so a server "Insufficient
  /// stock. Available: 2" was reported to the shopper as "Added to cart".
  static void _ensureOk(http.Response? res, String fallback) {
    if (res == null) {
      throw CartException('$fallback. Check your connection and try again.');
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String? message;
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] is String) {
        message = (body['message'] as String).trim();
      }
    } catch (_) {
      // Not JSON (a host error page).
    }
    throw CartException(message == null || message.isEmpty ? fallback : message,
        statusCode: res.statusCode);
  }
}

/// A cart write the server refused (or that never reached it). [message] is safe
/// to show the shopper as-is.
class CartException implements Exception {
  final String message;
  final int? statusCode;
  const CartException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
