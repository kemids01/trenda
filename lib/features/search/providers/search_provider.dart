// lib/features/search/providers/search_provider.dart
// Recent searches, kept on the phone (SharedPreferences). The search itself is
// search_everything_provider.dart (GET /api/search/everything).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trenda_shared/core/logger.dart';

/// ============================================================================
final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>(
  (ref) => SearchHistoryNotifier(),
);

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  static const String _storageKey = 'search_history';
  static const int _maxHistoryItems = 20;

  SearchHistoryNotifier() : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_storageKey) ?? [];
      state = historyJson;
    } catch (e) {
      AppLogger.error('Error loading search history', e);
    }
  }

  Future<void> addSearch(String query) async {
    if (query.trim().isEmpty) return;

    final trimmedQuery = query.trim();
    final updatedHistory = [
      trimmedQuery,
      ...state.where((q) => q != trimmedQuery),
    ].take(_maxHistoryItems).toList();

    state = updatedHistory;
    await _saveHistory();
  }

  Future<void> removeSearch(String query) async {
    state = state.where((q) => q != query).toList();
    await _saveHistory();
  }

  Future<void> clearHistory() async {
    state = [];
    await _saveHistory();
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, state);
    } catch (e) {
      AppLogger.error('Error saving search history', e);
    }
  }
}
