// lib/features/search/presentation/search_page.dart
// One search for the whole market — products, stores and ads — opened from the
// Shop, Trenda and Food docks (and the barcode scanner).
//
// The page is a market directory: the scope (Everything / Official / Food) sets
// the accent the way a market hall's signs change colour by section, and every
// group of results hangs under its own signboard with a count. Product and store
// results use the SAME cards as the Shop tab (ShopProductCard, ShopStoreCard),
// so a thing looks the same wherever the shopper meets it.
//
// Data: search_everything_provider.dart → GET /api/search/everything.
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:trenda_shared/models/ad_model.dart';
import 'package:trenda_shared/models/ad_placement.dart' show kAdListingImageAspect;
import 'package:trenda_shared/models/product_model.dart';
import 'package:trenda_shared/widgets/official_ad_detail_screen.dart';
import 'package:trenda_shared/widgets/official_ad_slot.dart' show OfficialAdItem;

import '../../core/providers/municipality_provider.dart';
import '../../core/router/app_router.dart';
import '../../home/presentation/widgets/shop_card_grid.dart';
import '../../home/presentation/widgets/shop_product_card.dart';
import '../../home/presentation/widgets/shop_store_card.dart';
import '../../home/presentation/widgets/shop_stores_row.dart' show kShopStoresRowCardWidth;
import '../../home/providers/stores_provider.dart' show StoreData;
import '../providers/search_everything_provider.dart';
import '../providers/search_provider.dart';
import 'barcode_scanner_page.dart';
import 'visual_search_sheet.dart';

const _kGold = Color(0xFFB8860B);
const _kChili = Color(0xFFD9480F);
const _kDebounce = Duration(milliseconds: 300);

/// The colour a scope paints the page in.
Color scopeAccent(SearchScope scope, ColorScheme scheme) => switch (scope) {
      SearchScope.all => scheme.primary,
      SearchScope.official => _kGold,
      SearchScope.food => _kChili,
    };

IconData _scopeIcon(SearchScope s) => switch (s) {
      SearchScope.all => Icons.storefront_rounded,
      SearchScope.official => Icons.verified_rounded,
      SearchScope.food => Icons.ramen_dining_rounded,
    };

/// Starting points before anything is typed: a tap searches the word.
const _kMarketAisles = <(String, IconData)>[
  ('Restaurant Food', Icons.restaurant_rounded),
  ('Fresh Produce', Icons.eco_rounded),
  ('Meat & Seafood', Icons.set_meal_rounded),
  ('Electronics', Icons.headphones_rounded),
  ('Fashion', Icons.checkroom_rounded),
  ('Home & Garden', Icons.chair_rounded),
  ('Beauty', Icons.spa_rounded),
  ('Coffee', Icons.coffee_rounded),
];
const _kFoodAisles = <(String, IconData)>[
  ('Chicken', Icons.kebab_dining_rounded),
  ('Pizza', Icons.local_pizza_rounded),
  ('Burger', Icons.lunch_dining_rounded),
  ('Coffee', Icons.coffee_rounded),
  ('Milk tea', Icons.local_cafe_rounded),
  ('Noodles', Icons.ramen_dining_rounded),
  ('Rice meal', Icons.rice_bowl_rounded),
  ('Dessert', Icons.icecream_rounded),
];

enum _Tab { all, products, stores, ads }

class SearchPage extends ConsumerStatefulWidget {
  final SearchScope initialScope;
  final String initialQuery;

