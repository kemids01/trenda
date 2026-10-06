// lib/features/home/providers/shop_sections_provider.dart
// Curated merchandising bands for the Shop tab, configured in the admin app
// (🏛️ Official Trenda Stores ▸ Shop Tab Sections) and served already
// municipality-filtered with their products resolved.
//
// Products may be Official Trenda store items or ordinary vendor items — both
// are retail products, so they parse into the same [ProductModel].
//
// A band shelves EITHER products or vendor STORES (`contentType`). Store cards
// arrive in the same shape `/api/stores` serves, so they parse into the same
// [StoreData] the Stores tab uses and draw with the same card.
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/core/config.dart';
import 'package:trenda_shared/models/product_model.dart';
import '../../core/providers/municipality_provider.dart';
import 'stores_provider.dart' show StoreData;

/// One admin-curated band: a heading, an optional subtitle, the colours it is
/// drawn in, and the products in the order the admin arranged them.
class ShopSection {
  final String id;
  final String title;
  final String? subtitle;

  /// Hex (`#RRGGBB`) for the band behind the carousel; null → the page surface.
  final String? backgroundColor;

  /// Hex for the heading tint; null → the app's primary colour.
  final String? accentColor;

  /// Hex for the rounded card the carousel sits on; null → white.
  final String? carouselColor;

  /// Hex for the subtitle; null → a muted shade of the band's ink.
  final String? subtitleColor;

  final List<ProductModel> products;

  /// The vendor stores this band features. Empty unless [shelvesStores].
  final List<StoreData> stores;

  /// 'products' | 'stores'.
  ///
  /// ⚠️ Absent means PRODUCTS. Bands created before store bands existed carry
  /// no `contentType`, and treating absent as anything else empties every one
  /// of them.
  final String contentType;

  bool get shelvesStores => contentType == 'stores';

  /// How many cards this band will draw — whichever shelf it uses. A band with
  /// none is not worth rendering.
  int get itemCount => shelvesStores ? stores.length : products.length;

  const ShopSection({
    required this.id,
    required this.title,
    this.subtitle,
    this.backgroundColor,
    this.accentColor,
    this.carouselColor,
    this.subtitleColor,
    required this.products,
    this.stores = const [],
    this.contentType = 'products',
  });

  factory ShopSection.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'];
    final products = (rawProducts is List)
        ? rawProducts
            .whereType<Map<String, dynamic>>()
            .map((e) => ProductModel.fromJson(e))
            .toList()
        : <ProductModel>[];

    final rawStores = json['stores'];
    final stores = (rawStores is List)
        ? rawStores
            .whereType<Map<String, dynamic>>()
            .map((e) => StoreData.fromJson(e))
            // A card with no id cannot be tapped through to /store/:id, so it
            // is worse than absent.
            .where((s) => s.id.isNotEmpty)
            .toList()
        : <StoreData>[];

    String? nonEmpty(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return ShopSection(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: nonEmpty(json['subtitle']),
      backgroundColor: nonEmpty(json['backgroundColor']),
      accentColor: nonEmpty(json['accentColor']),
      carouselColor: nonEmpty(json['carouselColor']),
      subtitleColor: nonEmpty(json['subtitleColor']),
      products: products,
      stores: stores,
      // Anything unrecognised falls back to products rather than to a band that
      // draws nothing.
      contentType:
          (json['contentType'] ?? '').toString() == 'stores' ? 'stores' : 'products',
    );
  }
}

/// The customer surfaces that carry an admin-curated carousel. The value is the
/// `placement` the server stores, so these strings are part of the API.
abstract final class ShopSectionPlacement {
  /// The Shop tab's stack of bands, under the quick lanes.
  static const shopTab = 'shop_tab';

  /// The single band above the "All items" grid.
  static const allItems = 'all_items';

  /// The single band above the "On sale" grid.
  static const onSale = 'on_sale';

  /// The single band above the Palengke (fresh market) grid.
  static const palengke = 'palengke';

  /// The Food tab's store and featured-food carousels. Per city with an
  /// all-cities default: the server drops a default band when the city has
  /// its own band of the same kind.
  static const foodTab = 'food_tab';
}

/// `GET /api/shop-sections?municipality=&placement=` — active bands serving
/// this city on ONE surface.
///
/// Keyed by placement because each surface gets its own carousel: a page that
/// rendered another page's band would be worse than one that rendered none.
///
/// Fails soft on every error: the page simply renders without the band rather
/// than showing an error where merchandising should be.
final shopSectionsForPlacementProvider =
    FutureProvider.family<List<ShopSection>, String>((ref, placement) async {
  final municipality = ref.watch(municipalityProvider);

  try {
    final queryParams = <String, String>{
      if (municipality != null) 'municipality': municipality,
      'placement': placement,
    };

    final uri = Uri.parse('${AppConfig.backendBaseUrl}/api/shop-sections')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

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
        .map((e) => ShopSection.fromJson(e))
        // Whichever shelf the band uses — an empty one renders as a coloured
        // strip with a heading and nothing under it.
        .where((s) => s.itemCount > 0)
        .toList();
  } catch (_) {
    return const [];
  }
});

/// The Shop tab's own bands. An alias so the tab's ~4 readers did not all have
/// to learn about placements.
final shopSectionsProvider = FutureProvider<List<ShopSection>>(
  (ref) => ref.watch(
    shopSectionsForPlacementProvider(ShopSectionPlacement.shopTab).future,
  ),
);
