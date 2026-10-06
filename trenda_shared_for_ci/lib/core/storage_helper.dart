// trenda_shared/lib/core/storage_helper.dart
// ============================================================================
// STORAGE HELPER - SharedPreferences wrapper with type safety
// ============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Type-safe wrapper for SharedPreferences
class StorageHelper {
  static SharedPreferences? _prefs;

  /// Initialize the storage helper (call in main)
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get the SharedPreferences instance
  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError(
        'StorageHelper not initialized. Call StorageHelper.init() in main().',
      );
    }
    return _prefs!;
  }

  // ============================================================================
  // STRING
  // ============================================================================

  static String? getString(String key, {String? defaultValue}) {
    return prefs.getString(key) ?? defaultValue;
  }

  static Future<bool> setString(String key, String value) {
    return prefs.setString(key, value);
  }

  // ============================================================================
  // INT
  // ============================================================================

  static int? getInt(String key, {int? defaultValue}) {
    return prefs.getInt(key) ?? defaultValue;
  }

  static Future<bool> setInt(String key, int value) {
    return prefs.setInt(key, value);
  }

  // ============================================================================
  // DOUBLE
  // ============================================================================

  static double? getDouble(String key, {double? defaultValue}) {
    return prefs.getDouble(key) ?? defaultValue;
  }

  static Future<bool> setDouble(String key, double value) {
    return prefs.setDouble(key, value);
  }

  // ============================================================================
  // BOOL
  // ============================================================================

  static bool? getBool(String key, {bool? defaultValue}) {
    return prefs.getBool(key) ?? defaultValue;
  }

  static Future<bool> setBool(String key, bool value) {
    return prefs.setBool(key, value);
  }

  // ============================================================================
  // STRING LIST
  // ============================================================================

  static List<String>? getStringList(String key) {
    return prefs.getStringList(key);
  }

  static Future<bool> setStringList(String key, List<String> value) {
    return prefs.setStringList(key, value);
  }

  // ============================================================================
  // JSON
  // ============================================================================

  static Map<String, dynamic>? getJson(String key) {
    final str = prefs.getString(key);
    if (str == null) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> setJson(String key, Map<String, dynamic> value) {
    return prefs.setString(key, jsonEncode(value));
  }

  static List<dynamic>? getJsonList(String key) {
    final str = prefs.getString(key);
    if (str == null) return null;
    try {
      return jsonDecode(str) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> setJsonList(String key, List<dynamic> value) {
    return prefs.setString(key, jsonEncode(value));
  }

  // ============================================================================
  // TYPED OBJECT
  // ============================================================================

  static T? getObject<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final json = getJson(key);
    if (json == null) return null;
    try {
      return fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> setObject<T>(
    String key,
    T value,
    Map<String, dynamic> Function(T) toJson,
  ) {
    return setJson(key, toJson(value));
  }

  static List<T>? getObjectList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final list = getJsonList(key);
    if (list == null) return null;
    try {
      return list.cast<Map<String, dynamic>>().map((e) => fromJson(e)).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> setObjectList<T>(
    String key,
    List<T> value,
    Map<String, dynamic> Function(T) toJson,
  ) {
    return setJsonList(key, value.map((e) => toJson(e)).toList());
  }

  // ============================================================================
  // DATETIME
  // ============================================================================

  static DateTime? getDateTime(String key) {
    final millis = prefs.getInt(key);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<bool> setDateTime(String key, DateTime value) {
    return prefs.setInt(key, value.millisecondsSinceEpoch);
  }

  // ============================================================================
  // UTILITY
  // ============================================================================

  static Future<bool> remove(String key) {
    return prefs.remove(key);
  }

  static Future<bool> clear() {
    return prefs.clear();
  }

  static bool containsKey(String key) {
    return prefs.containsKey(key);
  }

  static Set<String> get keys => prefs.getKeys();
}

// ============================================================================
// STORAGE KEYS
// Define your storage keys here for type safety
// ============================================================================

abstract class StorageKeys {
  // Auth
  static const String authToken = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';

  // User preferences
  static const String themeMode = 'theme_mode';
  static const String locale = 'locale';
  static const String notificationsEnabled = 'notifications_enabled';

  // App state
  static const String onboardingComplete = 'onboarding_complete';
  static const String lastSyncTimestamp = 'last_sync_timestamp';
  static const String cachedCart = 'cached_cart';

  // Feature flags
  static const String featureFlags = 'feature_flags';
}
