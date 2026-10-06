// lib/models/store_category.dart
// The admin-managed store-category tree, as the apps see it.
//
// Server rules: trenda_backend/utils/storeCategories.js. [storeMatchesCategory] MIRRORS the
// backend's function of the same name — change both or neither.
//
// Tree: GROUPS (e.g. "Food & Beverage") each holding SUBCATEGORIES ("Cafes"). A store has ONE
// primary group plus 0–10 secondary subcategories from any group. Keys are stable ids
// (`food-beverage`, `food-beverage.cafes`); names are what people read.
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Most secondary categories a store may carry (server enforces the same number).
const int kMaxStoreSubcategories = 10;

/// A group or a subcategory. A group carries its [subcategories]; a subcategory carries none.
class StoreCategoryNode {
  final String key;
  final String name;
  final List<StoreCategoryNode> subcategories;

  const StoreCategoryNode({
    required this.key,
    required this.name,
    this.subcategories = const [],
  });

  factory StoreCategoryNode.fromJson(Map<String, dynamic> json) => StoreCategoryNode(
        key: (json['key'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        subcategories: parseStoreCategoryTree(json['subcategories']),
      );
}

/// The `GET /api/store-categories` payload (`data`) as nodes. Anything malformed is skipped, and a
/// non-list yields an empty tree — a broken payload must never crash a screen.
List<StoreCategoryNode> parseStoreCategoryTree(Object? data) {
  if (data is! List) return const [];
  return [
    for (final item in data)
      if (item is Map)
        StoreCategoryNode.fromJson(Map<String, dynamic>.from(item)),
  ].where((n) => n.key.isNotEmpty).toList();
}

/// The group key of a subcategory key (`food-beverage.cafes` → `food-beverage`).
String storeCategoryGroupOf(String key) => key.split('.').first;

/// A store's category. [subcategories] are KEYS; [subcategoryNames] holds their names when the
/// server sent them (store cards do; an application does not).
class StoreCategoryPick {
  final String group;
  final String? groupName;
  final List<String> subcategories;
  final Map<String, String> subcategoryNames;

  const StoreCategoryPick({
    required this.group,
    this.groupName,
    this.subcategories = const [],
    this.subcategoryNames = const {},
  });

  /// Accepts both shapes the server uses: subcategories as bare keys (an application) or as
  /// `{key, name}` (a store card). Returns null when there is no group.
  static StoreCategoryPick? fromJson(Object? json) {
    if (json is! Map) return null;
    final group = (json['group'] ?? '').toString();
    if (group.isEmpty) return null;
    final keys = <String>[];
    final names = <String, String>{};
    final raw = json['subcategories'];
    if (raw is List) {
      for (final s in raw) {
        if (s is Map) {
          final k = (s['key'] ?? '').toString();
          if (k.isEmpty) continue;
          keys.add(k);
          final n = s['name']?.toString();
          if (n != null && n.isNotEmpty) names[k] = n;
        } else if (s != null && s.toString().isNotEmpty) {
          keys.add(s.toString());
        }
      }
    }
    final groupName = json['groupName']?.toString();
    return StoreCategoryPick(
      group: group,
      groupName: (groupName == null || groupName.isEmpty) ? null : groupName,
      subcategories: keys,
      subcategoryNames: names,
    );
  }

  /// What the server takes: keys only.
  Map<String, dynamic> toJson() => {'group': group, 'subcategories': subcategories};
}

/// Does a store belong under this filter? A [group] matches the store's primary group OR any of
/// its secondaries in that group; a [sub] matches when it is among the secondaries. No filter
/// matches everything, uncategorized stores included.
bool storeMatchesCategory(StoreCategoryPick? store, {String? group, String? sub}) {
  if ((group == null || group.isEmpty) && (sub == null || sub.isEmpty)) return true;
  if (store == null || store.group.isEmpty) return false;
  if (sub != null && sub.isNotEmpty) return store.subcategories.contains(sub);
  return store.group == group ||
      store.subcategories.any((k) => storeCategoryGroupOf(k) == group);
}

/// The active tree from the server. Throws on a failed request; callers decide how to fail.
Future<List<StoreCategoryNode>> fetchStoreCategoryTree(String baseUrl, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final res = await c
        .get(Uri.parse('$baseUrl/api/store-categories'), headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw Exception('Could not load store categories (HTTP ${res.statusCode})');
    }
    final body = jsonDecode(res.body);
    return parseStoreCategoryTree(body is Map ? body['data'] : null);
  } finally {
    if (client == null) c.close();
  }
}
