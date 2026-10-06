// lib/features/stores/utils/store_carousel.dart
// Pure rules for the Stores page carousel: one ordered deck built from the
// server's featured / open / closed buckets, the filter chips, and the hours
// line each card shows. Widget-free so the order is unit-testable.
import '../../home/providers/stores_provider.dart';
import 'storefront_style.dart' show formatReopening;

/// The chips above the carousel.
enum StoreFilter { all, open, featured }

/// Featured first (the flagship shops paid for the front), then open, then
/// closed. A store appearing in two buckets is shown once, in its first.
List<StoreData> carouselDeck({
  List<StoreData> featured = const [],
  List<StoreData> open = const [],
  List<StoreData> closed = const [],
}) {
  final seen = <String>{};
  final out = <StoreData>[];
  for (final s in [...featured, ...open, ...closed]) {
    if (seen.add(s.id)) out.add(s);
  }
  return out;
}

/// "Open now" means the shop's own status, not the bucket it came in — a
/// featured shop can be closed.
List<StoreData> filterStores(List<StoreData> deck, StoreFilter filter) =>
    switch (filter) {
      StoreFilter.all => deck,
      StoreFilter.open => deck.where((s) => s.storeStatus.isOpen).toList(),
      StoreFilter.featured => deck.where((s) => s.isFeatured).toList(),
    };

/// The search box under the carousel: every word must appear in the shop's
/// name, category or address (case-insensitive). Blank keeps the whole deck.
List<StoreData> searchStores(List<StoreData> deck, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return deck;
  return deck.where((s) {
    final hay = '${s.name} ${s.category} ${s.address ?? ''}'.toLowerCase();
    return words.every(hay.contains);
  }).toList();
}

/// 'Open now' · 'Opens Sat · 8:00 AM' · 'Closed'.
String storeHoursLabel(StoreData s) {
  if (s.storeStatus.isOpen) return 'Open now';
  return formatReopening(
        day: s.storeStatus.nextOpenDay,
        time: s.storeStatus.nextOpenAt,
      ) ??
      'Closed';
}
