import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/data/ads_repository.dart';
import 'package:trenda_shared/models/ad_model.dart';
import 'package:trenda_shared/core/config.dart';
import '../../core/providers/municipality_provider.dart';

final adsRepositoryProvider = Provider<AdsRepository>((ref) {
  return AdsRepository(baseUrl: AppConfig.backendBaseUrl);
});

/// State for paginated ads
class PaginatedAdsState {
  final List<AdModel> ads;
  final int currentPage;
  final int totalPages;
  final int totalAds;
  final bool isLoadingMore;
  final bool isSearching;
  final String searchQuery;
  final String? error;

  const PaginatedAdsState({
    this.ads = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalAds = 0,
    this.isLoadingMore = false,
    this.isSearching = false,
    this.searchQuery = '',
    this.error,
  });

  bool get hasMore => currentPage < totalPages;

  List<AdModel> get featuredAds => ads.where((ad) => ad.featured).toList();
  List<AdModel> get normalAds => ads.where((ad) => !ad.featured).toList();

  PaginatedAdsState copyWith({
    List<AdModel>? ads,
    int? currentPage,
    int? totalPages,
    int? totalAds,
    bool? isLoadingMore,
    bool? isSearching,
    String? searchQuery,
    String? error,
  }) {
    return PaginatedAdsState(
      ads: ads ?? this.ads,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalAds: totalAds ?? this.totalAds,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
      error: error,
    );
  }
}

/// The two ad kinds the Shop tab's lanes open. The values are what the server
/// stores on `Ad.kind`, so they are part of the API.
abstract final class AdKind {
  /// The Ads lane. Also covers every ad sold before `Ad.kind` existed — the
  /// server keeps those here.
  static const vendor = 'vendor';

  /// The Services lane.
  static const service = 'service';
}

/// Paginated ads notifier with search support, scoped to one [AdKind].
class PaginatedAdsNotifier
    extends AutoDisposeFamilyAsyncNotifier<PaginatedAdsState, String> {
  static const _pageSize = 15;

  /// The `Ad.kind` this list is for. Held so `loadMore` and `search` cannot
  /// silently widen the list to the other lane on page two.
  String get _kind => arg;

  @override
  Future<PaginatedAdsState> build(String kind) async {
    return _fetchPage(1, '');
  }

  Future<PaginatedAdsState> _fetchPage(int page, String search) async {
    final repo = ref.read(adsRepositoryProvider);
    final municipality = ref.read(municipalityProvider);

    final result = await repo.fetchPublicAds(
      page: page,
      limit: _pageSize,
      search: search.isNotEmpty ? search : null,
      municipality: municipality,
      kind: _kind,
    );

    final ads = result['ads'] as List<AdModel>;
    final total = result['total'] as int;
    final totalPages = result['totalPages'] as int;

    return PaginatedAdsState(
      ads: ads,
      currentPage: page,
      totalPages: totalPages,
      totalAds: total,
      searchQuery: search,
    );
  }

  /// Load more ads (next page)
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final repo = ref.read(adsRepositoryProvider);
      final municipality = ref.read(municipalityProvider);
      final nextPage = current.currentPage + 1;

      final result = await repo.fetchPublicAds(
        page: nextPage,
        limit: _pageSize,
        search: current.searchQuery.isNotEmpty ? current.searchQuery : null,
        municipality: municipality,
        // Page two must stay in the same lane as page one.
        kind: _kind,
      );

      final newAds = result['ads'] as List<AdModel>;
      final totalPages = result['totalPages'] as int;

      state = AsyncData(current.copyWith(
        ads: [...current.ads, ...newAds],
        currentPage: nextPage,
        totalPages: totalPages,
        isLoadingMore: false,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      ));
    }
  }

  /// Search ads with a query
  Future<void> search(String query) async {
    final trimmed = query.trim();
    final current = state.valueOrNull;

    // Skip if same query
    if (current != null && current.searchQuery == trimmed) return;

    state = AsyncData(PaginatedAdsState(
      isSearching: true,
      searchQuery: trimmed,
    ));

    try {
      final newState = await _fetchPage(1, trimmed);
      state = AsyncData(newState);
    } catch (e) {
      state = AsyncData(PaginatedAdsState(
        searchQuery: trimmed,
        error: e.toString(),
      ));
    }
  }

  /// Clear search and reload
  Future<void> clearSearch() async {
    state = const AsyncLoading();
    try {
      final newState = await _fetchPage(1, '');
      state = AsyncData(newState);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  /// Refresh all ads (pull-to-refresh)
  Future<void> refresh() async {
    final currentSearch = state.valueOrNull?.searchQuery ?? '';
    state = const AsyncLoading();
    try {
      final newState = await _fetchPage(1, currentSearch);
      state = AsyncData(newState);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}

/// Keyed by [AdKind]: the Ads lane and the Services lane are separate lists
/// with separate pagination and separate search state, so one cannot scroll
/// into the other.
final paginatedAdsProvider = AsyncNotifierProvider.autoDispose
    .family<PaginatedAdsNotifier, PaginatedAdsState, String>(
  PaginatedAdsNotifier.new,
);

/// Legacy provider for backward compatibility. Deliberately UNSCOPED — the Shop
/// tab's own rails have always shown whatever is running, of either kind.
final adsListProvider = FutureProvider<List<AdModel>>((ref) async {
  final repo = ref.watch(adsRepositoryProvider);
  final municipality = ref.watch(municipalityProvider);

  final result = await repo.fetchPublicAds(
    limit: 20,
    municipality: municipality,
  );
  return result['ads'] as List<AdModel>;
});
