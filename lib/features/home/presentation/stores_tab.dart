// lib/features/home/presentation/stores_tab.dart
// Stores page (Shop tab ▸ Stores lane, `/category/stores`): the city's shops as
// a semi-full-screen carousel. One shop per page — cover, logo, name, what it
// sells, rating, product count, hours, description and address — with the
// neighbours peeking in at the edges so it is obvious there is more to swipe.
//
// The deck is ordered featured → open → closed (utils/store_carousel.dart);
// chips narrow it to open or featured shops. Tapping a card or "Visit store"
// opens the store page, which is unchanged.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/municipality_provider.dart';
import '../../stores/utils/store_carousel.dart';
import '../../stores/utils/storefront_style.dart';
import '../providers/stores_provider.dart';
import '../utils/carousel_loop.dart';
import 'widgets/official_qr_scan.dart';
import 'widgets/store_category_chips.dart';

const Color _kOpen = Color(0xFF157347);
const Color _kGold = Color(0xFFC79A3C);

/// How much of the width the current card takes; neighbours share the rest.
const double _kViewport = 0.86;
const double _kNeighbourScale = 0.93;

/// Selected chip. Riverpod, not widget state (§13 rule 1).
final storeFilterProvider =
    StateProvider.autoDispose<StoreFilter>((_) => StoreFilter.all);

/// Text in the bottom search bar; narrows the deck by name/category/address.
final storeSearchProvider = StateProvider.autoDispose<String>((_) => '');

/// Below this the card would overflow, so the page scrolls instead of
/// squeezing — e.g. with the keyboard up while searching.
const double _kMinDeckHeight = 540;

class StoresTab extends ConsumerWidget {
  const StoresTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(publicStoresProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: dark ? const Color(0xFF0E1116) : const Color(0xFFF5F6F8),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(publicStoresProvider);
          await ref.read(publicStoresProvider.future);
        },
        child: storesAsync.when(
          loading: () => const _FullHeight(child: CircularProgressIndicator()),
          error: (e, s) => _FullHeight(
            child: _Notice(
              icon: Icons.wifi_tethering_off_rounded,
              title: 'Could not load shops',
              body: 'Check your connection and try again.',
              action: FilledButton.icon(
                onPressed: () => ref.invalidate(publicStoresProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ),
          ),
          data: (data) {
            final deck = carouselDeck(
              featured: data['featured'] ?? const [],
              open: data['open'] ?? const [],
              closed: data['closed'] ?? const [],
            );
            if (deck.isEmpty) {
              return const _FullHeight(
                child: _Notice(
                  icon: Icons.storefront_outlined,
                  title: 'No shops here yet',
                  body: 'Vendors in your city are still setting up.\n'
                      'Pull down to refresh.',
                ),
              );
            }
            return _StoresCarousel(deck: deck);
          },
        ),
      ),
    );
  }
}

class _StoresCarousel extends ConsumerStatefulWidget {
  const _StoresCarousel({required this.deck});
  final List<StoreData> deck;

  @override
  ConsumerState<_StoresCarousel> createState() => _StoresCarouselState();
}

class _StoresCarouselState extends ConsumerState<_StoresCarousel> {
  // Endless: the carousel opens deep in an unbounded PageView, so swiping past
  // the last shop lands on the first (utils/carousel_loop.dart). A new
  // controller per deck, because the opening page depends on the deck's size.
  late PageController _controller;
  late double _page;

  @override
  void initState() {
    super.initState();
    _controller = _controllerFor(_currentDeck().length);
  }

  PageController _controllerFor(int count) {
    final start = loopInitialPage(count);
    _page = start.toDouble();
    return PageController(viewportFraction: _kViewport, initialPage: start)
      ..addListener(_onScroll);
  }

  void _onScroll() {
    final p = _controller.page;
    if (p != null && p != _page) setState(() => _page = p);
  }

  /// The deck as the providers stand right now (build watches the same three).
  List<StoreData> _currentDeck() => filterStoresByCategory(
      searchStores(filterStores(widget.deck, ref.read(storeFilterProvider)),
          ref.read(storeSearchProvider).trim()),
      ref.read(storeCategoryFilterProvider));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The deck changed: back to its first card, looping over the new size.
  void _restart() {
    final old = _controller;
    setState(() => _controller = _controllerFor(_currentDeck().length));
    // Detached by the next frame, once the PageView has the new controller.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _select(StoreFilter f) {
    ref.read(storeFilterProvider.notifier).state = f;
    _restart();
  }

  /// A category chip changed: back to the first card.
  void _resetDeck() => _restart();

