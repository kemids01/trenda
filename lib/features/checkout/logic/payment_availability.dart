// Which payment methods the customer may actually choose, for the municipality they are shipping to.
//
// Checkout used to read only the GLOBAL app-config flags, so a city configured COD-only still showed
// the customer both options — the server then rejected the disallowed method at submit. The backend
// already resolves the per-city override for us (GET /api/config/delivery-fees?municipality= →
// `paymentMethods`); this decides which answer to trust.
//
// Pure and Flutter-free so the precedence is unit-testable.

/// Where the answer came from — useful for logging and for not silently trusting a failed fetch.
enum PaymentFlagSource { municipality, global, fallback }

class PaymentAvailability {
  final bool cashOnDelivery;
  final bool onlinePayment;
  final PaymentFlagSource source;

  const PaymentAvailability({
    required this.cashOnDelivery,
    required this.onlinePayment,
    required this.source,
  });

  /// Safe default when nothing could be resolved. COD stays ON deliberately: it is the only method
  /// that actually works today (there is no live online gateway), so defaulting it off would freeze
  /// ordering on a network blip.
  static const fallback = PaymentAvailability(
    cashOnDelivery: true,
    onlinePayment: false,
    source: PaymentFlagSource.fallback,
  );

  bool get anyEnabled => cashOnDelivery || onlinePayment;

  @override
  bool operator ==(Object other) =>
      other is PaymentAvailability &&
      other.cashOnDelivery == cashOnDelivery &&
      other.onlinePayment == onlinePayment &&
      other.source == source;

  @override
  int get hashCode => Object.hash(cashOnDelivery, onlinePayment, source);
}

/// Parse the `paymentMethods` object from /api/config/delivery-fees. Absent/!=false means enabled,
/// mirroring the backend's own `resolved.cashOnDelivery !== false`.
PaymentAvailability? paymentAvailabilityFromJson(Map<String, dynamic>? json) {
  if (json == null) return null;
  return PaymentAvailability(
    cashOnDelivery: json['cashOnDelivery'] != false,
    onlinePayment: json['onlinePayment'] != false,
    source: PaymentFlagSource.municipality,
  );
}

/// Decide what checkout should offer.
///
/// The per-municipality answer wins when we have one, because the SERVER enforces exactly that at
/// submit — showing anything else means offering a choice that will fail. Otherwise fall back to the
/// global flags, then to [PaymentAvailability.fallback].
///
/// One guard: never return "nothing is payable". If a resolution would disable every method the
/// customer simply could not order, so we keep COD available and let the server have the final say.
/// (The admin API already refuses a config that disables both; this protects against a stale or
/// partial payload reaching an installed app.)
PaymentAvailability resolvePaymentAvailability({
  PaymentAvailability? municipality,
  bool? globalCashOnDelivery,
  bool? globalOnlinePayment,
}) {
  PaymentAvailability chosen;
  if (municipality != null) {
    chosen = municipality;
  } else if (globalCashOnDelivery != null || globalOnlinePayment != null) {
    chosen = PaymentAvailability(
      cashOnDelivery: globalCashOnDelivery ?? true,
      onlinePayment: globalOnlinePayment ?? false,
      source: PaymentFlagSource.global,
    );
  } else {
    return PaymentAvailability.fallback;
  }

  if (!chosen.anyEnabled) {
    return PaymentAvailability(
      cashOnDelivery: true,
      onlinePayment: false,
      source: chosen.source,
    );
  }
  return chosen;
}
