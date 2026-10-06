// lib/features/core/services/offline_cache_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trenda_shared/models/product_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for managing offline caching of data
class OfflineCacheService {
  static const _productsKey = 'cached_products';
  static const _categoriesKey = 'cached_categories';
  static const _lastSyncKey = 'last_sync_timestamp';
  static const _cacheExpiryHours = 24;

  static OfflineCacheService? _instance;
  late SharedPreferences _prefs;

  OfflineCacheService._();

  static Future<OfflineCacheService> getInstance() async {
    if (_instance == null) {
      _instance = OfflineCacheService._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  // Check connectivity
  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    // connectivity_plus returns List<ConnectivityResult> directly
    final List<ConnectivityResult> results = result;
    return !results.contains(ConnectivityResult.none);
  }

  // Cache expiry check
  bool isCacheExpired() {
    final lastSync = _prefs.getInt(_lastSyncKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - lastSync;
    final hours = diff / (1000 * 60 * 60);
    return hours > _cacheExpiryHours;
  }

  void _updateSyncTimestamp() {
    _prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Products cache
  Future<void> cacheProducts(List<ProductModel> products) async {
    final jsonList = products.map((p) => p.toJson()).toList();
    await _prefs.setString(_productsKey, jsonEncode(jsonList));
    _updateSyncTimestamp();
  }

  Future<List<ProductModel>?> getCachedProducts() async {
    final data = _prefs.getString(_productsKey);
    if (data == null) return null;

    try {
      final jsonList = jsonDecode(data) as List;
      return jsonList
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return null;
    }
  }

  // Categories cache
  Future<void> cacheCategories(List<String> categories) async {
    await _prefs.setStringList(_categoriesKey, categories);
  }

  Future<List<String>?> getCachedCategories() async {
    return _prefs.getStringList(_categoriesKey);
  }

  // Search results cache (by query)
  Future<void> cacheSearchResults(
      String query, List<ProductModel> products) async {
    final key = 'search_$query';
    final jsonList = products.map((p) => p.toJson()).toList();
    await _prefs.setString(key, jsonEncode(jsonList));
  }

  Future<List<ProductModel>?> getCachedSearchResults(String query) async {
    final key = 'search_$query';
    final data = _prefs.getString(key);
    if (data == null) return null;

    try {
      final jsonList = jsonDecode(data) as List;
      return jsonList
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return null;
    }
  }

  // Recently viewed products
  Future<void> addRecentlyViewed(ProductModel product) async {
    const key = 'recently_viewed';
    final existing = _prefs.getStringList(key) ?? [];

    // Remove if already exists (to re-add at front)
    existing.remove(product.id);

    // Add at front
    existing.insert(0, jsonEncode(product.toJson()));

    // Keep only last 20
    final trimmed = existing.take(20).toList();
    await _prefs.setStringList(key, trimmed);
  }

  Future<List<ProductModel>> getRecentlyViewed() async {
    const key = 'recently_viewed';
    final data = _prefs.getStringList(key) ?? [];

    return data
        .map((jsonStr) {
          try {
            return ProductModel.fromJson(jsonDecode(jsonStr));
          } catch (e) {
            return null;
          }
        })
        .whereType<ProductModel>()
        .toList();
  }

  // Clear all cache
  Future<void> clearCache() async {
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('cached_') ||
          key.startsWith('search_') ||
          key == 'recently_viewed') {
        await _prefs.remove(key);
      }
    }
  }
}