  void _search(String q) {
    ref.read(storeSearchProvider.notifier).state = q;
    _restart();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(storeFilterProvider);
    final query = ref.watch(storeSearchProvider).trim();
    final category = ref.watch(storeCategoryFilterProvider);
    final shown = filterStoresByCategory(
        searchStores(filterStores(widget.deck, filter), query), category);
    final openCount = widget.deck.where((s) => s.storeStatus.isOpen).length;
    final hasFeatured = widget.deck.any((s) => s.isFeatured);
    final current = loopIndex(_page.round(), shown.length);

    // A fixed-height column inside a scroll view, so pull-to-refresh still
    // works on a page whose main content scrolls sideways. The search + QR
    // bar sits outside it, pinned to the bottom (and above the keyboard).
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: constraints.maxHeight < _kMinDeckHeight
                    ? _kMinDeckHeight
                    : constraints.maxHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(total: widget.deck.length, openCount: openCount),
                    _Filters(
                      selected: filter,
                      showFeatured: hasFeatured,
                      onSelect: _select,
                    ),
                    StoreCategoryChips(onChanged: _resetDeck),
                    const SizedBox(height: 10),
                    Expanded(
                      child: shown.isEmpty
                          ? (!category.isAll
                              ? const _Notice(
                                  icon: Icons.category_outlined,
                                  title: 'No shops in this category yet',
                                  body: 'Tap “All categories” to browse every shop.',
                                )
                              : query.isNotEmpty
                              ? _Notice(
                                  icon: Icons.search_off_rounded,
                                  title: 'No shop matches “$query”',
                                  body: 'Try another name or category,\n'
                                      'or clear the search.',
                                )
                              : _Notice(
                                  icon: Icons.nights_stay_outlined,
                                  title: filter == StoreFilter.open
                                      ? 'Every shop is closed right now'
                                      : 'No featured shops yet',
                                  body: 'Tap “All” to browse every shop.',
                                ))
                          : PageView.builder(
                              key: ObjectKey(_controller),
                              controller: _controller,
                              itemCount: loopItemCount(shown.length),
                              itemBuilder: (context, page) {
                                final i = loopIndex(page, shown.length);
                                final distance =
                                    (page - _page).abs().clamp(0.0, 1.0);
                                final scale =
                                    1 - (1 - _kNeighbourScale) * distance;
                                return Transform.scale(
                                  scale: scale,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    child: _StoreCard(
                                      store: shown[i],
                                      onOpen: () =>
                                          context.push('/store/${shown[i].id}'),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (shown.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Center(
                          child: _Pager(count: shown.length, current: current)),
                    ],
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
        _SearchBar(onChanged: _search),
      ],
    );
  }
}

/// Pinned under the carousel: search shops by name/category/address, and scan
/// a shop's QR (store codes only — see scanStoreQr).
class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  // Seeded from the provider so the box and the filter never disagree.
  late final _text = TextEditingController(text: ref.read(storeSearchProvider));

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _clear() {
    _text.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasText = ref.watch(storeSearchProvider).isNotEmpty;
    final field = scheme.onSurface.withValues(alpha: dark ? 0.08 : 0.05);

    return Material(
      color: dark ? const Color(0xFF171B22) : scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top:
                BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _text,
                      onChanged: widget.onChanged,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search shops',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: hasText
                            ? IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: _clear,
                              )
                            : null,
                        filled: true,
                        fillColor: field,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Scan store QR',
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: FilledButton(
                      onPressed: () => scanStoreQr(context),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: scheme.onSurface,
                        foregroundColor: scheme.surface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded,
                          size: 22, semanticLabel: 'Scan store QR'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.total, required this.openCount});
  final int total;
  final int openCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final city = ref.watch(municipalityProvider)?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total == 1 ? '1 shop' : '$total shops',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  (city == null || city.isEmpty) ? 'Near you' : 'in $city',
                  style:
                      TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          _StatusPill(
            label: '$openCount open',
            color: _kOpen,
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.selected,
    required this.showFeatured,
    required this.onSelect,
  });

  final StoreFilter selected;
  final bool showFeatured;
  final ValueChanged<StoreFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget chip(String label, StoreFilter f) {
      final on = selected == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: on,
          showCheckmark: false,
          onSelected: (_) => onSelect(f),
          selectedColor: scheme.onSurface,
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: on ? scheme.surface : scheme.onSurface,
          ),
          side: BorderSide(
            color: on
                ? scheme.onSurface
                : scheme.outlineVariant.withValues(alpha: 0.8),
          ),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('All', StoreFilter.all),
          chip('Open now', StoreFilter.open),
          if (showFeatured) chip('Featured', StoreFilter.featured),
        ],
      ),
    );
  }
}

