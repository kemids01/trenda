// lib/features/products/presentation/product_browse_page.dart
// The three browse grids behind the Shop tab's quick lanes: "All items",
// "On sale" and "Palengke" (fresh market: vegetables, fruit, meat, fish).
//
// They are ONE page with three modes rather than two files, because everything
// below the heading is identical — the admin-curated carousel, the category
// chips derived from real inventory, the sort menu, the grid card. Only the
// source of products, the accent and the default order differ.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_shared/models/product_model.dart';

import '../../core/widgets/frontend_official_ad_slot.dart';
import '../../home/presentation/widgets/curated_carousel_header.dart';
import '../../home/presentation/widgets/shop_card_grid.dart';
import '../../home/presentation/widgets/shop_product_card.dart';
import '../../home/presentation/widgets/shop_stores_row.dart';
import '../../home/providers/shop_category_provider.dart' show palengkeStoresProvider;
import '../../home/providers/stores_provider.dart' show publicStoresProvider;
import '../../home/providers/shop_sections_provider.dart';
import '../providers/browse_paging_provider.dart';
import '../providers/products_provider.dart';
import '../utils/catalogue_browse.dart';

/// Which lane opened this page.
enum BrowseMode { allItems, onSale, palengke }

extension _BrowseModeSpec on BrowseMode {
  String get title => switch (this) {
        BrowseMode.allItems => 'All items',
        BrowseMode.onSale => 'On sale',
        BrowseMode.palengke => 'Palengke',
      };

  /// Matches the quick-lane tile colour, so the page reads as that lane opened
  /// rather than as a generic list.
  Color get accent => switch (this) {
        BrowseMode.allItems => const Color(0xFF2563EB),
        BrowseMode.onSale => const Color(0xFFDC2626),
        BrowseMode.palengke => const Color(0xFF15803D),
      };

  IconData get icon => switch (this) {
        BrowseMode.allItems => Icons.grid_view_rounded,
        BrowseMode.onSale => Icons.local_offer_rounded,
        BrowseMode.palengke => Icons.shopping_basket_rounded,
      };

  /// Which curated band the admin fills for this page.
  String get placement => switch (this) {
        BrowseMode.allItems => ShopSectionPlacement.allItems,
        BrowseMode.onSale => ShopSectionPlacement.onSale,
        BrowseMode.palengke => ShopSectionPlacement.palengke,
      };

  /// "All items" opens shuffled so the same vendors are not always on top;
  /// "On sale" opens on the deepest cut, which is what a shopper came for.
  BrowseSort get defaultSort => switch (this) {
        BrowseMode.allItems => BrowseSort.shuffle,
        BrowseMode.onSale => BrowseSort.biggestDiscount,
        // Freshest listings first: what came in today is what a shopper wants.
        BrowseMode.palengke => BrowseSort.newest,
      };

  List<BrowseSort> get sorts => switch (this) {
        BrowseMode.allItems => const [
            BrowseSort.shuffle,
            BrowseSort.newest,
            BrowseSort.priceLow,
            BrowseSort.priceHigh,
            BrowseSort.popular,
          ],
        BrowseMode.onSale => const [
            BrowseSort.biggestDiscount,
            BrowseSort.shuffle,
            BrowseSort.newest,
            BrowseSort.priceLow,
            BrowseSort.priceHigh,
          ],
        BrowseMode.palengke => const [
            BrowseSort.newest,
            BrowseSort.priceLow,
            BrowseSort.priceHigh,
            BrowseSort.popular,
            BrowseSort.shuffle,
          ],
      };

  List<ProductModel> source(List<ProductModel> all) => switch (this) {
        BrowseMode.allItems => browsableProducts(all),
        BrowseMode.onSale => onSaleProducts(all),
        BrowseMode.palengke => palengkeProducts(all),
      };

  String get emptyHeadline => switch (this) {
        BrowseMode.allItems => 'Nothing on the shelves yet',
        BrowseMode.onSale => 'No sales running right now',
        BrowseMode.palengke => 'No fresh market items yet',
      };

  String get emptyBody => switch (this) {
        BrowseMode.allItems =>
          'No shop in your city has anything in stock at the moment. '
              'Check back shortly.',
        BrowseMode.onSale =>
          'Shops in your city have not marked anything down today. '
              'The rest of the catalogue is still open.',
        BrowseMode.palengke =>
          'No vegetables, fruit, meat or fish are listed in your city right '
              'now. Vendors list them under Fresh Produce or Meat & Seafood.',
      };
}

class ProductBrowsePage extends ConsumerStatefulWidget {
  const ProductBrowsePage({super.key, required this.mode});

  final BrowseMode mode;

  @override
  ConsumerState<ProductBrowsePage> createState() => _ProductBrowsePageState();
}

