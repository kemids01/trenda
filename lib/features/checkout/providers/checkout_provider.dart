// lib/features/checkout/providers/checkout_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/core/logger.dart';
import 'package:trenda_shared/core/config.dart';
import '../data/checkout_repository.dart';
import '../logic/checkout_error_text.dart';
import '../logic/payment_availability.dart';
import '../models/checkout_model.dart';

// Re-export DeliveryFees and CalculatedDeliveryFee for consumers of this provider
export '../data/checkout_repository.dart'
    show
        DeliveryFees,
        CalculatedDeliveryFee,
        MunicipalityFeesResponse,
        DynamicFees,
        FeeThreshold,
        CustomerGuidance,
        GuidanceTooltips,
        DeliveryAreaCheck,
        BlockedStore,
        CheckoutQuote,
        CheckoutQuoteGroup;

final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return CheckoutRepository(baseUrl: AppConfig.backendBaseUrl);
});

// ✅ Enhanced state management with better error handling
class CheckoutState {
  final String? orderId;
  /// Orders the checkout was placed as — one per store / Official warehouse, each with its own rider.
  final int orderCount;
  final bool isLoading;
  final String? error;
  final CheckoutStatus status;

  const CheckoutState({
    this.orderId,
    this.orderCount = 1,
    this.isLoading = false,
    this.error,
    this.status = CheckoutStatus.idle,
  });

  CheckoutState copyWith({
    String? orderId,
    int? orderCount,
    bool? isLoading,
    String? error,
    CheckoutStatus? status,
  }) {
    return CheckoutState(
      orderId: orderId ?? this.orderId,
      orderCount: orderCount ?? this.orderCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      status: status ?? this.status,
    );
  }
}

enum CheckoutStatus {
  idle,
  processing,
  success,
  error,
}

final checkoutProvider = StateNotifierProvider<CheckoutNotifier, CheckoutState>(
  (ref) => CheckoutNotifier(ref.read(checkoutRepositoryProvider)),
);

class CheckoutNotifier extends StateNotifier<CheckoutState> {
  final CheckoutRepository _repository;

  CheckoutNotifier(this._repository) : super(const CheckoutState());

  Future<String?> createCheckout(CheckoutRequest request) async {
    state = state.copyWith(
      isLoading: true,
      status: CheckoutStatus.processing,
      error: null,
    );

    try {
      final orderId = await _repository.createCheckout(request);

      state = state.copyWith(
        orderId: orderId,
        orderCount: _repository.lastPlacedOrderCount,
        isLoading: false,
        status: CheckoutStatus.success,
      );

      return orderId;
    } catch (e, stack) {
      AppLogger.error('Checkout error', e, stack);

      state = state.copyWith(
        isLoading: false,
        status: CheckoutStatus.error,
        error: _parseError(e),
      );

      return null;
    }
  }

  void reset() {
    state = const CheckoutState();
  }

  String _parseError(dynamic error) {
    // Already written for the shopper — including the server's own reason and
    // the cooldown wait, which this used to replace with "Checkout failed".
    if (error is CheckoutException) return error.message;
    if (error is CooldownException) return error.message;
    // Everything else names its actual cause (signed out, offline, unreadable reply…).
    return checkoutErrorText(error as Object);
  }
}

// ============================================================================
// DELIVERY FEES PROVIDER (fetches from database via API)
// ============================================================================

/// The delivery city the fees are being quoted for. Empty = no address chosen yet.
typedef DeliveryFeeScope = ({String municipality, String barangay});

const DeliveryFeeScope kUnscopedDeliveryFees = (municipality: '', barangay: '');

/// ✅ ENTERPRISE: Provider with keepAlive caching to avoid repeated API calls
/// Fees are cached per municipality for the checkout session, invalidate manually if needed.
///
/// ⚠️ KEYED BY MUNICIPALITY ON PURPOSE. `GET /api/config/delivery-fees` runs the §8 cascade at the
/// GLOBAL tier unless `?municipality=` is supplied. This provider used to call it with no argument,
/// so every city was quoted the global `delivery_settings.baseFee` while `createOrder` charged the
/// per-city override — Tuguegarao City showed ₱60 at checkout and billed ₱80
/// (ORD-1789445886279-9FP4QN). `ref.keepAlive()` made it worse: the wrong figure was then cached for
/// the whole session. Pass the shipping address's city, and its barangay so the per-barangay
/// surcharge resolves too.
final deliveryFeesProvider =
    FutureProvider.family<DeliveryFees, DeliveryFeeScope>((ref, scope) async {
  // Keep alive to cache fees during checkout session (per city).
  ref.keepAlive();

  final repository = ref.read(checkoutRepositoryProvider);
  try {
    final fees = await repository.getDeliveryFees(
      municipality: scope.municipality.isEmpty ? null : scope.municipality,
      barangay: scope.barangay.isEmpty ? null : scope.barangay,
    );
    AppLogger.info(
        'Delivery fees fetched from API (cached) for "${scope.municipality}"');
    return fees;
  } catch (e) {
    AppLogger.warning('Failed to fetch delivery fees, using defaults: $e');
    return DeliveryFees.defaults();
  }
});

// ============================================================================
// AUTHORITATIVE DELIVERY FEE PROVIDER (#1)
// Calls POST /api/config/calculate-delivery-fee — the SAME §8 cascade (distance-inclusive) the
// order is charged with. The UI uses this for the displayed fee; the local DeliveryFees formula is
// kept only as an offline fallback.
// ============================================================================

