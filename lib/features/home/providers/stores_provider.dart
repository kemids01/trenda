// lib/features/home/providers/stores_provider.dart
// Provider for fetching public stores data

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/core/config.dart';
import 'package:trenda_shared/data/base_repository.dart' show optionalAuthHeaders;
import 'package:trenda_shared/core/logger.dart';
import 'package:trenda_shared/models/store_category.dart';
import '../../core/providers/municipality_provider.dart';

/// Store data model for display
class StoreData {
  final String id;
  final String name;
  final String? description;
  final String? logo;
  final String? coverImage;
  final String category;
  final double rating;
  final int reviewCount;
  final int productCount;
  final bool isFeatured;
  final String municipality;
  final String? address;
  final StoreStatus storeStatus;

  /// The store's place in the admin-managed store-category tree, or null when uncategorized.
  /// The Stores page's category chips filter on it (shared storeMatchesCategory).
  final StoreCategoryPick? storeCategory;

  StoreData({
    required this.id,
    required this.name,
    this.description,
    this.logo,
    this.coverImage,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.productCount,
    required this.isFeatured,
    required this.municipality,
    this.address,
    required this.storeStatus,
    this.storeCategory,
  });

  factory StoreData.fromJson(Map<String, dynamic> json) {
    return StoreData(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Store',
      description: json['description']?.toString(),
      logo: json['logo']?.toString(),
      coverImage: json['coverImage']?.toString(),
      // The store-category group name ('' when uncategorized — the card then shows only the city).
      category: json['category']?.toString() ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      productCount: json['productCount'] ?? 0,
      isFeatured: json['isFeatured'] ?? false,
      municipality: json['municipality']?.toString() ?? '',
      address: json['address']?.toString(),
      storeStatus: StoreStatus.fromJson(json['storeStatus'] ?? {}),
      storeCategory: StoreCategoryPick.fromJson(json['storeCategory']),
    );
  }
}

class StoreStatus {
  final bool isOpen;
  final String? nextOpenTime;

  /// Weekday the store next opens ('saturday'), from `nextOpenTime.day`.
  final String? nextOpenDay;

  /// Opening clock time ('08:00'), from `nextOpenTime.open` (VendorStoreHours)
  /// or `nextOpenTime.time` (the VendorStore schedule shape).
  final String? nextOpenAt;

  StoreStatus({
    required this.isOpen,
    this.nextOpenTime,
    this.nextOpenDay,
    this.nextOpenAt,
  });

  factory StoreStatus.fromJson(Map<String, dynamic> json) {
    // The backend sends nextOpenTime as an OBJECT
    // ({date, day, open, close, isSpecialHours}), so toString() alone yields an
    // unreadable map — pull the display fields out of it.
    final next = json['nextOpenTime'];
    final Map<String, dynamic>? nextMap =
        next is Map ? Map<String, dynamic>.from(next) : null;

    return StoreStatus(
      isOpen: json['isOpen'] ?? true,
      nextOpenTime: next?.toString(),
      nextOpenDay: nextMap?['day']?.toString(),
      nextOpenAt: (nextMap?['open'] ?? nextMap?['time'])?.toString(),
    );
  }
}

/// Provider to fetch public stores (with municipality filter)
final publicStoresProvider =
    FutureProvider<Map<String, List<StoreData>>>((ref) async {
  try {
    final baseUrl = AppConfig.backendBaseUrl;
    final municipality = ref.watch(municipalityProvider);

    // Build query params with municipality filter
    final queryParams = <String, String>{};
    if (municipality != null && municipality.isNotEmpty) {
      queryParams['municipality'] = municipality;
    }

    final uri = Uri.parse('$baseUrl/api/stores')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    AppLogger.debug('Fetching stores from: $uri', 'Stores');

    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    );

    AppLogger.debug('Stores response status: ${response.statusCode}', 'Stores');

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch stores: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to fetch stores');
    }

    final data = body['data'];
    AppLogger.debug(
        'Response data: featured=${(data['featured'] as List?)?.length ?? 0}, open=${(data['open'] as List?)?.length ?? 0}, closed=${(data['closed'] as List?)?.length ?? 0}',
        'Stores');

    final featured = (data['featured'] as List?)
            ?.map((e) => StoreData.fromJson(e))
            .toList() ??
        [];
    final open =
        (data['open'] as List?)?.map((e) => StoreData.fromJson(e)).toList() ??
            [];
    final closed =
        (data['closed'] as List?)?.map((e) => StoreData.fromJson(e)).toList() ??
            [];

    return {
      'featured': featured,
      'open': open,
      'closed': closed,
    };
  } catch (e) {
    throw Exception('Error loading stores: $e');
  }
});

/// Provider for a single store's details
final storeDetailsProvider =
    FutureProvider.family<StoreData?, String>((ref, vendorId) async {
  try {
    final baseUrl = AppConfig.backendBaseUrl;
    final uri =
        Uri.parse('$baseUrl/api/stores/$vendorId?includeProducts=false');

    // Token when signed in → counted as this shopper on the store's Visitors card.
    final response = await http.get(uri, headers: await optionalAuthHeaders());

    if (response.statusCode != 200) {
      return null;
    }

    final body = jsonDecode(response.body);
    if (body['success'] != true) {
      return null;
    }

    return StoreData.fromJson(body['data']['store']);
  } catch (e) {
    return null;
  }
});