/// The Palengke page's Official ad slot (both slot registries list it).
const String kPalengkeAdSlotId = 'frontend.palengke.top';

class _ProductBrowsePageState extends ConsumerState<ProductBrowsePage> {
  late BrowseSort _sort = widget.mode.defaultSort;
  String _category = kAllCategories;

  /// Held for the life of the page so the shuffle is stable: picking a category
  /// or scrolling must not deal the grid again under the shopper's thumb. Only
  /// the Shuffle button (and reopening the page) reseeds it.
  int _seed = DateTime.now().millisecondsSinceEpoch;

  void _reshuffle() => setState(() {
        _seed = DateTime.now().microsecondsSinceEpoch;
        _sort = BrowseSort.shuffle;
      });

  /// Palengke fetches its two categories server-side (the shared all-products
  /// page is capped and can hold none of them); the other modes need the
  /// whole catalogue page.
  FutureProvider<List<ProductModel>> get _products =>
      widget.mode == BrowseMode.palengke
          ? categoryProductsProvider(kPalengkeCategoryParam)
          : publicProductsProvider;

  Future<void> _refresh() async {
    ref.invalidate(_products);
    if (widget.mode == BrowseMode.palengke) ref.invalidate(publicStoresProvider);
    ref.invalidate(shopSectionsForPlacementProvider(widget.mode.placement));
    await ref.read(_products.future);
  }

  /// "All items" and "On sale" page from the server (browsePagingProvider);
  /// Palengke is already a small server-side slice and keeps its one list.
  bool get _paged => widget.mode != BrowseMode.palengke;

  BrowseQuery get _query => BrowseQuery(
        onSale: widget.mode == BrowseMode.onSale,
        category: _category,
        sort: _sort,
        seed: _seed,
      );

  /// The last chips the server sent. Changing a chip or the sort is a new
  /// query that starts loading from scratch; holding these keeps the filter
  /// bar on screen meanwhile instead of flashing away.
  List<String> _chips = const [kAllCategories];

  Future<void> _refreshPaged() async {
    ref.invalidate(shopSectionsForPlacementProvider(widget.mode.placement));
    ref.invalidate(browsePagingProvider(_query));
    await ref.read(browsePagingProvider(_query).future);
  }

