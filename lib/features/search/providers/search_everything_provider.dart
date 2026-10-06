// lib/features/search/providers/search_everything_provider.dart
// One search for products, stores and ads — GET /api/search/everything
// (trenda_backend/utils/searchEverything.js owns the matching and ranking).
// The Shop, Trenda and Food docks all open the same page; Trenda starts on the
// Official scope and Food on the Food scope.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/core/config.dart';
import 'package:trenda_shared/models/ad_model.dart';
import 'package:trenda_shared/models/product_model.dart';
import 'package:trenda_shared/widgets/official_ad_slot.dart' show OfficialAdItem;

import '../../home/providers/stores_provider.dart' show StoreData;

/// Mirrors the backend's SEARCH_MIN_CHARS: shorter queries are not sent.
const int kSearchMinChars = 2;

enum SearchScope {
  all('all', 'Everything'),
  official('official', 'Official'),
  food('food', 'Food');

  final String param;
  final String label;
  const SearchScope(this.param, this.label);

  static SearchScope fromParam(Object? v) =>
      SearchScope.values.firstWhere((s) => s.param == v, orElse: () => SearchScope.all);
}

/// One search: the text, the scope and the shopper's city. Equal requests
/// share a cached result.
class SearchRequest {
  final String query;
  final SearchScope scope;
  final String? municipality;
  const SearchRequest(this.query, this.scope, this.municipality);

  bool get isSearchable => query.trim().length >= kSearchMinChars;

  @override
  bool operator ==(Object other) =>
      other is SearchRequest &&
      other.query == query &&
      other.scope == scope &&
      other.municipality == municipality;

  @override
  int get hashCode => Object.hash(query, scope, municipality);
}

class SearchEverythingResult {
  final List<ProductModel> products;
  final int productTotal;
  final List<StoreData> stores;
  final int storeTotal;
  final List<AdModel> listingAds; // vendor + service ads
  final List<OfficialAdItem> officialAds;
  final int adTotal;

  const SearchEverythingResult({
    this.products = const [],
    this.productTotal = 0,
    this.stores = const [],
    this.storeTotal = 0,
    this.listingAds = const [],
    this.officialAds = const [],
    this.adTotal = 0,
  });

  static const empty = SearchEverythingResult();

  int get adCount => listingAds.length + officialAds.length;
  bool get isEmpty => products.isEmpty && stores.isEmpty && adCount == 0;
  int get total => productTotal + storeTotal + adTotal;

  factory SearchEverythingResult.fromJson(Map<String, dynamic> data) {
    Map<String, dynamic> m(Object? v) => v is Map<String, dynamic> ? v : const {};
    List<Map<String, dynamic>> rows(Object? v) =>
        v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];
    int n(Object? v) => v is num ? v.toInt() : 0;

    final products = m(data['products']);
    final stores = m(data['stores']);
    final ads = m(data['ads']);
    return SearchEverythingResult(
      products: rows(products['items']).map(ProductModel.fromJson).toList(),
      productTotal: n(products['total']),
      // A store card with no id cannot open /store/:id.
      stores: rows(stores['items']).map(StoreData.fromJson).where((s) => s.id.isNotEmpty).toList(),
      storeTotal: n(stores['total']),
      listingAds: rows(ads['vendor']).map(AdModel.fromJson).toList(),
      officialAds: rows(ads['official']).map(OfficialAdItem.fromJson).toList(),
      adTotal: n(ads['total']),
    );
  }
}

/// Throws on a failed request so the page can offer Retry; a too-short query
/// resolves to [SearchEverythingResult.empty] without a network call.
final searchEverythingProvider = FutureProvider.autoDispose
    .family<SearchEverythingResult, SearchRequest>((ref, req) async {
  if (!req.isSearchable) return SearchEverythingResult.empty;
  final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/search/everything').replace(
    queryParameters: {
      'q': req.query.trim(),
      'scope': req.scope.param,
      if (req.municipality != null && req.municipality!.isNotEmpty) 'municipality': req.municipality!,
      'limit': '48',
    },
  );
  final res = await http
      .get(uri, headers: const {'Accept': 'application/json'})
      .timeout(AppConfig.connectTimeout);
  if (res.statusCode != 200) throw Exception('Search failed (${res.statusCode})');
  final body = jsonDecode(res.body);
  final data = body is Map<String, dynamic> ? body['data'] : null;
  if (data is! Map<String, dynamic>) throw Exception('Search returned nothing readable');
  return SearchEverythingResult.fromJson(data);
});

enum SearchProductSort {
  relevance('Best match'),
  priceLow('Price: low to high'),
  priceHigh('Price: high to low');

  final String label;
  const SearchProductSort(this.label);
}

/// Server order is relevance; the price sorts break ties on id so equal prices
/// never swap places between rebuilds.
List<ProductModel> sortSearchProducts(List<ProductModel> products, SearchProductSort sort) {
  if (sort == SearchProductSort.relevance) return products;
  final list = [...products];
  list.sort((a, b) {
    final byPrice = sort == SearchProductSort.priceLow
        ? a.basePrice.compareTo(b.basePrice)
        : b.basePrice.compareTo(a.basePrice);
    return byPrice != 0 ? byPrice : a.id.compareTo(b.id);
  });
  return list;
}
