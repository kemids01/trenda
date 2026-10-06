import '../../cart/models/cart_model.dart';

class StoreGroup {
  final String storeName;
  final List<CartItem> items;
  const StoreGroup(this.storeName, this.items);

  /// The shop's id — seeds its house colour so a group is recognisably the
  /// same shop the customer saw on the street. Empty when the items carry none.
  String get vendorId =>
      items.firstWhere((i) => i.vendorId.isNotEmpty,
          orElse: () => items.first).vendorId;

  /// What this shop's items come to on their own. Each shop is a separate
  /// pickup, so its total is worth showing per group.
  double get subtotal =>
      items.fold<double>(0, (sum, i) => sum + i.subtotal);

  int get itemCount => items.fold<int>(0, (sum, i) => sum + i.quantity);
}

/// Group cart items by store name (first-seen store order + item order preserved).
List<StoreGroup> groupItemsByStore(List<CartItem> items) {
  final order = <String>[];
  final map = <String, List<CartItem>>{};
  for (final it in items) {
    final name = (it.storeName == null || it.storeName!.trim().isEmpty)
        ? 'Store'
        : it.storeName!.trim();
    if (!map.containsKey(name)) {
      map[name] = [];
      order.add(name);
    }
    map[name]!.add(it);
  }
  return [for (final n in order) StoreGroup(n, map[n]!)];
}
