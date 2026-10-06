class DeliveryForce {
  final String type; // 'heavy_express'
  final String reason;
  const DeliveryForce(this.type, this.reason);
}

/// Which delivery type the cart weight FORCES, with a customer-facing reason. Null if none.
///
/// [heavyThreshold] MUST be the server's heavy-TYPE threshold (DeliveryFees.heavyTypeThresholdKg,
/// from GET /api/config/delivery-fees → resolved from DeliverySettings.loadCapacityKg). The same
/// number gates checkoutController and the Order pre-save hook, so the option offered here is always
/// the option the server will price and dispatch. Passing the weight-SURCHARGE threshold instead
/// (the old behaviour) let the app offer Express for a cart the server re-typed as Heavy.
/// Bulk was merged into Heavy platform-wide.
DeliveryForce? deliverySelectionReason({
  required double totalWeight,
  double heavyThreshold = 20,
}) {
  if (totalWeight > heavyThreshold) {
    final w = totalWeight.toStringAsFixed(1);
    return DeliveryForce('heavy_express',
        'Your cart weighs $w kg. Heavy Express is required for orders over ${heavyThreshold.toStringAsFixed(0)} kg.');
  }
  return null;
}

/// Final delivery options to offer.
/// • locked type (by weight) -> only that type
/// • pasabay dropped when GPS-only, and when the cart is at/above [pasabayMaxWeightKg]
///   (the server rejects pasabay there, so offering it would fail at submit).
List<String> availableDeliveryTypes(
  List<String> adminEnabled, {
  required bool gpsOnly,
  String? lockedType,
  double totalWeight = 0,
  double pasabayMaxWeightKg = 50,
}) {
  if (lockedType != null) return [lockedType];
  final dropPasabay = gpsOnly || totalWeight >= pasabayMaxWeightKg;
  if (dropPasabay) return adminEnabled.where((t) => t != 'pasabay').toList();
  return adminEnabled;
}
