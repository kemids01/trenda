// trenda_shared/lib/core/trenda_qr.dart
// Canonical Trenda QR scheme shared by trenda_admin (build), trenda_vendor +
// trenda_frontend (scan). A single format so every app agrees on what a scanned
// code means.
//
// Format:  trenda://<kind>/<id>
//   kind = product   → a RETAIL store product (consumer clone Product id) → trenda_frontend
//   kind = wholesale → an official master (SupplierProduct id)            → trenda_vendor
//   kind = supplier  → a supplier id                                      → trenda_vendor
//   kind = store     → a vendor storefront (vendor id)                    → trenda_frontend
//
// ⚠️ `parse` is DELIBERATELY STRICT: a string with no Trenda marker returns
// null. It used to fall through to `product` for anything unrecognised, which
// meant a vendor store code (`trenda://store/<vendorId>`) was read as a product
// and opened a product page for a vendor id — and any foreign QR (a Wi-Fi code,
// a random URL) pushed a dead product page instead of saying "not a Trenda
// code". A guess that navigates is worse than a refusal.

/// What a scanned Trenda QR points at.
enum TrendaQrKind { product, wholesale, supplier, store }

/// Resolved scan target.
class TrendaQrTarget {
  const TrendaQrTarget(this.kind, this.id);
  final TrendaQrKind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is TrendaQrTarget && other.kind == kind && other.id == id;
  @override
  int get hashCode => Object.hash(kind, id);
  @override
  String toString() => 'TrendaQrTarget(${kind.name}, $id)';
}

/// Build + parse the canonical Trenda QR value.
class TrendaQr {
  const TrendaQr._();

  /// Mongo ObjectId shape — the only thing accepted as a bare, keyword-less id
  /// (1D barcodes on shelf labels carry just this).
  static final RegExp _objectId = RegExp(r'^[0-9a-fA-F]{24}$');

  /// Keyword → kind. Plurals included because web URLs use them.
  static const Map<String, TrendaQrKind> _kinds = {
    'product': TrendaQrKind.product,
    'products': TrendaQrKind.product,
    'wholesale': TrendaQrKind.wholesale,
    'supplier': TrendaQrKind.supplier,
    'suppliers': TrendaQrKind.supplier,
    'store': TrendaQrKind.store,
    'stores': TrendaQrKind.store,
    'vendor': TrendaQrKind.store,
  };

  /// The string to encode into a QR image: `trenda://<kind>/<id>`.
  static String build(TrendaQrKind kind, String id) =>
      'trenda://${kind.name}/${id.trim()}';

  /// Parse a scanned string into a [TrendaQrTarget].
  ///
  /// Accepted:
  ///   - `trenda://<kind>/<id>` — the canonical form every printed label uses
  ///   - `https://<host>/<kind>/<id>` and `https://<host>/q/<kind>/<id>`
  ///   - `<kind>:<id>`
  ///   - a bare 24-hex ObjectId → [TrendaQrKind.product]
  ///
  /// Returns null for everything else, INCLUDING a recognised kind with no id.
  static TrendaQrTarget? parse(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // A bare ObjectId is the shelf-barcode case and carries no keyword.
    if (_objectId.hasMatch(s)) return TrendaQrTarget(TrendaQrKind.product, s);

    // Split on every separator a Trenda code can use, dropping the scheme and
    // host so `https://trenda.app/q/product/ID` and `trenda://product/ID` reduce
    // to the same segment list.
    final segs = s
        .split(RegExp(r'[/:?=&#]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (segs.isEmpty) return null;

    // Find the LAST kind keyword, so a host containing one (say
    // "store.trenda.ph/product/ID") still resolves by the real path segment.
    var kindIndex = -1;
    TrendaQrKind? kind;
    for (var i = 0; i < segs.length; i++) {
      final hit = _kinds[segs[i].toLowerCase()];
      if (hit != null) {
        kind = hit;
        kindIndex = i;
      }
    }
    if (kind == null) return null;

    // The id is what follows the keyword. Anything before it is scheme/host.
    final after = segs.sublist(kindIndex + 1);
    if (after.isEmpty) return null;

    // Prefer a proper ObjectId among the remaining segments (tolerates a
    // trailing slug or query leftovers); else take the first one.
    final id = after.firstWhere(
      (p) => _objectId.hasMatch(p),
      orElse: () => after.first,
    );
    if (id.isEmpty) return null;

    return TrendaQrTarget(kind, id);
  }
}
