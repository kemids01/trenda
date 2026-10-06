// lib/features/products/utils/catalogue_browse.dart
// The ordering and filtering behind the "All items" and "On sale" grids.
//
// Pure and widget-free, so the rules can be tested without a network or a
// widget tree — and so the two pages cannot drift into filtering the same
// catalogue differently.

import 'dart:math';

import 'package:trenda_shared/models/product_model.dart';

/// How a browse grid is ordered.
///
/// [shuffle] is the default for "All items": the catalogue is small enough that
/// a fixed order would show the same handful of vendors at the top forever.
enum BrowseSort { shuffle, newest, priceLow, priceHigh, popular, biggestDiscount }

extension BrowseSortLabel on BrowseSort {
  String get label => switch (this) {
        BrowseSort.shuffle => 'Surprise me',
        BrowseSort.newest => 'Newest first',
        BrowseSort.priceLow => 'Price: low to high',
        BrowseSort.priceHigh => 'Price: high to low',
        BrowseSort.popular => 'Most reviewed',
        BrowseSort.biggestDiscount => 'Biggest discount',
      };
}

/// The chip shown first in every category filter. Not a category — a clear-all.
const String kAllCategories = 'All';

/// Anything a shopper could actually buy right now. An out-of-stock card is a
/// dead end, and a grid is mostly dead ends if it does not say this.
bool _buyable(ProductModel p) => !p.isOutOfStock;

/// Everything the "All items" grid draws from.
List<ProductModel> browsableProducts(List<ProductModel> products) =>
    products.where(_buyable).toList();

/// Everything the "On sale" grid draws from: a vendor has set a compare-at
/// price above what they are charging.
///
/// ⚠️ This is the ONE definition of "on sale" the app uses — the Shop tab's
/// deals rail derives from the same `discountPercentage`. A second rule here
/// would put a product on the sale page that carries no sale badge.
List<ProductModel> onSaleProducts(List<ProductModel> products) =>
    products.where((p) => _buyable(p) && p.discountPercentage > 0).toList();

/// The product categories a palengke (wet market) sells: vegetables and fruit,
/// and meat and fish. These are existing categories (shared
/// `AppConfig.productCategories` + backend `Product.category`), so a vendor's
/// listing reaches Palengke with no extra tagging.
const List<String> kPalengkeCategories = ['Fresh Produce', 'Meat & Seafood'];

/// [kPalengkeCategories] as the `?category=` list the server takes (any of them).
final String kPalengkeCategoryParam = kPalengkeCategories.join(',');

final Set<String> _palengkeKeys =
    kPalengkeCategories.map((c) => c.toLowerCase()).toSet();

/// Everything the Palengke grid draws from: in-stock fresh-market products.
/// Category spelling is matched loosely (case and spaces), since it is free
/// text on older listings.
List<ProductModel> palengkeProducts(List<ProductModel> products) => products
    .where((p) =>
        _buyable(p) && _palengkeKeys.contains(p.category.trim().toLowerCase()))
    .toList();

/// The categories actually present in [products], most stocked first, with
/// [kAllCategories] at the front.
///
/// Derived from real inventory rather than a fixed list, so a city never offers
/// a filter that matches nothing — the hardcoded eight-category chip row this
/// replaced showed "Automotive" in a town that sells none.
List<String> browseCategories(List<ProductModel> products) {
  final counts = <String, int>{};
  for (final p in products) {
    final c = p.category.trim();
    if (c.isEmpty) continue;
    counts[c] = (counts[c] ?? 0) + 1;
  }
  final ordered = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.toLowerCase().compareTo(b.toLowerCase());
    });
  return [kAllCategories, ...ordered];
}

/// Orders [products] for display.
///
/// [seed] drives [BrowseSort.shuffle] and is the reason the grid does not
/// re-order under the shopper's thumb: the caller holds one seed for as long as
/// the page is open, so every rebuild — a filter change, a scroll, a keyboard
/// opening — produces the SAME shuffle. A fresh seed is what reshuffles.
///
/// Every sort ends on a stable tie-break (id), because Dart's `sort` is not
/// stable and two equally-priced products would otherwise swap places on an
/// unrelated rebuild.
List<ProductModel> sortForBrowse(
  List<ProductModel> products,
  BrowseSort sort, {
  required int seed,
}) {
  final out = [...products];
  switch (sort) {
    case BrowseSort.shuffle:
      out.shuffle(Random(seed));
      return out;
    case BrowseSort.newest:
      out.sort((a, b) {
        final c = b.createdAt.compareTo(a.createdAt);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    case BrowseSort.priceLow:
      out.sort((a, b) {
        final c = a.basePrice.compareTo(b.basePrice);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    case BrowseSort.priceHigh:
      out.sort((a, b) {
        final c = b.basePrice.compareTo(a.basePrice);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    case BrowseSort.popular:
      out.sort((a, b) {
        final c = b.totalReviews.compareTo(a.totalReviews);
        if (c != 0) return c;
        final byRating = b.averageRating.compareTo(a.averageRating);
        return byRating != 0 ? byRating : a.id.compareTo(b.id);
      });
    case BrowseSort.biggestDiscount:
      out.sort((a, b) {
        final c = b.discountPercentage.compareTo(a.discountPercentage);
        if (c != 0) return c;
        final byPrice = a.basePrice.compareTo(b.basePrice);
        return byPrice != 0 ? byPrice : a.id.compareTo(b.id);
      });
  }
  return out;
}

/// Narrows [products] to one category. [kAllCategories] (or null) clears it.
///
/// Matched case-insensitively: product categories are free text on the way in,
/// and a chip that matches nothing because of a capital letter reads as an
/// empty catalogue.
List<ProductModel> filterByCategory(
  List<ProductModel> products,
  String? category,
) {
  if (category == null || category == kAllCategories || category.trim().isEmpty) {
    return products;
  }
  final want = category.trim().toLowerCase();
  return products.where((p) => p.category.trim().toLowerCase() == want).toList();
}

/// The whole pipeline in the order the grids apply it: buyable → category →
/// sort. One function so "All items" and "On sale" cannot disagree about it.
List<ProductModel> browseGrid(
  List<ProductModel> source, {
  String? category,
  BrowseSort sort = BrowseSort.shuffle,
  required int seed,
}) =>
    sortForBrowse(filterByCategory(source, category), sort, seed: seed);