typedef CheckoutFeeParams = ({
  String deliveryType,
  String municipality,
  String barangay,
  double weight,
  int itemCount,
  double orderTotal,
  double vendorLat,
  double vendorLng,
  double customerLat,
  double customerLng,
  // Comma-joined PRODUCT ids of lines with no coordinates (pinlessLineIdsKey); the server resolves each
  // to its origin (vendor store / Official warehouse) exactly as createOrder does. A String, not a
  // List, so the family key compares.
  String productIds,
});

final checkoutFeeProvider =
    FutureProvider.family<CalculatedDeliveryFee, CheckoutFeeParams>((ref, p) async {
  final repo = ref.watch(checkoutRepositoryProvider);
  return repo.calculateDeliveryFeeByDistance(
    vendorLat: p.vendorLat,
    vendorLng: p.vendorLng,
    customerLat: p.customerLat,
    customerLng: p.customerLng,
    municipality: p.municipality,
    barangay: p.barangay,
    deliveryType: p.deliveryType,
    weight: p.weight,
    itemCount: p.itemCount,
    orderTotal: p.orderTotal,
    productIds: p.productIds,
  );
});

// ============================================================================
// MUNICIPALITY FEES PROVIDER (dynamic fee thresholds from DB)
// ============================================================================

/// Keyed by municipality name — fetches dynamic fees + customer guidance
final municipalityFeesProvider =
    FutureProvider.family<MunicipalityFeesResponse?, String>((ref, municipality) async {
  if (municipality.isEmpty) return null;

  final repository = ref.read(checkoutRepositoryProvider);
  try {
    return await repository.fetchMunicipalityFees(municipality);
  } catch (e) {
    AppLogger.warning('Failed to fetch municipality fees: $e');
    return null;
  }
});

// ============================================================================
// PAYMENT METHOD AVAILABILITY (per shipping municipality)
// ============================================================================

/// Which payment methods checkout may offer for [municipality].
///
/// The backend resolves the per-city override against the global flags and enforces that same
/// answer at submit, so asking it is the only way the app can avoid offering a method the order
/// will be refused for. Null municipality (no address chosen yet) returns the global resolution.
final paymentAvailabilityProvider =
    FutureProvider.family<PaymentAvailability?, String?>((ref, municipality) async {
  final repository = ref.read(checkoutRepositoryProvider);
  return repository.getPaymentMethods(municipality);
});

// ============================================================================
// DELIVERY AREA PRE-CHECK
// ============================================================================

/// What the delivery-area pre-check is asked about. `productIds` is a sorted,
/// comma-joined string so equal carts are equal keys.
typedef DeliveryAreaQuery = ({
  String municipality,
  String barangay,
  double? lat,
  double? lng,
  String productIds,
});

/// Can every store in the cart deliver to the chosen address? Same server rule as
/// createOrder (POST /api/checkout/delivery-area-check). Fails soft — its own error
/// never blocks checkout.
final deliveryAreaCheckProvider = FutureProvider.autoDispose
    .family<DeliveryAreaCheck, DeliveryAreaQuery>((ref, q) async {
  if (q.municipality.trim().isEmpty || q.productIds.isEmpty) {
    return DeliveryAreaCheck.unknown();
  }
  return ref.watch(checkoutRepositoryProvider).checkDeliveryArea(
    productIds: q.productIds.split(','),
    shippingAddress: {
      'city': q.municipality,
      'municipality': q.municipality,
      'barangay': q.barangay,
      if (q.lat != null) 'latitude': q.lat,
      if (q.lng != null) 'longitude': q.lng,
    },
  );
});

// ============================================================================
// PER-STORE DELIVERY QUOTE (POST /api/checkout/quote)
// A cart from several stores is placed as one order PER STORE (or Official warehouse), each with
// its own rider and its own delivery fee priced from that store. This asks the server — with the
// same grouping and pricing createOrder charges — what each store's delivery costs.
// ============================================================================

/// Family key. [cartKey] = checkoutQuoteCartKey(...), so equal carts are equal keys.
typedef CheckoutQuoteQuery = ({
  String cartKey,
  String municipality,
  String barangay,
  double? lat,
  double? lng,
  String deliveryType,
  String? batchTypeId,
});

/// Null while there is no address, or when the quote fails (checkout then keeps its single
/// estimate — never blocks).
final checkoutQuoteProvider =
    FutureProvider.autoDispose.family<CheckoutQuote?, CheckoutQuoteQuery>((ref, q) async {
  if (q.cartKey.isEmpty || q.municipality.trim().isEmpty || q.barangay.trim().isEmpty) return null;
  final items = q.cartKey.split(',').map((line) {
    final parts = line.split(':');
    return CheckoutItem(
      productId: parts[0],
      variantId: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
      quantity: parts.length > 2 ? int.tryParse(parts[2]) ?? 1 : 1,
    );
  }).toList();
  return ref.watch(checkoutRepositoryProvider).quoteCheckout(
    items: items,
    shippingAddress: {
      'city': q.municipality,
      'municipality': q.municipality,
      'barangay': q.barangay,
      if (q.lat != null) 'latitude': q.lat,
      if (q.lng != null) 'longitude': q.lng,
    },
    deliveryType: q.deliveryType,
    batchTypeId: q.batchTypeId,
  );
});
