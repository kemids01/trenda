// lib/features/vendors/providers/vendor_follow_provider.dart
// ============================================================================
// VENDOR FOLLOW PROVIDER - State Management for Following Vendors
// ============================================================================
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_frontend/features/auth/data/providers.dart' show currentUidProvider;
import 'package:http/http.dart' as http;
import 'package:trenda_shared/trenda_shared.dart';
import 'package:trenda_shared/models/map_pin.dart';

// ============================================================================
// VENDOR REPOSITORY PROVIDER
// ============================================================================
final vendorRepositoryProvider = Provider<VendorRepository>((ref) {
  return VendorRepository();
});

/// Repository for vendor-related API calls
class VendorRepository extends BaseRepository {
  VendorRepository() : super();

  Future<VendorProfile?> getVendorProfile(String vendorId) async {
    try {
      final uri =
          Uri.parse('$baseUrl/api/stores/$vendorId?includeProducts=false');
      // Token when signed in → counted as this shopper on the store's Visitors card.
      final response = await http
          .get(uri, headers: await optionalAuthHeaders())
          .timeout(AppConfig.connectTimeout);

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body['success'] != true) return null;

      final store = body['data']?['store'];
      if (store == null) return null;

      // One parser for both callers. The hand-rolled copy that used to live
      // here dropped storeStatus (so the closed banner could never show),
      // category, municipality, address, phone, email and the trading hours —
      // all of which this endpoint returns — and defaulted isVerified to TRUE,
      // which put a verified tick on every unverified store.
      return VendorProfile.fromJson(
        Map<String, dynamic>.from(store),
        baseUrl: baseUrl,
        fallbackId: vendorId,
      );
    } catch (e) {
      return null;
    }
  }

  Future<List<VendorProduct>> getVendorProducts(String vendorId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/stores/$vendorId/products?limit=50');
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(AppConfig.connectTimeout);

      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body);
      if (body['success'] != true) return [];

      final products = body['data'] as List<dynamic>?;
      if (products == null) return [];

      return products.map((p) => VendorProduct.fromJson(p)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<VendorProfile>> getFollowedVendors() async {
    try {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendors/following');
      final response = await http
          .get(
            uri,
            headers: headers(token),
          )
          .timeout(AppConfig.connectTimeout);

      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body);
      if (body['success'] != true) return [];

      final vendors = body['data'] as List<dynamic>? ?? [];
      return vendors.map((v) => VendorProfile.fromJson(v)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Update follow status on backend
  Future<void> updateFollowStatus(String vendorId, bool isFollowing) async {
    try {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendors/$vendorId/follow');

      if (isFollowing) {
        // POST to follow
        await http
            .post(uri, headers: headers(token))
            .timeout(AppConfig.connectTimeout);
      } else {
        // DELETE to unfollow
        await http
            .delete(uri, headers: headers(token))
            .timeout(AppConfig.connectTimeout);
      }
    } catch (e) {
      // Log but don't throw - FCM subscription and local storage already handled
      if (kDebugMode) {
        print('⚠️ Failed to sync follow status: $e');
      }
    }
  }
}

// ============================================================================
// FOLLOWED VENDORS STATE
// ============================================================================
final followedVendorsProvider =
    StateNotifierProvider<FollowedVendorsNotifier, Set<String>>((ref) {
  // Rebuilt (and reloaded) on every account change — see currentUidProvider.
  ref.watch(currentUidProvider);
  return FollowedVendorsNotifier(ref);
});

class FollowedVendorsNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;

  FollowedVendorsNotifier(this._ref) : super({}) {
    _loadFollowedVendors();
  }

  Future<void> _loadFollowedVendors() async {
    try {
      final repo = _ref.read(vendorRepositoryProvider);
      final followed = await repo.getFollowedVendors();
      state = followed.map((v) => v.id).toSet();
    } catch (e) {
      // Load from local storage as fallback
      state = {};
    }
  }

  bool isFollowing(String vendorId) => state.contains(vendorId);

  Future<void> toggleFollow(String vendorId) async {
    if (state.contains(vendorId)) {
      state = {...state}..remove(vendorId);
    } else {
      state = {...state, vendorId};
    }
  }

  void addFollow(String vendorId) {
    state = {...state, vendorId};
  }

  void removeFollow(String vendorId) {
    state = {...state}..remove(vendorId);
  }
}

// ============================================================================
// SINGLE VENDOR FOLLOW STATUS
// ============================================================================
final isFollowingVendorProvider =
    Provider.family<bool, String>((ref, vendorId) {
  final followed = ref.watch(followedVendorsProvider);
  return followed.contains(vendorId);
});

// ============================================================================
// VENDOR PROFILE PROVIDER
// ============================================================================
final vendorProfileProvider =
    FutureProvider.family<VendorProfile?, String>((ref, vendorId) async {
  final repo = ref.read(vendorRepositoryProvider);
  return await repo.getVendorProfile(vendorId);
});

// ============================================================================
// VENDOR PRODUCTS PROVIDER
// ============================================================================
final vendorProductsProvider =
    FutureProvider.family<List<VendorProduct>, String>((ref, vendorId) async {
  final repo = ref.read(vendorRepositoryProvider);
  return await repo.getVendorProducts(vendorId);
});

// ============================================================================
// VENDOR PROFILE MODEL
// ============================================================================
class VendorProfile {
  final String id;
  final String storeName;
  final String? storeDescription;
  final String? logoUrl;
  final String? bannerUrl;
  final double rating;
  final int reviewCount;
  final int followerCount;
  final int productCount;
  final bool isVerified;
  final DateTime? memberSince;
  final bool isOpen;
  final String? nextOpenTime;

  /// Weekday the store next opens ('saturday'), from `storeStatus.nextOpenTime.day`.
  final String? nextOpenDay;

  /// Opening clock time ('08:00'), from that object's `open`/`time` field.
  final String? nextOpenAt;
  final String? accentColor;

  // --- Shop details. /api/stores/:id has always returned these; the profile
  // used to drop them on the floor, leaving the store page nothing real to say.
  final String? category;
  final String? municipality;
  final String? address;
  final String? phone;
  final String? email;
  final bool isFeatured;

  /// Where the shop is, when the backend's gate allowed it. Null for free vendors,
  /// hidden pins, unpinned stores, and when the platform flag is off.
  final MapPin? storePin;

  /// May a shopper message this shop? ⚠️ Absent means TRUE — never hide a button that
  /// still works because a payload was cached before the field existed.
  final bool chatEnabled;

  /// Weekly trading hours, either the VendorStoreHours MAP or the VendorStore
  /// LIST — see `utils/store_hours.dart`, which normalises both.
  final dynamic storeHours;
  final dynamic operatingHours;

  VendorProfile({
    required this.id,
    required this.storeName,
    this.storeDescription,
    this.logoUrl,
    this.bannerUrl,
    this.rating = 0,
    this.reviewCount = 0,
    this.followerCount = 0,
    this.productCount = 0,
    this.isVerified = false,
    this.memberSince,
    this.isOpen = true,
    this.nextOpenTime,
    this.nextOpenDay,
    this.nextOpenAt,
    this.accentColor,
    this.category,
    this.municipality,
    this.address,
    this.phone,
    this.email,
    this.isFeatured = false,
    this.storePin,
    this.chatEnabled = true,
    this.storeHours,
    this.operatingHours,
  });

  /// Parses a store payload.
  ///
  /// [baseUrl] absolutises relative image paths; [fallbackId] is used when the
  /// payload carries no id of its own (the store-details endpoint keys it by
  /// the vendor id the caller already knows).
  factory VendorProfile.fromJson(
    Map<String, dynamic> json, {
    String? baseUrl,
    String? fallbackId,
  }) {
    // storeStatus.nextOpenTime is an OBJECT ({date, day, open, close}); the old
    // toString() on it put a raw map behind the closed-store banner's "Opens".
    final next = json['storeStatus']?['nextOpenTime'];
    final Map<String, dynamic>? nextMap =
        next is Map ? Map<String, dynamic>.from(next) : null;

    String? absolute(String? url) {
      if (url == null || url.isEmpty) return null;
      if (baseUrl == null || url.startsWith('http')) return url;
      return '$baseUrl${url.startsWith('/') ? '' : '/'}$url';
    }

    String? text(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return VendorProfile(
      id: json['_id'] ?? json['id'] ?? json['vendor'] ?? fallbackId ?? '',
      storeName: json['storeName'] ?? json['name'] ?? 'Store',
      storeDescription: json['storeDescription'] ?? json['description'],
      logoUrl: absolute(
          json['logoUrl'] ?? json['logo'] ?? json['storelogo']),
      bannerUrl: absolute(json['storeBanner'] ??
          json['bannerUrl'] ??
          json['banner'] ??
          json['coverImage']),
      rating: (json['rating'] ?? json['averageRating'] ?? 0).toDouble(),
      reviewCount: json['reviewCount'] ?? json['totalReviews'] ?? 0,
      followerCount: json['followerCount'] ?? json['followers'] ?? 0,
      productCount: json['productCount'] ?? json['totalProducts'] ?? 0,
      isVerified: json['verified'] ?? json['isVerified'] ?? false,
      memberSince: json['memberSince'] != null
          ? DateTime.tryParse(json['memberSince'])
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'])
              : null),
      isOpen: json['storeStatus']?['isOpen'] ?? json['isOpen'] ?? true,
      nextOpenTime: nextMap == null ? next?.toString() : null,
      nextOpenDay: nextMap?['day']?.toString(),
      nextOpenAt: (nextMap?['open'] ?? nextMap?['time'])?.toString(),
      accentColor: json['theme']?['accentColor'] ?? json['accentColor'],
      category: text(json['category'] ?? json['businessType']),
      municipality: text(json['municipality'] ?? json['city']),
      address: text(json['address']),
      phone: text(json['phone']),
      email: text(json['email']),
      isFeatured: json['isFeatured'] ?? json['featured'] ?? false,
      storePin: MapPin.fromJson(
        json['storePin'] is Map ? Map<String, dynamic>.from(json['storePin'] as Map) : null,
      ),
      chatEnabled: json['chatEnabled'] != false,
      storeHours: json['storeHours'],
      operatingHours: json['operatingHours'],
    );
  }
}

// ============================================================================
// VENDOR PRODUCT MODEL
// ============================================================================
class VendorProduct {
  final String id;
  final String name;
  final String? description;
  final double basePrice;
  final double? salePrice;
  final List<String> images;
  final int stock;
  final bool inStock;
  final int soldCount;
  final double rating;
  final String pricingUnit;

  VendorProduct({
    required this.id,
    required this.name,
    this.description,
    required this.basePrice,
    this.salePrice,
    this.images = const [],
    this.stock = 0,
    this.inStock = true,
    this.soldCount = 0,
    this.rating = 0.0,
    this.pricingUnit = 'each',
  });

  factory VendorProduct.fromJson(Map<String, dynamic> json) {
    final stockValue = _stockFromJson(json);
    // Prioritize stock value - if stock > 0, product is in stock regardless of inStock field
    final isInStock = stockValue > 0 || (json['inStock'] == true);

    return VendorProduct(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      basePrice: (json['basePrice'] ?? json['price'] ?? 0).toDouble(),
      salePrice: json['salePrice'] != null
          ? (json['salePrice'] as num).toDouble()
          : null,
      images: List<String>.from(json['images'] ?? []),
      stock: stockValue,
      inStock: isInStock,
      soldCount: json['soldCount'] ?? json['totalSold'] ?? json['sales'] ?? 0,
      rating: (json['rating'] ?? json['averageRating'] ?? 0).toDouble(),
      pricingUnit: json['pricingUnit'] ?? 'each',
    );
  }

  /// Same rule as the shared ProductModel.stock: a product with variants sums
  /// them, otherwise `totalStock`. `/api/stores/:id/products` returns raw
  /// Product docs, which carry no `stock` field at all — reading only `stock`
  /// made every product on a store page read 0 and show SOLD OUT.
  static int _stockFromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    final variants = json['variants'];
    if (json['hasVariants'] == true && variants is List && variants.isNotEmpty) {
      return variants.fold<int>(
          0, (sum, v) => sum + (v is Map ? asInt(v['stock']) : 0));
    }
    return asInt(json['totalStock'] ?? json['stock'] ?? json['quantity'] ?? 0);
  }
}
