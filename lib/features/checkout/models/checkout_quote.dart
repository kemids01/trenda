// lib/features/checkout/models/checkout_quote.dart
//
// One delivery fee PER STORE (POST /api/checkout/quote). A checkout with items from two stores is
// placed as two orders — one per store, or per Official Trenda warehouse — each delivered by its
// own rider and priced from its own store to the customer. The server groups and prices the cart
// with the same code createOrder charges with, so these are the fees the customer pays.

/// One store's (or warehouse's) delivery in a checkout.
class CheckoutQuoteGroup {
  final String key;
  final String label;
  final bool isOfficial;
  final int itemCount;
  final double subtotal;
  final String deliveryType;

  /// Null when the server could not price this delivery (then the checkout falls back to the
  /// single estimate) — never shown as ₱0.
  final double? fee;

  /// Why this delivery cannot be placed as chosen (e.g. too heavy for Pasabay), if anything.
  final String? error;

  const CheckoutQuoteGroup({
    required this.key,
    required this.label,
    required this.isOfficial,
    required this.itemCount,
    required this.subtotal,
    required this.deliveryType,
    this.fee,
    this.error,
  });

  factory CheckoutQuoteGroup.fromJson(Map<String, dynamic> j) => CheckoutQuoteGroup(
        key: j['key']?.toString() ?? '',
        label: (j['label']?.toString().trim().isNotEmpty ?? false) ? j['label'].toString() : 'Store',
        isOfficial: j['kind'] == 'official',
        itemCount: (j['itemCount'] as num?)?.toInt() ?? 0,
        subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
        deliveryType: j['deliveryType']?.toString() ?? 'express',
        fee: (j['fee'] as num?)?.toDouble(),
        error: j['error']?.toString(),
      );
}

class CheckoutQuote {
  final List<CheckoutQuoteGroup> groups;

  /// Sum of every store's fee; null when any of them could not be priced.
  final double? deliveryTotal;

  const CheckoutQuote({required this.groups, this.deliveryTotal});

  factory CheckoutQuote.fromJson(Map<String, dynamic> j) {
    final groups = ((j['groups'] as List?) ?? const [])
        .whereType<Map>()
        .map((g) => CheckoutQuoteGroup.fromJson(Map<String, dynamic>.from(g)))
        .toList();
    final total = (j['deliveryTotal'] as num?)?.toDouble();
    final allPriced = groups.isNotEmpty && groups.every((g) => g.fee != null);
    return CheckoutQuote(groups: groups, deliveryTotal: allPriced ? total : null);
  }

  /// More than one store → more than one order, rider and delivery fee.
  bool get isSplit => groups.length > 1;

  /// The per-store fees are usable for display: split, and every store priced.
  bool get showsPerStoreFees => isSplit && deliveryTotal != null;

  /// "2 stores · 2 riders" — what the split means for the shopper.
  String get splitCaption => '${groups.length} stores · ${groups.length} riders';
}

/// Stable family key for a cart: sorted "productId:variantId:qty" lines.
String checkoutQuoteCartKey(Iterable<({String productId, String? variantId, int quantity})> lines) {
  final parts = lines.map((l) => '${l.productId}:${l.variantId ?? ''}:${l.quantity}').toList()..sort();
  return parts.join(',');
}