  const SearchPage({super.key, this.initialScope = SearchScope.all, this.initialQuery = ''});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _field = TextEditingController(text: widget.initialQuery);
  final FocusNode _focus = FocusNode();
  late final ValueNotifier<SearchScope> _scope = ValueNotifier(widget.initialScope);
  late final ValueNotifier<String> _query = ValueNotifier(widget.initialQuery.trim());
  final ValueNotifier<_Tab> _tab = ValueNotifier(_Tab.all);
  final ValueNotifier<SearchProductSort> _sort = ValueNotifier(SearchProductSort.relevance);
  final ValueNotifier<bool> _listening = ValueNotifier(false);
  final stt.SpeechToText _speech = stt.SpeechToText();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _speech.cancel();
    _field.dispose();
    _focus.dispose();
    for (final n in [_scope, _query, _tab, _sort, _listening]) {
      n.dispose();
    }
    super.dispose();
  }

  void _onTyped(String text) {
    _debounce?.cancel();
    _debounce = Timer(_kDebounce, () => _commit(text, remember: false));
  }

  /// Runs [text] now. Submitted / tapped searches are remembered; keystrokes are not.
  void _commit(String text, {bool remember = true}) {
    _debounce?.cancel();
    final q = text.trim();
    if (_field.text != text) {
      _field.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    }
    if (q != _query.value) _tab.value = _Tab.all;
    _query.value = q;
    if (remember && q.length >= kSearchMinChars) ref.read(searchHistoryProvider.notifier).addSearch(q);
  }

  Future<void> _voice() async {
    if (_listening.value) {
      await _speech.stop();
      _listening.value = false;
      return;
    }
    final ok = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') _listening.value = false;
      },
      onError: (_) => _listening.value = false,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice search is not available on this phone')),
      );
      return;
    }
    _listening.value = true;
    await _speech.listen(
      onResult: (r) {
        _field.text = r.recognizedWords;
        if (r.finalResult) {
          _listening.value = false;
          _commit(r.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ValueListenableBuilder<SearchScope>(
      valueListenable: _scope,
      builder: (context, scope, _) {
        final accent = scopeAccent(scope, theme.colorScheme);
        return Scaffold(
          backgroundColor: dark ? const Color(0xFF0E1116) : const Color(0xFFF4F6F8),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _SearchHeader(
                  controller: _field,
                  focus: _focus,
                  accent: accent,
                  scope: scope,
                  listening: _listening,
                  onChanged: _onTyped,
                  onSubmitted: (t) => _commit(t),
                  onClear: () => _commit(''),
                  onVoice: _voice,
                  onScan: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const BarcodeScannerPage())),
                ),
                _ScopeBar(
                  scope: scope,
                  onChanged: (s) {
                    _scope.value = s;
                    _tab.value = _Tab.all;
                  },
                ),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _query,
                    builder: (context, q, _) {
                      final municipality = ref.watch(municipalityProvider);
                      final req = SearchRequest(q, scope, municipality);
                      if (!req.isSearchable) {
                        return _Landing(
                          scope: scope,
                          accent: accent,
                          onPick: _commit,
                        );
                      }
                      return _Results(
                        request: req,
                        accent: accent,
                        tab: _tab,
                        sort: _sort,
                        onWiden: () => _scope.value = SearchScope.all,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────── header ───────────────────────────────

class _SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final Color accent;
  final SearchScope scope;
  final ValueNotifier<bool> listening;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onVoice;
  final VoidCallback onScan;

  const _SearchHeader({
    required this.controller,
    required this.focus,
    required this.accent,
    required this.scope,
    required this.listening,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onVoice,
    required this.onScan,
  });

  String get _hint => switch (scope) {
        SearchScope.all => 'Search products, stores and ads',
        SearchScope.official => 'Search Official Trenda',
        SearchScope.food => 'Search food and restaurants',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: dark ? 0.08 : 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.onSurface.withValues(alpha: dark ? 0.12 : 0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('search-field'),
                      controller: controller,
                      focusNode: focus,
                      textInputAction: TextInputAction.search,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      cursorColor: accent,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintText: _hint,
                        hintStyle: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.45),
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (_, v, __) => v.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            tooltip: 'Clear',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                            onPressed: onClear,
                          ),
                  ),
                  IconButton(
                    tooltip: 'Search by photo',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.camera_alt_rounded,
                      size: 19,
                      color: scheme.onSurface.withValues(alpha: 0.45),
                    ),
                    onPressed: () => VisualSearchSheet.show(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SquareIconButton(
            tooltip: 'Scan a barcode',
            icon: Icons.qr_code_scanner_rounded,
            color: accent,
            onTap: onScan,
          ),
        ],
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SquareIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      width: 44,
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, size: 21),
        style: IconButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.11),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.22)),
          ),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _ScopeBar extends StatelessWidget {
  final SearchScope scope;
  final ValueChanged<SearchScope> onChanged;
  const _ScopeBar({required this.scope, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
        children: [
          for (final s in SearchScope.values) ...[
            _ScopeChip(
              key: ValueKey('scope-${s.param}'),
              label: s.label,
              icon: _scopeIcon(s),
              color: scopeAccent(s, scheme),
              selected: s == scope,
              onTap: () => onChanged(s),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ScopeChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: selected ? 1 : 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: selected ? Colors.white : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── landing ───────────────────────────────

class _Landing extends ConsumerWidget {
  final SearchScope scope;
  final Color accent;
  final ValueChanged<String> onPick;
  const _Landing({required this.scope, required this.accent, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    final scheme = Theme.of(context).colorScheme;
    final aisles = scope == SearchScope.food ? _kFoodAisles : _kMarketAisles;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (history.isNotEmpty) ...[
          _Signboard(
            title: 'Recent',
            accent: accent,
            trailing: TextButton(
              onPressed: () => ref.read(searchHistoryProvider.notifier).clearHistory(),
              child: const Text('Clear'),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in history.take(10))
                InputChip(
                  label: Text(h),
                  avatar: Icon(Icons.history_rounded, size: 16, color: scheme.onSurface.withValues(alpha: 0.5)),
                  onPressed: () => onPick(h),
                  onDeleted: () => ref.read(searchHistoryProvider.notifier).removeSearch(h),
                  deleteIconColor: scheme.onSurface.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        _Signboard(
          title: scope == SearchScope.food ? 'Hungry for…' : 'Browse the market',
          accent: accent,
        ),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.82,
          children: [
            for (var i = 0; i < aisles.length; i++)
              _Reveal(
                index: i,
                child: _AisleTile(
                  label: aisles[i].$1,
                  icon: aisles[i].$2,
                  accent: accent,
                  onTap: () => onPick(aisles[i].$1),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.tips_and_updates_outlined, size: 16, color: scheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Search finds products, stores and ads in your city. Type at least $kSearchMinChars letters.',
                style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.55)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AisleTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  const _AisleTile({required this.label, required this.icon, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF1A1F27) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), shape: BoxShape.circle),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, height: 1.15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── results ───────────────────────────────

class _Results extends ConsumerWidget {
  final SearchRequest request;
  final Color accent;
  final ValueNotifier<_Tab> tab;
  final ValueNotifier<SearchProductSort> sort;
  final VoidCallback onWiden;

  const _Results({
    required this.request,
    required this.accent,
    required this.tab,
    required this.sort,
    required this.onWiden,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(searchEverythingProvider(request));
    return async.when(
      loading: () => _LoadingShelves(accent: accent),
      error: (e, _) => _Message(
        icon: Icons.wifi_off_rounded,
        accent: accent,
        title: "Couldn't search right now",
        body: 'Check your connection and try again.',
        action: ('Try again', () => ref.invalidate(searchEverythingProvider(request))),
      ),
      data: (r) {
        if (r.isEmpty) {
          final narrowed = request.scope != SearchScope.all;
          return _Message(
            icon: Icons.search_off_rounded,
            accent: accent,
            title: 'Nothing for “${request.query.trim()}”',
            body: narrowed
                ? 'Nothing in ${request.scope.label} matches. Try the whole market.'
                : 'Check the spelling, or try a shorter or more general word.',
            action: narrowed ? ('Search everything', onWiden) : null,
          );
        }
        return ValueListenableBuilder<_Tab>(
          valueListenable: tab,
          builder: (context, current, _) => Column(
            children: [
              _TabRail(result: r, current: current, accent: accent, onTap: (t) => tab.value = t),
              Expanded(
                child: switch (current) {
                  _Tab.all => _AllView(result: r, request: request, accent: accent, onSeeAll: (t) => tab.value = t),
                  _Tab.products => _ProductsView(result: r, accent: accent, sort: sort),
                  _Tab.stores => _StoresView(stores: r.stores),
                  _Tab.ads => _AdsView(result: r, accent: accent),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabRail extends StatelessWidget {
  final SearchEverythingResult result;
  final _Tab current;
  final Color accent;
  final ValueChanged<_Tab> onTap;
  const _TabRail({required this.result, required this.current, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tabs = <(_Tab, String, int)>[
      (_Tab.all, 'All', result.total),
      (_Tab.products, 'Products', result.productTotal),
      (_Tab.stores, 'Stores', result.storeTotal),
      (_Tab.ads, 'Ads', result.adTotal),
    ];
    return Container(
      height: 42,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final (t, label, count) in tabs)
            InkWell(
              key: ValueKey('search-tab-${t.name}'),
              onTap: count == 0 && t != _Tab.all ? null : () => onTap(t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: t == current ? accent : Colors.transparent, width: 2.5),
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: t == current ? FontWeight.w800 : FontWeight.w600,
                        color: count == 0 && t != _Tab.all
                            ? scheme.onSurface.withValues(alpha: 0.35)
                            : (t == current ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.7)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _Tally(count: count, accent: t == current ? accent : scheme.outline),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  final int count;
  final Color accent;
  const _Tally({required this.count, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count > 999 ? '999+' : '$count',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accent),
      ),
    );
  }
}

/// All results on one page: stores first (a store is a destination), then the
/// products, then the ads. Each group shows a taste and a "See all".
class _AllView extends StatelessWidget {
  static const _productPreview = 8;
  final SearchEverythingResult result;
  final SearchRequest request;
  final Color accent;
  final ValueChanged<_Tab> onSeeAll;
  const _AllView({required this.result, required this.request, required this.accent, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final products = result.products.take(_productPreview).toList();
    var reveal = 0;
    return CustomScrollView(
      key: const ValueKey('search-all'),
      slivers: [
        if (request.scope == SearchScope.official)
          SliverToBoxAdapter(child: _Reveal(index: reveal++, child: const _OfficialStoreTile())),
        if (result.stores.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _Reveal(
              index: reveal++,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                child: _Signboard(
                  title: 'Stores',
                  count: result.storeTotal,
                  accent: accent,
                  onSeeAll: result.storeTotal > result.stores.take(10).length ? () => onSeeAll(_Tab.stores) : null,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: kShopStoresRowCardWidth + kShopStoreCardDetailsHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: result.stores.length.clamp(0, 10),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => ShopStoreCard(
                  store: result.stores[i],
                  width: kShopStoresRowCardWidth,
                  onTap: () => _openStore(context, result.stores[i]),
                ),
              ),
            ),
          ),
        ],
        if (products.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _Reveal(
              index: reveal++,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 8, 0),
                child: _Signboard(
                  title: 'Products',
                  count: result.productTotal,
                  accent: accent,
                  onSeeAll: result.productTotal > products.length ? () => onSeeAll(_Tab.products) : null,
                ),
              ),
            ),
          ),
          _productGrid(products),
        ],
        if (result.adCount > 0) ...[
          SliverToBoxAdapter(
            child: _Reveal(
              index: reveal++,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 8, 0),
                child: _Signboard(
                  title: 'Ads',
                  count: result.adTotal,
                  accent: accent,
                  onSeeAll: () => onSeeAll(_Tab.ads),
                ),
              ),
            ),
          ),
          if (result.listingAds.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: _ListingAdCard.width / kAdListingImageAspect + 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: result.listingAds.length.clamp(0, 10),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => _ListingAdCard(ad: result.listingAds[i], accent: accent),
                ),
              ),
            ),
          for (final ad in result.officialAds.take(3))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _OfficialAdBanner(ad: ad),
              ),
            ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

Widget _productGrid(List<ProductModel> products) => SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      sliver: SliverGrid(
        gridDelegate: const ShopCardGridDelegate(),
        delegate: SliverChildBuilderDelegate(
          (context, i) => ShopProductCard(
            product: products[i],
            onTap: () => context.push('/product/${products[i].id}'),
          ),
          childCount: products.length,
        ),
      ),
    );

void _openStore(BuildContext context, StoreData s) => context.push('/store/${s.id}');

class _ProductsView extends StatelessWidget {
  final SearchEverythingResult result;
  final Color accent;
  final ValueNotifier<SearchProductSort> sort;
  const _ProductsView({required this.result, required this.accent, required this.sort});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SearchProductSort>(
      valueListenable: sort,
      builder: (context, current, _) {
        final products = sortSearchProducts(result.products, current);
        return CustomScrollView(
          key: const ValueKey('search-products'),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  children: [
                    for (final s in SearchProductSort.values) ...[
                      ChoiceChip(
                        label: Text(s.label),
                        selected: s == current,
                        selectedColor: accent.withValues(alpha: 0.18),
                        side: BorderSide(color: accent.withValues(alpha: s == current ? 0.8 : 0.25)),
                        onSelected: (_) => sort.value = s,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            if (result.productTotal > products.length)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                  child: Text(
                    'Showing the best ${products.length} of ${result.productTotal}. Add a word to narrow it down.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
                  ),
                ),
              ),
            _productGrid(products),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
    );
  }
}

class _StoresView extends StatelessWidget {
  final List<StoreData> stores;
  const _StoresView({required this.stores});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const ValueKey('search-stores'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          sliver: SliverGrid(
            gridDelegate: const ShopCardGridDelegate(detailsHeight: kShopStoreCardDetailsHeight),
            delegate: SliverChildBuilderDelegate(
              (context, i) => ShopStoreCard(store: stores[i], onTap: () => _openStore(context, stores[i])),
              childCount: stores.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _AdsView extends StatelessWidget {
  final SearchEverythingResult result;
  final Color accent;
  const _AdsView({required this.result, required this.accent});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const ValueKey('search-ads'),
      slivers: [
        for (final ad in result.officialAds)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _OfficialAdBanner(ad: ad),
            ),
          ),
        if (result.listingAds.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                // A 6:5 photo over two lines of text.
                childAspectRatio: kAdListingImageAspect * 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _ListingAdCard(ad: result.listingAds[i], accent: accent, width: null),
                childCount: result.listingAds.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────── pieces ───────────────────────────────

/// A section's signboard: an accent post, the title and a tally.
class _Signboard extends StatelessWidget {
  final String title;
  final int? count;
  final Color accent;
  final VoidCallback? onSeeAll;
  final Widget? trailing;
  const _Signboard({required this.title, required this.accent, this.count, this.onSeeAll, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
          if (count != null) ...[const SizedBox(width: 8), _Tally(count: count!, accent: accent)],
          const Spacer(),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(foregroundColor: accent),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('See all'), Icon(Icons.chevron_right_rounded, size: 18)],
              ),
            ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _OfficialStoreTile extends StatelessWidget {
  const _OfficialStoreTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF8A6508), _kGold, Color(0xFFE0B54A)]),
          ),
          child: InkWell(
            onTap: () => context.push('/official-store'),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Official Trenda Store',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                  Text('Visit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListingAdCard extends StatelessWidget {
  static const double width = 200;
  final AdModel ad;
  final Color accent;
  final double? cardWidth;
  const _ListingAdCard({required this.ad, required this.accent, double? width = _ListingAdCard.width})
      : cardWidth = width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final image = ad.photos.isNotEmpty ? ad.photos.first : '';
    final service = ad.kind == 'service';
    return SizedBox(
      width: cardWidth,
      child: Material(
        color: dark ? const Color(0xFF1A1F27) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Routes.adDetails, extra: ad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: kAdListingImageAspect,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image.isEmpty
                        ? ColoredBox(color: accent.withValues(alpha: 0.1), child: Icon(Icons.campaign_rounded, color: accent))
                        : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          service ? 'SERVICE' : 'AD',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(ad.businessName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficialAdBanner extends StatelessWidget {
  final OfficialAdItem ad;
  const _OfficialAdBanner({required this.ad});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OfficialAdDetailScreen(ad: ad))),
        child: AspectRatio(
          aspectRatio: 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ad.image.isEmpty
                  ? const ColoredBox(color: _kGold)
                  : CachedNetworkImage(imageUrl: ad.image, fit: BoxFit.cover),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: _kGold, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    ad.badgeText.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final (String, VoidCallback)? action;
  const _Message({required this.icon, required this.accent, required this.title, required this.body, this.action});

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
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: accent),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6))),
            if (action != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: accent),
                onPressed: action!.$2,
                child: Text(action!.$1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Placeholder shelves while results load — the shape of what is coming, not a spinner.
class _LoadingShelves extends StatelessWidget {
  final Color accent;
  const _LoadingShelves({required this.accent});

  @override
  Widget build(BuildContext context) {
    final block = accent.withValues(alpha: 0.08);
    Widget box(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: block, borderRadius: BorderRadius.circular(10)),
        );
    return ListView(
      key: const ValueKey('search-loading'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        box(120, 18),
        const SizedBox(height: 12),
        Row(children: [box(140, 190), const SizedBox(width: 10), box(140, 190)]),
        const SizedBox(height: 20),
        box(120, 18),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: box(0, 220)), const SizedBox(width: 10), Expanded(child: box(0, 220))]),
      ],
    );
  }
}

/// A short fade-and-rise as a section arrives, staggered by [index].
class _Reveal extends StatelessWidget {
  final int index;
  final Widget child;
  const _Reveal({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.08).clamp(0.0, 0.5);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: c),
      ),
    );
  }
}
