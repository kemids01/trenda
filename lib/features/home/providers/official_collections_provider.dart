import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/core/config.dart';
import 'package:trenda_shared/models/product_model.dart';
import '../../core/providers/municipality_provider.dart';

/// A curated Official Trenda Store merchandising collection (e.g. "Trending
/// Now", "Flash Sale"). Backend serves already window/surface/municipality
/// filtered, non-empty sections.
class StoreCollection {
  final String id;
  final String title;
  final String? subtitle;
  final String type;
  final String? accentColor; // hex e.g. "#2563EB"; null → default gold theme
  final String? bannerImage; // optional hero banner url; null → accent bar only
  final List<ProductModel> products;

  const StoreCollection({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
    this.accentColor,
    this.bannerImage,
    required this.products,
  });

  factory StoreCollection.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'];
    final products = (rawProducts is List)
        ? rawProducts
            .whereType<Map<String, dynamic>>()
            .map((e) => ProductModel.fromJson(e))
            .toList()
        : <ProductModel>[];
    final banner = json['bannerImage']?.toString();
    return StoreCollection(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: json['subtitle']?.toString(),
      type: (json['type'] ?? '').toString(),
      accentColor: json['accentColor']?.toString(),
      bannerImage: (banner != null && banner.isNotEmpty) ? banner : null,
      products: products,
    );
  }
}

/// Parse a "#RRGGBB" / "RRGGBB" hex string into a Color; returns [fallback] when null/invalid.
Color colorFromHex(String? hex, Color fallback) {
  if (hex == null) return fallback;
  var h = hex.trim().replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

/// ---------------------------------------------------------------------------
/// 🏛️ OFFICIAL TRENDA STORE — CURATED COLLECTIONS (municipality-scoped, public)
/// ---------------------------------------------------------------------------
/// Mirrors [officialStoreProductsProvider]: same backend base URL
/// ([AppConfig.backendBaseUrl]) + same municipality resolution
/// ([municipalityProvider]). Hits `GET /api/official-store/collections` and
/// returns the served sections. On any error/empty → empty list so the UI can
/// simply hide the collections block (never throws to the UI).
final officialStoreCollectionsProvider =
    FutureProvider<List<StoreCollection>>((ref) async {
  final municipality = ref.watch(municipalityProvider);

  try {
    final queryParams = <String, String>{
      if (municipality != null) 'municipality': municipality,
    };

    final uri = Uri.parse(
      '${AppConfig.backendBaseUrl}/api/official-store/collections',
    ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(AppConfig.connectTimeout);

    if (response.statusCode != 200) return const [];

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return const [];
    if (body['success'] != true) return const [];

    final data = body['data'];
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => StoreCollection.fromJson(e))
        .where((c) => c.products.isNotEmpty)
        .toList();
  } catch (_) {
    // Never surface an error to the UI — just hide the collections block.
    return const [];
  }
});
