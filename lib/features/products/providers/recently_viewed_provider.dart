// lib/features/products/providers/recently_viewed_provider.dart
// Tracks recently viewed products locally

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trenda_shared/models/product_model.dart';

/// Maximum number of recently viewed items to store
const int _maxRecentItems = 20;
const String _recentlyViewedKey = 'recently_viewed_products';

/// Recently viewed products notifier
class RecentlyViewedNotifier extends StateNotifier<List<ProductModel>> {
  RecentlyViewedNotifier() : super([]) {
    _loadFromStorage();
  }

  /// Load recently viewed from local storage
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_recentlyViewedKey);
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json);
        state = decoded.map((e) => ProductModel.fromJson(e)).toList();
      }
    } catch (e) {
      // Ignore errors, start with empty list
      state = [];
    }
  }

  /// Save to local storage
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(state.map((p) => p.toJson()).toList());
      await prefs.setString(_recentlyViewedKey, json);
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Add a product to recently viewed (moves to front if already exists)
  void addProduct(ProductModel product) {
    // Remove if already exists (to move it to front)
    final filtered = state.where((p) => p.id != product.id).toList();

    // Add to front
    state = [product, ...filtered];

    // Limit to max items
    if (state.length > _maxRecentItems) {
      state = state.sublist(0, _maxRecentItems);
    }

    _saveToStorage();
  }

  /// Clear all recently viewed
  void clearAll() {
    state = [];
    _saveToStorage();
  }

  /// Remove a specific product
  void removeProduct(String productId) {
    state = state.where((p) => p.id != productId).toList();
    _saveToStorage();
  }
}

/// Provider for recently viewed products
final recentlyViewedProvider =
    StateNotifierProvider<RecentlyViewedNotifier, List<ProductModel>>(
  (ref) => RecentlyViewedNotifier(),
);

/// Provider for limited recently viewed (for home page display)
final recentlyViewedLimitedProvider = Provider<List<ProductModel>>((ref) {
  final all = ref.watch(recentlyViewedProvider);
  return all.take(10).toList(); // Show only first 10 on home
});
