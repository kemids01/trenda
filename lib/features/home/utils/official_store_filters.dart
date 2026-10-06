// lib/features/home/utils/official_store_filters.dart
// Pure (widget-free) filter/sort helpers for the Official Trenda Store surfaces
// (Hub tab, landing page, collection see-all). Kept separate so they can be unit-tested.
import 'package:trenda_shared/models/product_model.dart';

/// The Official Trenda Store owns products under this vendor id (the store clone's
/// `vendor` firebaseUid). Used to detect an official product on the shared detail page.
const String kOfficialStoreVendorId = 'official-trenda-store';

/// True when a product belongs to the Official Trenda Store.
bool isOfficialProduct(ProductModel p) =>
    isOfficialStore(vendorId: p.vendorId, storeName: p.storeName);

/// String-based Official Trenda check for surfaces without a full [ProductModel]
/// (cart items, order items). Matches the store vendor id or an "Official Trenda" store name.
bool isOfficialStore({String? vendorId, String? storeName}) =>
    vendorId == kOfficialStoreVendorId ||
    (storeName?.toLowerCase().contains('official trenda') ?? false);

/// Distinct categories present in the loaded official products, 'All' first.
/// Derived from the actual data so the chips never filter to an empty list.
List<String> officialCategories(List<ProductModel> products) {
  final set = <String>{};
  for (final p in products) {
    final c = p.category.trim();
    if (c.isNotEmpty) set.add(c);
  }
  final list = set.toList()..sort();
  return ['All', ...list];
}

/// True when a product is currently discounted (percentage or compare-at price).
bool officialOnSale(ProductModel p) =>
    p.discountPercentage > 0 ||
    (p.compareAtPrice != null && p.compareAtPrice! > p.basePrice);

/// Filter by category ('All' = no filter) + free-text query (name/category) +
/// optional on-sale / free-delivery / saved-only toggles.
List<ProductModel> filterOfficial(
  List<ProductModel> products, {
  String category = 'All',
  String query = '',
  bool onSaleOnly = false,
  bool freeDeliveryOnly = false,
  bool savedOnly = false,
  Set<String> savedIds = const {},
}) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  return products.where((p) {
    if (category != 'All' && p.category != category) return false;
    if (onSaleOnly && !officialOnSale(p)) return false;
    if (freeDeliveryOnly && !p.freeDelivery) return false;
    if (savedOnly && !savedIds.contains(p.id)) return false;
    if (words.isEmpty) return true;
    final hay = officialSearchText(p);
    return words.every(hay.contains);
  }).toList();
}

/// Everything a shopper might type for a product, lower-cased in one string.
/// A query matches when EVERY word appears somewhere in it, in any order —
/// so "soap dove" finds "Dove Soap Bar".
String officialSearchText(ProductModel p) => [
      p.name,
      p.category,
      p.subcategory ?? '',
      p.brand ?? '',
      ...p.tags,
      p.description ?? '',
    ].join(' ').toLowerCase();

/// Sort keys: newest (server order) | price_asc | price_desc | discount.
List<ProductModel> sortOfficial(List<ProductModel> products, String sortKey) {
  final list = [...products];
  switch (sortKey) {
    case 'price_asc':
      list.sort((a, b) => a.basePrice.compareTo(b.basePrice));
      break;
    case 'price_desc':
      list.sort((a, b) => b.basePrice.compareTo(a.basePrice));
      break;
    case 'discount':
      list.sort((a, b) => b.discountPercentage.compareTo(a.discountPercentage));
      break;
    case 'newest':
    default:
      break; // backend already returns newest-first
  }
  return list;
}

/// Convenience: filter then sort in one call.
List<ProductModel> applyOfficialFilters(
  List<ProductModel> products, {
  String category = 'All',
  String query = '',
  String sort = 'newest',
  bool onSaleOnly = false,
  bool freeDeliveryOnly = false,
  bool savedOnly = false,
  Set<String> savedIds = const {},
}) =>
    sortOfficial(
        filterOfficial(products,
            category: category,
            query: query,
            onSaleOnly: onSaleOnly,
            freeDeliveryOnly: freeDeliveryOnly,
            savedOnly: savedOnly,
            savedIds: savedIds),
        sort);

/// Human label for a sort key.
String officialSortLabel(String key) {
  switch (key) {
    case 'price_asc':
      return 'Price: Low to High';
    case 'price_desc':
      return 'Price: High to Low';
    case 'discount':
      return 'Biggest Discount';
    case 'newest':
    default:
      return 'Newest';
  }
}

const List<String> kOfficialSortKeys = [
  'newest',
  'price_asc',
  'price_desc',
  'discount',
];
