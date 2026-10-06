// lib/features/home/presentation/official_store_page.dart
// Dedicated Official Trenda Store landing page (route /official-store). Full
// municipality-scoped catalog with search + data-derived category chips + sort,
// reusing the shared OfficialProductCard + filter helpers. Linked from the Hub banner.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/trenda_shared.dart';
import '../providers/official_store_provider.dart';
import '../providers/official_favorites_provider.dart';
import '../utils/official_store_filters.dart';
import '../../core/widgets/frontend_official_ad_slot.dart';
import 'widgets/official_product_card.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldDark = Color(0xFFB8860B);

class OfficialStorePage extends ConsumerStatefulWidget {
  const OfficialStorePage({super.key});

  @override
  ConsumerState<OfficialStorePage> createState() => _OfficialStorePageState();
}

class _OfficialStorePageState extends ConsumerState<OfficialStorePage> {
  String _search = '';
  String _selectedCategory = 'All';
  String _sort = 'newest';
  bool _onSale = false;
  bool _freeDelivery = false;
  bool _savedOnly = false;

  Widget _filterChip(String label, bool selected, ValueChanged<bool> onSel) => FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSel,
        selectedColor: _kGold,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : Colors.grey.shade700,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(officialStoreProductsProvider);
    final all = async.maybeWhen(
        data: (l) => l, orElse: () => const <ProductModel>[]);
    final categories = officialCategories(all);
    final effectiveCategory =
        categories.contains(_selectedCategory) ? _selectedCategory : 'All';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: _kGoldDark,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, size: 20),
            SizedBox(width: 8),
            Text('Official Trenda Store'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search official products...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kGoldDark),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = categories[i];
                final sel = effectiveCategory == c;
                return FilterChip(
                  label: Text(c),
                  selected: sel,
                  onSelected: (_) => setState(() => _selectedCategory = c),
                  selectedColor: _kGold,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: sel ? Colors.white : Colors.grey.shade700,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              _filterChip('On sale', _onSale, (v) => setState(() => _onSale = v)),
              const SizedBox(width: 8),
              _filterChip('Free delivery', _freeDelivery, (v) => setState(() => _freeDelivery = v)),
              const SizedBox(width: 8),
              _filterChip('Saved', _savedOnly, (v) => setState(() => _savedOnly = v)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
            child: Row(
              children: [
                const Icon(Icons.sort, size: 18, color: _kGoldDark),
                const SizedBox(width: 6),
                const Text('Sort:',
                    style: TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _sort,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  items: [
                    for (final k in kOfficialSortKeys)
                      DropdownMenuItem(
                          value: k, child: Text(officialSortLabel(k))),
                  ],
                  onChanged: (v) => setState(() => _sort = v ?? 'newest'),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 44, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      const Text('Could not load official products'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () =>
                            ref.invalidate(officialStoreProductsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (products) {
                final list = applyOfficialFilters(products,
                    category: effectiveCategory,
                    query: _search,
                    sort: _sort,
                    onSaleOnly: _onSale,
                    freeDeliveryOnly: _freeDelivery,
                    savedOnly: _savedOnly,
                    savedIds: ref.watch(officialFavoritesProvider));
                if (list.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No matching official products'),
                    ),
                  );
                }
                // Slivers, not a GridView: the ad below the grid has to scroll
                // with the products. The filter bar above stays put because it
                // lives outside this scroll view.
                return CustomScrollView(
                  slivers: [
                    // Official Trenda ads — above the grid. Unsold → nothing.
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(0, 8, 0, 2),
                        child: FrontendOfficialAdSlot(
                          slotId: 'frontend.official_store.top',
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(12),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.57,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => OfficialProductCard(product: list[i]),
                          childCount: list.length,
                        ),
                      ),
                    ),
                    // Official Trenda ads — below the grid.
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(0, 4, 0, 8),
                        child: FrontendOfficialAdSlot(
                          slotId: 'frontend.official_store.bottom',
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
