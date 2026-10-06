// lib/features/products/providers/browse_paging_provider.dart
// Paged "All items" / "On sale" grids (GET /api/products/browse).
//
// The server filters, applies the category chip, sorts and pages — the same
// rules catalogue_browse.dart applied on the phone to one capped page of 500,
// which past 500 products silently showed a subset. One provider instance per
// [BrowseQuery]: a new chip, sort or shuffle seed is a new query and starts
// again at page 1, so pages from two different orders can never be mixed.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/data/products_repository.dart';
import 'package:trenda_shared/models/product_model.dart';

import '../../core/providers/municipality_provider.dart';
import '../utils/catalogue_browse.dart';
import 'products_provider.dart';

/// Products per page. Two phone screens of the grid, so the next page is
/// usually loaded before the shopper reaches the bottom.
const int kBrowsePageSize = 40;

/// The server's key for each [BrowseSort].
String browseSortParam(BrowseSort sort) => switch (sort) {
      BrowseSort.shuffle => 'shuffle',
      BrowseSort.newest => 'newest',
      BrowseSort.priceLow => 'priceLow',
      BrowseSort.priceHigh => 'priceHigh',
      BrowseSort.popular => 'popular',
      BrowseSort.biggestDiscount => 'discount',
    };

/// What one paged grid shows.
@immutable
class BrowseQuery {
  const BrowseQuery({
    required this.onSale,
    required this.category,
    required this.sort,
    required this.seed,
  });

  final bool onSale;

  /// A chip name, or [kAllCategories].
  final String category;
  final BrowseSort sort;
  final int seed;

  @override
  bool operator ==(Object other) =>
      other is BrowseQuery &&
      other.onSale == onSale &&
      other.category == category &&
      other.sort == sort &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(onSale, category, sort, seed);
}

@immutable
class BrowsePagingState {
  const BrowsePagingState({
    this.products = const [],
    this.page = 0,
    this.totalPages = 0,
    this.total = 0,
    this.categories = const [],
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<ProductModel> products;
  final int page;
  final int totalPages;

  /// Products matching the query across ALL pages (the count the page shows).
  final int total;

  /// The category chips (from page 1), most stocked first.
  final List<BrowseCategoryCount> categories;
  final bool isLoadingMore;

  /// A failed next page — the loaded pages stay; scrolling retries.
  final Object? loadMoreError;

  bool get hasMore => page < totalPages;

  BrowsePagingState copyWith({
    List<ProductModel>? products,
    int? page,
    int? totalPages,
    int? total,
    bool? isLoadingMore,
    Object? loadMoreError,
  }) =>
      BrowsePagingState(
        products: products ?? this.products,
        page: page ?? this.page,
        totalPages: totalPages ?? this.totalPages,
        total: total ?? this.total,
        categories: categories,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        loadMoreError: loadMoreError,
      );
}

class BrowsePagingNotifier
    extends AutoDisposeFamilyAsyncNotifier<BrowsePagingState, BrowseQuery> {
  @override
  Future<BrowsePagingState> build(BrowseQuery query) async {
    // Watched: a city change starts the grid again.
    final municipality = ref.watch(municipalityProvider);
    final first = await _fetch(1, municipality);
    return BrowsePagingState(
      products: first.products,
      page: first.page,
      totalPages: first.totalPages,
      total: first.total,
      categories: first.categories,
    );
  }

  Future<BrowsePageResult> _fetch(int page, String? municipality) =>
      ref.read(productsRepositoryProvider).fetchBrowseProducts(
            page: page,
            limit: kBrowsePageSize,
            municipality: municipality,
            onSale: arg.onSale,
            category: arg.category == kAllCategories ? null : arg.category,
            sort: browseSortParam(arg.sort),
            seed: arg.seed,
          );

  /// Appends the next page. No-op while one is loading or when there is none.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next =
          await _fetch(current.page + 1, ref.read(municipalityProvider));
      // Keyed by id: a product that moved between pages while the shopper
      // scrolled (a stock change) is never drawn twice.
      final seen = {for (final p in current.products) p.id};
      state = AsyncData(current.copyWith(
        products: [
          ...current.products,
          ...next.products.where((p) => seen.add(p.id))
        ],
        page: next.page,
        totalPages: next.totalPages,
        total: next.total,
        isLoadingMore: false,
      ));
    } catch (e) {
      state =
          AsyncData(current.copyWith(isLoadingMore: false, loadMoreError: e));
    }
  }
}

final browsePagingProvider = AsyncNotifierProvider.autoDispose
    .family<BrowsePagingNotifier, BrowsePagingState, BrowseQuery>(
        BrowsePagingNotifier.new);
