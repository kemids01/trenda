// lib/features/home/utils/home_rails.dart
// Derives the home screen's merchandising rails from the products already
// fetched for the municipality. Pure, so the shelves can be tested without a
// network or a widget tree.
//
// These replace two wireframe placeholders ("TOP 10 / NON FEATURED ADS /
// CAROUSEL") that shipped to customers as grey boxes with a generic icon.

import 'package:trenda_shared/models/product_model.dart';

/// Anything a customer could actually buy right now.
bool _buyable(ProductModel p) => !p.isOutOfStock;

/// Discounted items, deepest cut first. Empty when nothing is on sale — the
/// caller hides the rail rather than showing an empty shelf.
List<ProductModel> topDeals(List<ProductModel> products, {int limit = 10}) {
  final deals = products
      .where((p) => _buyable(p) && p.discountPercentage > 0)
      .toList()
    ..sort((a, b) {
      final byDiscount = b.discountPercentage.compareTo(a.discountPercentage);
      if (byDiscount != 0) return byDiscount;
      // Tie-break on price so the order is stable between rebuilds.
      return a.basePrice.compareTo(b.basePrice);
    });
  return deals.take(limit).toList();
}

/// What other people in the municipality are actually buying.
List<ProductModel> bestSellers(List<ProductModel> products, {int limit = 10}) {
  final sellers = products.where((p) => _buyable(p) && p.sales > 0).toList()
    ..sort((a, b) {
      final bySales = b.sales.compareTo(a.sales);
      if (bySales != 0) return bySales;
      return b.averageRating.compareTo(a.averageRating);
    });
  return sellers.take(limit).toList();
}

/// Newest listings first.
List<ProductModel> freshArrivals(List<ProductModel> products, {int limit = 10}) {
  final fresh = products.where(_buyable).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return fresh.take(limit).toList();
}

/// Vendor-featured items, falling back to the newest so the shelf is never
/// empty on a catalogue where nobody has paid for featuring.
List<ProductModel> featuredShelf(List<ProductModel> products, {int limit = 10}) {
  final featured =
      products.where((p) => _buyable(p) && p.featured).take(limit).toList();
  if (featured.length >= limit) return featured;

  final seen = featured.map((p) => p.id).toSet();
  for (final p in freshArrivals(products, limit: limit * 2)) {
    if (featured.length >= limit) break;
    if (seen.add(p.id)) featured.add(p);
  }
  return featured;
}

/// The categories present in this municipality's catalogue, most stocked first.
///
/// Home category tiles are derived from real inventory rather than a hardcoded
/// list, so a city never shows a category it cannot sell.
List<String> catalogueCategories(
  List<ProductModel> products, {
  int limit = 8,
}) {
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
  return ordered.take(limit).toList();
}

/// '₱1,299' — grouped thousands, no decimals, the way prices are shown on a
/// shelf. Decimals belong on the product page, not the rail.
String shelfPrice(double amount) {
  final whole = amount.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  return '₱$buf';
}
