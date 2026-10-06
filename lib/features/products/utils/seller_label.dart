// lib/features/products/utils/seller_label.dart
// Who is actually selling this item, and what Trenda can honestly promise about
// getting it to you. Pure so both can be pinned by tests — the page used to
// call every seller an "Official Store" and quote a delivery time nothing
// produces.

/// What the product page prints under the shop name.
///
/// "Official Trenda Store" is a specific first-party seller, not a compliment:
/// only [isOfficial] products may carry it. An ordinary vendor is a local
/// vendor; a resold listing names the reseller, with the maker credited
/// separately.
String sellerRoleLabel({bool isOfficial = false, bool isResale = false}) {
  if (isOfficial) return 'Official Trenda Store';
  if (isResale) return 'Reseller';
  return 'Local vendor';
}

/// One line of the delivery block.
class DeliveryPromise {
  final String text;

  /// True for things Trenda actually guarantees; false for "depends on" notes.
  final bool assured;

  const DeliveryPromise(this.text, {this.assured = true});
}

/// What can truthfully be said about delivery before checkout.
///
/// Trenda is municipality-scoped same-day-ish logistics with a fee resolved by
/// the fee cascade at checkout, and COD is the only working payment method —
/// so the page must not quote a shipping window ("3-5 days" was hardcoded) or
/// imply card payment.
List<DeliveryPromise> deliveryPromises({
  bool freeShipping = false,
  String? municipality,
}) {
  final where = (municipality != null && municipality.trim().isNotEmpty)
      ? ' in ${municipality.trim()}'
      : '';

  return [
    freeShipping
        ? const DeliveryPromise('Free delivery on this item')
        : DeliveryPromise(
            'Delivery fee is calculated at checkout from your address$where',
            assured: false,
          ),
    const DeliveryPromise('Delivered by a Trenda rider from the seller'),
    const DeliveryPromise('Cash on delivery — pay the rider when it arrives'),
  ];
}
