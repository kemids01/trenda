// lib/features/home/providers/official_favorites_provider.dart
// Local (SharedPreferences) wishlist for Official Trenda Store products — lets a customer
// bookmark official items. Persists across launches. Mirrors the vendor app's favorites.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfficialFavoritesNotifier extends StateNotifier<Set<String>> {
  OfficialFavoritesNotifier() : super(const {}) {
    _load();
  }

  static const _key = 'official_store_favorites';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = (prefs.getStringList(_key) ?? const <String>[]).toSet();
    } catch (_) {
      // Best-effort — favorites are non-critical.
    }
  }

  bool isFavorite(String id) => state.contains(id);

  Future<void> toggle(String id) async {
    if (id.isEmpty) return;
    final next = {...state};
    if (!next.add(id)) next.remove(id); // add returns false if already present
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, next.toList());
    } catch (_) {}
  }
}

final officialFavoritesProvider =
    StateNotifierProvider<OfficialFavoritesNotifier, Set<String>>(
        (ref) => OfficialFavoritesNotifier());
