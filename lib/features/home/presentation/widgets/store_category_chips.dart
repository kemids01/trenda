// Stores page ▸ category chips: "All · <groups> · Official Trenda Store", then — once a group is
// picked — that group's subcategories. The tree is admin-managed (trenda_admin nav 131); only
// ACTIVE categories arrive. Filtering is client-side: the page already holds the city's whole
// deck. The match rule is the shared `storeMatchesCategory` (mirrors the backend).
//
// "Official Trenda Store" is not a tree entry — Trenda's own store has its own page, so that chip
// navigates to /official-store instead of filtering.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_shared/core/config.dart';
import 'package:trenda_shared/models/store_category.dart';

import '../../providers/stores_provider.dart';

const Color _kGold = Color(0xFFC79A3C); // the Official store's accent, as on the store card

/// The active tree. Fails SOFT to an empty list: no chips is better than a broken Stores page.
final storeCategoryTreeProvider = FutureProvider<List<StoreCategoryNode>>((ref) async {
  try {
    return await fetchStoreCategoryTree(AppConfig.backendBaseUrl);
  } catch (_) {
    return const [];
  }
});

/// The selected category filter. Empty = All.
class StoreCategoryFilter {
  final String? group;
  final String? sub;
  const StoreCategoryFilter({this.group, this.sub});

  bool get isAll => group == null && sub == null;
}

final storeCategoryFilterProvider =
    StateProvider.autoDispose<StoreCategoryFilter>((_) => const StoreCategoryFilter());

/// The stores the filter keeps, in their original order.
List<StoreData> filterStoresByCategory(List<StoreData> stores, StoreCategoryFilter f) => f.isAll
    ? stores
    : stores.where((s) => storeMatchesCategory(s.storeCategory, group: f.group, sub: f.sub)).toList();

class StoreCategoryChips extends ConsumerWidget {
  /// Called after the filter changes, so the page can return to its first card.
  final VoidCallback onChanged;
  const StoreCategoryChips({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(storeCategoryTreeProvider).valueOrNull ?? const [];
    if (groups.isEmpty) return const SizedBox.shrink();
    final f = ref.watch(storeCategoryFilterProvider);
    final selected = groups.where((g) => g.key == f.group).firstOrNull;

    void set(StoreCategoryFilter next) {
      ref.read(storeCategoryFilterProvider.notifier).state = next;
      onChanged();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Row(children: [
          _Chip(label: 'All categories', on: f.isAll, onTap: () => set(const StoreCategoryFilter())),
          for (final g in groups)
            _Chip(
              label: g.name,
              on: f.group == g.key,
              // Tapping the selected group again goes back to All.
              onTap: () => set(f.group == g.key
                  ? const StoreCategoryFilter()
                  : StoreCategoryFilter(group: g.key)),
            ),
          _Chip(
            label: 'Official Trenda Store',
            icon: Icons.verified_rounded,
            accent: _kGold,
            on: false,
            onTap: () => context.push('/official-store'),
          ),
        ]),
        if (selected != null && selected.subcategories.isNotEmpty)
          _Row(dense: true, children: [
            for (final s in selected.subcategories)
              _Chip(
                label: s.name,
                dense: true,
                on: f.sub == s.key,
                onTap: () => set(StoreCategoryFilter(
                    group: selected.key, sub: f.sub == s.key ? null : s.key)),
              ),
          ]),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final List<Widget> children;
  final bool dense;
  const _Row({required this.children, this.dense = false});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: dense ? 34 : 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: children,
        ),
      );
}

/// Same look as the page's Open/Featured chips (inverted when on); an [accent] tints the
/// Official chip gold; [dense] chips (subcategories) are lighter and smaller.
class _Chip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? accent;
  final bool dense;

  const _Chip({
    required this.label,
    required this.on,
    required this.onTap,
    this.icon,
    this.accent,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = accent ?? scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: 16, color: on ? scheme.surface : ink),
        label: Text(label),
        selected: on,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: dense ? scheme.onSurface.withValues(alpha: 0.85) : ink,
        backgroundColor: accent?.withValues(alpha: 0.10),
        labelStyle: TextStyle(
          fontSize: dense ? 11.5 : 12.5,
          fontWeight: dense ? FontWeight.w500 : FontWeight.w600,
          color: on ? scheme.surface : ink,
        ),
        side: BorderSide(
          color: on ? ink : (accent ?? scheme.outlineVariant).withValues(alpha: 0.8),
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