  Widget _pagedBody(Color accent) {
    final query = _query;
    final paged = ref.watch(browsePagingProvider(query));
    final data = paged.valueOrNull;
    if (data != null && data.categories.isNotEmpty) {
      _chips = [kAllCategories, ...data.categories.map((c) => c.name)];
    }

    Widget filterBar(int count) => _FilterBar(
          categories: _chips,
          selected: _category,
          accent: accent,
          sort: _sort,
          sorts: widget.mode.sorts,
          count: count,
          onCategory: (c) => setState(() => _category = c),
          onSort: (s) => setState(() => _sort = s),
        );

    return RefreshIndicator(
      onRefresh: _refreshPaged,
      child: NotificationListener<ScrollNotification>(
        // Fetch the next page while the shopper is still ~a screen away.
        onNotification: (n) {
          if (n.metrics.extentAfter < 900) {
            ref.read(browsePagingProvider(query).notifier).loadMore();
          }
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: CuratedCarouselHeader(placement: widget.mode.placement),
            ),
            ...paged.when(
              skipLoadingOnReload: true,
              loading: () => [
                if (_chips.length > 1) SliverToBoxAdapter(child: filterBar(0)),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(error: e, onRetry: _refreshPaged),
                ),
              ],
              data: (s) {
                if (s.total == 0 && _category == kAllCategories) {
                  return [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(mode: widget.mode, accent: accent),
                    ),
                  ];
                }
                return [
                  SliverToBoxAdapter(child: filterBar(s.total)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    sliver: SliverGrid(
                      gridDelegate: const ShopCardGridDelegate(),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => ShopProductCard(
                          product: s.products[i],
                          onTap: () => context.push('/product/${s.products[i].id}'),
                        ),
                        childCount: s.products.length,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _PageFooter(
                      state: s,
                      accent: accent,
                      onRetry: () => ref.read(browsePagingProvider(query).notifier).loadMore(),
                    ),
                  ),
                ];
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // All items / On sale page from the server (_pagedBody); only Palengke
    // still reads one list of products.
    final productsAsync = _paged
        ? const AsyncValue<List<ProductModel>>.data([])
        : ref.watch(_products);
    final accent = widget.mode.accent;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF0E1116)
          : const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Icon(widget.mode.icon, size: 18),
            const SizedBox(width: 8),
            Text(
              widget.mode.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          if (widget.mode.sorts.contains(BrowseSort.shuffle))
            IconButton(
              tooltip: 'Shuffle',
              icon: const Icon(Icons.shuffle_rounded),
              onPressed: _reshuffle,
            ),
        ],
      ),
      body: _paged
          ? _pagedBody(accent)
          : RefreshIndicator(
        onRefresh: _refresh,
        child: productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(error: e, onRetry: _refresh),
          data: (all) {
            final source = widget.mode.source(all);
            final categories = browseCategories(source);
            // A category the shopper picked can vanish when the catalogue
            // reloads (last item sold out). Fall back rather than showing an
            // empty grid under a chip that is no longer there.
            final category =
                categories.contains(_category) ? _category : kAllCategories;
            final items = browseGrid(
              source,
              category: category,
              sort: _sort,
              seed: _seed,
            );

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Palengke only: the stores that sell fresh market items, then
                // its Official ad slot under them — the same top as the Shop
                // tab's category pages.
                if (widget.mode == BrowseMode.palengke) ...[
                  SliverToBoxAdapter(
                    child: ShopStoresRow(
                      stores: ref.watch(palengkeStoresProvider),
                      accent: accent,
                      emptyText: 'No Palengke stores in your city yet.',
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: FrontendOfficialAdSlot(slotId: kPalengkeAdSlotId),
                    ),
                  ),
                ],

                // Admin-curated carousel (📢 ADVERTISING ▸ Shop Tab Sections,
                // placement = this page). Renders nothing when unconfigured.
                SliverToBoxAdapter(
                  child: CuratedCarouselHeader(placement: widget.mode.placement),
                ),

                if (source.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(mode: widget.mode, accent: accent),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: _FilterBar(
                      categories: categories,
                      selected: category,
                      accent: accent,
                      sort: _sort,
                      sorts: widget.mode.sorts,
                      count: items.length,
                      onCategory: (c) => setState(() => _category = c),
                      onSort: (s) => setState(() => _sort = s),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    sliver: SliverGrid(
                      // Cells fit the card: square photo + its details block.
                      gridDelegate: const ShopCardGridDelegate(),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => ShopProductCard(
                          product: items[i],
                          onTap: () => context.push('/product/${items[i].id}'),
                        ),
                        childCount: items.length,
                      ),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Under the paged grid: loading the next page, a retry when it failed, or
/// "that's everything" once the last page is in.
class _PageFooter extends StatelessWidget {
  const _PageFooter({required this.state, required this.accent, required this.onRetry});

  final BrowsePagingState state;
  final Color accent;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))),
      );
    }
    if (state.loadMoreError != null) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: Icon(Icons.refresh_rounded, color: accent),
          label: Text('Could not load more — try again', style: TextStyle(color: accent)),
        ),
      );
    }
    if (!state.hasMore && state.products.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: Text(
            state.total == 1 ? "That's the only item" : "That's all ${state.total} items",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
          ),
        ),
      );
    }
    return const SizedBox(height: 8);
  }
}

/// Category chips + the sort menu, on one line above the grid.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.categories,
    required this.selected,
    required this.accent,
    required this.sort,
    required this.sorts,
    required this.count,
    required this.onCategory,
    required this.onSort,
  });

  final List<String> categories;
  final String selected;
  final Color accent;
  final BrowseSort sort;
  final List<BrowseSort> sorts;
  final int count;
  final ValueChanged<String> onCategory;
  final ValueChanged<BrowseSort> onSort;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 2),
          child: Row(
            children: [
              Text(
                count == 1 ? '1 item' : '$count items',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
              const Spacer(),
              PopupMenuButton<BrowseSort>(
                initialValue: sort,
                onSelected: onSort,
                itemBuilder: (_) => [
                  for (final s in sorts)
                    PopupMenuItem(value: s, child: Text(s.label)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort_rounded, size: 16, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        sort.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Only worth a row when there is something to choose between: a single
        // category plus "All" is two chips that do the same thing.
        if (categories.length > 2)
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = categories[i];
                final isSelected = c == selected;
                return ChoiceChip(
                  label: Text(c),
                  selected: isSelected,
                  onSelected: (_) => onCategory(c),
                  showCheckmark: false,
                  selectedColor: accent,
                  backgroundColor: scheme.surface,
                  side: BorderSide(
                    color: isSelected
                        ? accent
                        : scheme.onSurface.withValues(alpha: 0.12),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : scheme.onSurface,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.mode, required this.accent});

  final BrowseMode mode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(mode.icon, size: 32, color: accent),
            ),
            const SizedBox(height: 18),
            Text(
              mode.emptyHeadline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mode.emptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.wifi_off_rounded, size: 40, color: scheme.error),
        const SizedBox(height: 14),
        Text(
          'Could not load the catalogue',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$error',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}