/// One shop, most of the screen: cover with the logo overlapping it, then the
/// facts a shopper decides on.
class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store, required this.onOpen});

  final StoreData store;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = store.storeStatus.isOpen
        ? awningPaletteFor(store.id, brightness: theme.brightness)
        : shutteredPalette(brightness: theme.brightness);
    final open = store.storeStatus.isOpen;
    final description = (store.description ?? '').trim();
    final address = (store.address ?? '').trim();
    final meta = joinMeta([store.category, store.municipality]);

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onOpen,
        // The card is as tall as the screen allows, so its parts scale with it:
        // the cover takes about a third, and on a short phone the description
        // gives way before anything overflows.
        child: LayoutBuilder(builder: (context, box) {
          final roomy = box.maxHeight >= 500;
          // Compact (short phones): a smaller cover, and the description and
          // address give way — both are on the store page one tap away.
          final coverHeight = roomy
              ? (box.maxHeight * 0.36).clamp(150.0, 210.0)
              : (box.maxHeight * 0.26).clamp(88.0, 130.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Cover + logo ──────────────────────────────────────────────
              SizedBox(
                height: coverHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    _Cover(store: store, stripe: palette.stripe, dim: !open),
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        children: [
                          if (store.isFeatured)
                            const _StatusPill(
                                label: 'FEATURED', color: _kGold, solid: true),
                          const Spacer(),
                          _StatusPill(
                            label: open ? 'OPEN' : 'CLOSED',
                            color: open ? _kOpen : const Color(0xFF6B7280),
                            solid: true,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 18,
                      bottom: -30,
                      child: _Logo(store: store, stripe: palette.stripe),
                    ),
                  ],
                ),
              ),
              // ── Facts ─────────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 38, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        maxLines: roomy ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 21,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _Stats(store: store),
                      if (roomy && description.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Flexible(
                          child: Text(
                            description,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: scheme.onSurface.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (roomy && address.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Icon(Icons.place_outlined,
                                  size: 16, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton(
                          onPressed: onOpen,
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.onSurface,
                            foregroundColor: scheme.surface,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                open ? 'Visit store' : 'Browse store',
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.store, required this.stripe, required this.dim});
  final StoreData store;
  final Color stripe;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final cover = (store.coverImage ?? '').trim();
    // No cover photo: the shop's own house colour, so every card still has a
    // distinct face instead of a grey box.
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [stripe, Color.lerp(stripe, Colors.black, 0.35)!],
        ),
      ),
      child: Center(
        child: Icon(Icons.storefront_rounded,
            size: 64, color: Colors.white.withValues(alpha: 0.25)),
      ),
    );
    final image = cover.isEmpty
        ? fallback
        : CachedNetworkImage(
            imageUrl: cover,
            fit: BoxFit.cover,
            placeholder: (_, __) => fallback,
            errorWidget: (_, __, ___) => fallback,
          );
    if (!dim) return image;
    // A closed shop keeps its face, desaturated, so it reads as "shutters down".
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.33, 0.59, 0.11, 0, 0, //
        0.33, 0.59, 0.11, 0, 0, //
        0.33, 0.59, 0.11, 0, 0, //
        0, 0, 0, 1, 0,
      ]),
      child: image,
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.store, required this.stripe});
  final StoreData store;
  final Color stripe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final logo = (store.logo ?? '').trim();
    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: logo.isEmpty
            ? ColoredBox(
                color: stripe,
                child: Center(
                  child: Text(
                    storeMonogram(store.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
            : CachedNetworkImage(
                imageUrl: logo,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => ColoredBox(color: stripe),
              ),
      ),
    );
  }
}

/// Products · Rating · Hours, in one ruled row.
class _Stats extends StatelessWidget {
  const _Stats({required this.store});
  final StoreData store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rated = store.reviewCount > 0 && store.rating > 0;
    final open = store.storeStatus.isOpen;

    Widget cell(String value, String label,
            {Color? valueColor, IconData? icon}) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: valueColor),
                    const SizedBox(width: 3),
                  ],
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: valueColor ?? scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 11.5, color: scheme.onSurfaceVariant)),
            ],
          ),
        );
    Widget rule() => Container(
          width: 1,
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: scheme.outlineVariant,
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          cell('${store.productCount}', 'Products'),
          rule(),
          cell(
            rated ? store.rating.toStringAsFixed(1) : 'New',
            rated ? '${store.reviewCount} reviews' : 'No reviews yet',
            icon: rated ? Icons.star_rounded : null,
            valueColor: rated ? const Color(0xFFD97706) : null,
          ),
          rule(),
          cell(
            open ? 'Open' : 'Closed',
            // 'Opens Sat · 8:00 AM', or 'For now' when no reopening is known.
            open
                ? 'Right now'
                : (storeHoursLabel(store) == 'Closed'
                    ? 'For now'
                    : storeHoursLabel(store)),
            valueColor: open ? _kOpen : scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    this.solid = false,
  });

  final String label;
  final Color color;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!solid) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: solid ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dots + "3 / 12", so the shopper knows how far through the street they are.
class _Pager extends StatelessWidget {
  const _Pager({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Dots only while they fit; a long street shows just the counter.
    final showDots = count <= 12;
    return Column(
      children: [
        if (showDots)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == current ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: scheme.onSurface
                        .withValues(alpha: i == current ? 0.85 : 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        if (showDots) const SizedBox(height: 8),
        Text(
          '${current + 1} / $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Keeps an empty/error state pull-to-refreshable by filling the viewport.
class _FullHeight extends StatelessWidget {
  final Widget child;

  const _FullHeight({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 32, color: scheme.onSurface.withValues(alpha: 0.35)),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 20),
            action!,
          ],
        ],
      ),
    );
  }
}
