// lib/features/checkout/data/checkout_repository.dart
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:trenda_shared/core/logger.dart';
import '../logic/checkout_error_text.dart';
import '../logic/payment_availability.dart';
import '../models/checkout_model.dart';
import '../models/checkout_quote.dart';

export '../models/checkout_quote.dart';

/// Result of a coupon validation call (POST /api/coupons/validate).
class CouponValidation {
  final bool ok;
  final double discount;
  final String? type;
  /// Non-null only on failure (ok == false).
  final String? message;

  const CouponValidation({
    required this.ok,
    this.discount = 0.0,
    this.type,
    this.message,
  });
}

/// Pure parser for the /api/coupons/validate response.
/// Testable without http/Firebase. 200+success → ok with discount/type;
/// anything else → not-ok with the backend message.
CouponValidation parseCouponValidationResponse(int statusCode, String body) {
  Map<String, dynamic> parsed;
  try {
    parsed = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return const CouponValidation(ok: false, message: 'Could not validate coupon');
  }
  if (statusCode == 200 && parsed['success'] == true) {
    final data = (parsed['data'] as Map<String, dynamic>?) ?? const {};
    return CouponValidation(
      ok: true,
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      type: data['type'] as String?,
    );
  }
  return CouponValidation(
    ok: false,
    message: (parsed['message'] as String?) ?? 'Invalid coupon code',
  );
}

/// Which `X-Idempotency-Key` a checkout attempt sends.
///
/// ⚠️ The backend caches the FIRST response for a key for 24 h — errors included —
/// and replays it for any later request with that key. So a key may be reused ONLY
/// for a retry of the very same order whose earlier attempt got no definitive
/// answer (timed out / dropped connection, or 409 "still processing"). Reusing it
/// after a refusal ("Insufficient stock") would replay that refusal all day even
/// after the shopper fixed the cart. And a NEW key per tap — what this used to do —
/// meant a retry after a slow Render cold start created a second order.
class IdempotencyKeyLedger {
  String? _key;
  String? _body;

  /// The key for [body]: the pending one if [body] is the same order, else fresh.
  String keyFor(String body, String Function() generate) {
    if (_key != null && _body == body) return _key!;
    _key = generate();
    _body = body;
    return _key!;
  }

  /// The server answered definitively — the next attempt is a new request.
  void settle() {
    _key = null;
    _body = null;
  }
}

class CheckoutRepository {
  final String baseUrl;

  CheckoutRepository({required this.baseUrl});

  /// Long enough for a Render cold start; an unbounded wait left the spinner up
  /// forever when a connection stalled.
  static const Duration _createTimeout = Duration(seconds: 90);

  final IdempotencyKeyLedger _keys = IdempotencyKeyLedger();

  /// Generate a unique idempotency key for each checkout request
  /// Backend requires: 16-128 characters
  String _generateIdempotencyKey() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final random = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final userId =
        FirebaseAuth.instance.currentUser?.uid.substring(0, 8) ?? 'guest';
    // Format: checkout-{userId}-{timestamp}-{random} = guaranteed 16+ chars
    return 'checkout-$userId-$timestamp-$random';
  }

  /// How many orders the last successful [createCheckout] placed. A cart from N stores (or N
  /// Official warehouses) is placed as N orders, each with its own rider; the confirmation page
  /// says so. 1 for an ordinary single-store checkout and for servers that predate the split.
  int lastPlacedOrderCount = 1;

  /// Per-store delivery fees for this cart (POST /api/checkout/quote) — the same grouping and
  /// pricing createOrder charges. Fails SOFT: any error → null, and checkout keeps its single
  /// estimate (createOrder is authoritative either way).
  Future<CheckoutQuote?> quoteCheckout({
    required List<CheckoutItem> items,
    required Map<String, dynamic> shippingAddress,
    required String deliveryType,
    String? batchTypeId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final token = await user.getIdToken();
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/checkout/quote'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'cartItems': items.map((e) => e.toJson()).toList(),
              'shippingAddress': shippingAddress,
              'deliveryType': deliveryType,
              if (batchTypeId != null) 'batchTypeId': batchTypeId,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is! Map || body['data'] is! Map) return null;
      return CheckoutQuote.fromJson(Map<String, dynamic>.from(body['data'] as Map));
    } catch (e) {
      AppLogger.warning('Checkout quote failed (falling back to the single estimate): $e');
      return null;
    }
  }

  Future<String> createCheckout(CheckoutRequest request) async {
    try {
      // Get Firebase token - force refresh for critical checkout operation
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      final token = await user.getIdToken(true); // ✅ Force refresh

      final requestBody = request.toJson();
      final encodedBody = jsonEncode(requestBody);
      AppLogger.debug('📤 Checkout Request: $requestBody', 'Checkout');

      // Same order retried after no answer → same key (see IdempotencyKeyLedger).
      final idempotencyKey = _keys.keyFor(encodedBody, _generateIdempotencyKey);

      final http.Response res;
      try {
        res = await http
            .post(
              Uri.parse('$baseUrl/api/checkout/create-order'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
                'X-Idempotency-Key': idempotencyKey, // ✅ Required by backend
              },
              body: encodedBody,
            )
            .timeout(_createTimeout);
      } catch (e) {
        // No answer: the order MAY have been placed. Keep the key, so tapping
        // Place order again returns that order instead of creating a second one.
        throw const CheckoutException(
          "We couldn't confirm your order. Check My orders before trying again — "
          'tapping Place order again will not create a second order.',
        );
      }

      // 409 = the first attempt is still running on the server; keep the key so
      // the next tap picks up its result. Anything else is a definitive answer.
      if (res.statusCode == 409) {
        throw CheckoutException(_messageOf(res.body) ??
            'Your order is still being placed. Please wait a moment.');
      }
      _keys.settle();

      // ✅ Handle 429 cooldown error specially
      if (res.statusCode == 429) {
        final body = jsonDecode(res.body);
        final message =
            body['message'] ?? 'Please wait before placing a new order';
        final remainingMinutes = body['data']?['remainingMinutes'];

        if (remainingMinutes != null) {
          throw CooldownException(
            'Please wait $remainingMinutes minute(s) before placing a new order. '
            'This helps prevent order abuse.',
            remainingMinutes: remainingMinutes as int,
          );
        }
        throw CooldownException(message);
      }

      if (res.statusCode != 201) {
        AppLogger.error(
            'Create Checkout Failed: Status: ${res.statusCode}', null);
        AppLogger.debug('📥 Error Response Body: ${res.body}', 'Checkout');
        // The server's reason, not "400 {json}" — it is written for the shopper.
        throw CheckoutException(serverFailureText(res.statusCode, res.body));
      }

      final String orderId;
      try {
        final body = jsonDecode(res.body);
        if (body['success'] != true) {
          throw CheckoutException(serverFailureText(res.statusCode, res.body));
        }
        // Backend returns order object, not orderId directly
        final orderData = body['data']['order'];
        orderId =
            orderData['_id']?.toString() ?? orderData['id']?.toString() ?? '';
        // One order per store — `orders` lists them all; `order` is the first.
        final orders = body['data']['orders'];
        lastPlacedOrderCount = orders is List && orders.isNotEmpty ? orders.length : 1;
      } on CheckoutException {
        rethrow;
      } catch (_) {
        // A 201 we can't read: the order WAS created.
        throw const CheckoutException(
            'Your order was placed but we could not open it. See My orders.');
      }
      if (orderId.isEmpty) {
        // Navigating to /order-confirmation/'' shows a broken page.
        throw const CheckoutException(
            'Your order was placed but we could not open it. See My orders.');
      }
      return orderId;
    } catch (e) {
      AppLogger.error('createCheckout error', e);
      rethrow;
    }
  }

  /// Validate a coupon for live Apply-time feedback. Advisory only —
  /// createOrder re-validates server-side and is authoritative.
  /// Can every store in the cart deliver to this address? Same server rule createOrder
  /// enforces. Fails SOFT: any error → [DeliveryAreaCheck.unknown] (never blocks —
  /// createOrder still enforces).
  Future<DeliveryAreaCheck> checkDeliveryArea({
    required List<String> productIds,
    required Map<String, dynamic> shippingAddress,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return DeliveryAreaCheck.unknown();
      final token = await user.getIdToken();
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/checkout/delivery-area-check'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'items': [for (final id in productIds) {'productId': id}],
              'shippingAddress': shippingAddress,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return DeliveryAreaCheck.unknown();
      final body = jsonDecode(res.body);
      if (body is! Map || body['data'] is! Map) return DeliveryAreaCheck.unknown();
      return DeliveryAreaCheck.fromJson(Map<String, dynamic>.from(body['data'] as Map));
    } catch (_) {
      return DeliveryAreaCheck.unknown();
    }
  }

  Future<CouponValidation> validateCoupon(String code, double cartTotal) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return const CouponValidation(
            ok: false, message: 'Please sign in to use a coupon');
      }
      final token = await user.getIdToken();
      final res = await http.post(
        Uri.parse('$baseUrl/api/coupons/validate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'code': code, 'cartTotal': cartTotal}),
      );
      return parseCouponValidationResponse(res.statusCode, res.body);
    } catch (e) {
      return const CouponValidation(
          ok: false, message: 'Could not validate coupon. Try again.');
    }
  }

  /// Which payment methods this municipality allows, resolved by the backend
  /// (per-city MunicipalityFees.paymentMethods override → global featureFlags).
  ///
  /// The server enforces exactly this at submit, so checkout must ask rather than assume: a
  /// COD-only city used to be offered both methods and the order was refused on placement.
  /// Returns null when it cannot be resolved — the caller then falls back to the global flags.
  Future<PaymentAvailability?> getPaymentMethods(String? municipality) async {
    try {
      final uri = Uri.parse('$baseUrl/api/config/delivery-fees').replace(
        queryParameters: {
          if (municipality != null && municipality.isNotEmpty) 'municipality': municipality,
        },
      );
      final res = await http.get(uri, headers: {'Content-Type': 'application/json'});
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body['success'] != true || body['data'] == null) return null;
      final raw = body['data']['paymentMethods'];
      return paymentAvailabilityFromJson(
          raw is Map ? Map<String, dynamic>.from(raw) : null);
    } catch (e) {
      AppLogger.warning('getPaymentMethods failed, falling back to global flags: $e');
      return null;
    }
  }

  /// Fetch delivery fees from database (set by admin in SystemConfig).
  ///
  /// [municipality] resolves the per-city overrides (fees, enabled types, weight gates) and
  /// [barangay] the per-barangay per-type override on top of it. Omitting them is NOT neutral — the
  /// endpoint then runs the §8 cascade at the GLOBAL tier, so the app quotes a fee the order will
  /// not be charged. Always pass the shipping address once one is chosen.
  Future<DeliveryFees> getDeliveryFees({
    String? municipality,
    String? barangay,
  }) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/config/delivery-fees').replace(
          queryParameters: {
            if (municipality != null && municipality.isNotEmpty) 'municipality': municipality,
            if (barangay != null && barangay.isNotEmpty) 'barangay': barangay,
          },
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return DeliveryFees.fromJson(body['data']);
        }
      }

      // Return defaults if API fails
      AppLogger.warning(
          'Delivery fees API returned non-200: ${res.statusCode}');
      return DeliveryFees.defaults();
    } catch (e) {
      AppLogger.error('getDeliveryFees error', e);
      return DeliveryFees.defaults();
    }
  }

  /// ✅ Calculate delivery fee based on vendor-to-customer distance
  /// Calls backend API with Haversine distance calculation
  Future<CalculatedDeliveryFee> calculateDeliveryFeeByDistance({
    required double vendorLat,
    required double vendorLng,
    required double customerLat,
    required double customerLng,
    String? municipality,
    String? barangay,
    String deliveryType = 'express',
    String? batchTypeId,
    double weight = 0,
    int itemCount = 1,
    double orderTotal = 0,
    String productIds = '',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/config/calculate-delivery-fee'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vendorLat': vendorLat,
          'vendorLng': vendorLng,
          'customerLat': customerLat,
          'customerLng': customerLng,
          'municipality': municipality,
          // Send the delivery barangay so the estimate includes the per-barangay
          // surcharge (estimate == charge).
          if (barangay != null && barangay.isNotEmpty) 'barangay': barangay,
          'deliveryType': deliveryType,
          // Pasabay: the selected batch type's multiplier (estimate == charge). Null = default type.
          if (batchTypeId != null) 'batchTypeId': batchTypeId,
          // Send the cart so the estimate == the charge (backend re-computes authoritatively).
          'weight': weight,
          'itemCount': itemCount,
          'orderTotal': orderTotal,
          // Products with no coordinates: the server resolves each to the origin createOrder uses
          // (vendor STORE pin / Official WAREHOUSE); vendorLat/Lng may then be 0, which it ignores.
          if (productIds.isNotEmpty) 'productIds': productIds.split(','),
        }),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return CalculatedDeliveryFee.fromJson(body['data']);
        }
      }

      // Fallback: use defaults with estimated distance
      AppLogger.warning(
          'Calculate delivery fee API returned non-200: ${res.statusCode}');
      return CalculatedDeliveryFee.fallback(deliveryType);
    } catch (e) {
      AppLogger.error('calculateDeliveryFeeByDistance error', e);
      return CalculatedDeliveryFee.fallback(deliveryType);
    }
  }

  /// ✅ Fetch municipality-specific fee thresholds and guidance from DB
  Future<MunicipalityFeesResponse?> fetchMunicipalityFees(
      String municipality) async {
    try {
      final encoded = Uri.encodeComponent(municipality);
      final res = await http.get(
        Uri.parse('$baseUrl/api/municipalities/$encoded/fees'),
        headers: {'Content-Type': 'application/json'},
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return MunicipalityFeesResponse.fromJson(
              body['data'] as Map<String, dynamic>);
        }
      }

      AppLogger.warning(
          'Municipality fees API returned non-200: ${res.statusCode}');
      return null;
    } catch (e) {
      AppLogger.error('fetchMunicipalityFees error', e);
      return null;
    }
  }
}

/// ✅ Result from distance-based delivery fee calculation
class CalculatedDeliveryFee {
  final double distance;
  final double baseFee;
  final double baseDistance;
  final double perKm;
  final double extraDistance;
  final double distanceFee;
  final double surcharge;
  final double totalFee;
  final String breakdown;
  final bool municipalityOverride;
  final String deliveryType;
  // ✅ NEW: Peak hour surcharge
  final double peakHourSurcharge;
  final bool isPeakHour;
  /// The heavy-tier flat surcharge inside [surcharge]. Broken out so the breakdown can name it.
  final double heavySurcharge;

  const CalculatedDeliveryFee({
    required this.distance,
    required this.baseFee,
    required this.baseDistance,
    required this.perKm,
    required this.extraDistance,
    required this.distanceFee,
    required this.surcharge,
    required this.totalFee,
    required this.breakdown,
    required this.municipalityOverride,
    required this.deliveryType,
    this.peakHourSurcharge = 0,
    this.isPeakHour = false,
    this.heavySurcharge = 0,
  });

  factory CalculatedDeliveryFee.fromJson(Map<String, dynamic> json) {
    final peakSurcharge = (json['peakHourSurcharge'] as num?)?.toDouble() ?? 0;
    return CalculatedDeliveryFee(
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
      baseFee: (json['baseFee'] as num?)?.toDouble() ?? 50,
      baseDistance: (json['baseDistance'] as num?)?.toDouble() ?? 1,
      perKm: (json['perKm'] as num?)?.toDouble() ?? 10,
      extraDistance: (json['extraDistance'] as num?)?.toDouble() ?? 0,
      distanceFee: (json['distanceFee'] as num?)?.toDouble() ?? 0,
      surcharge: (json['surcharge'] as num?)?.toDouble() ?? 0,
      totalFee: (json['totalFee'] as num?)?.toDouble() ?? 80,
      breakdown: json['breakdown'] as String? ?? 'Estimated fee',
      municipalityOverride: json['municipalityOverride'] as bool? ?? false,
      deliveryType: json['deliveryType'] as String? ?? 'express',
      peakHourSurcharge: peakSurcharge,
      heavySurcharge: (json['heavySurcharge'] as num?)?.toDouble() ?? 0,
      isPeakHour: peakSurcharge > 0,
    );
  }

  /// Fallback when API fails - uses reasonable defaults
  /// These values should match backend DeliverySettings defaults
  factory CalculatedDeliveryFee.fallback(String deliveryType) {
    // Default base fees (should match backend defaults)
    const double defaultExpress = 80;
    const double defaultPasabay = 20;
    const double defaultHeavy = 100;

    double fee;
    String breakdown;

    switch (deliveryType) {
      case 'express':
        fee = defaultExpress;
        breakdown = 'Express delivery (estimated)';
        break;
      case 'pasabay':
        fee = defaultPasabay;
        breakdown = 'Pasabay delivery (flat rate)';
        break;
      case 'heavy_express':
        fee = defaultHeavy;
        breakdown = 'Heavy express (estimated)';
        break;
      default:
        fee = defaultExpress;
        breakdown = 'Default delivery fee';
    }

    return CalculatedDeliveryFee(
      distance: 0,
      baseFee: 50,
      baseDistance: 1,
      perKm: 10,
      extraDistance: 0,
      distanceFee: 0,
      surcharge: deliveryType == 'express' ? 30 : 50,
      totalFee: fee,
      breakdown: breakdown,
      municipalityOverride: false,
      deliveryType: deliveryType,
    );
  }
}

/// Delivery fees from SystemConfig
class DeliveryFees {
  final double express;
  final double pasabay;
  final double heavyExpress;
  // ✅ The weight (kg) above which the SERVER forces heavy_express — resolved per municipality/
  // barangay from DeliverySettings.loadCapacityKg (GET /api/config/delivery-fees →
  // heavyTypeThresholdKg). Checkout MUST gate on this, not on heavyWeightThreshold: the latter is the
  // weight-SURCHARGE trigger, and when the two differ the app used to offer Express for a cart the
  // server then re-priced (and re-typed) as Heavy. Falls back to heavyWeightThreshold, then 20.
  final double heavyTypeThresholdKg;
  // ✅ The weight-surcharge trigger (₱/kg above it). NOT a type gate — see heavyTypeThresholdKg.
  final double heavyWeightThreshold;
  // ✅ Pasabay is unavailable at/above this cart weight (server rejects it at checkout).
  final double pasabayMaxWeightKg;
  final double base;
  final double baseDistance;
  final double perKm;
  final bool freeDeliveryEnabled;
  final double freeDeliveryThreshold;
  /// DEPRECATED — Express is the base tier; the backend's §8 cascade stopped applying an express
  /// surcharge on 2026-08-20. Kept only so older API payloads still parse. Do not add it to any
  /// customer-facing total or breakdown.
  @Deprecated('Express is the base tier — no surcharge is charged')
  final double expressSurcharge;
  final double heavySurcharge;
  // ✅ Cross-municipality surcharge (from backend config)
  // ✅ Admin-enabled delivery options (global). Absent => all enabled.
  final List<String> enabledDeliveryTypes;

  const DeliveryFees({
    required this.express,
    required this.pasabay,
    required this.heavyExpress,
    required this.base,
    required this.baseDistance,
    required this.perKm,
    this.freeDeliveryEnabled = false,
    this.freeDeliveryThreshold = 1000,
    this.expressSurcharge = 30,
    this.heavySurcharge = 50,
    this.heavyTypeThresholdKg = 20,
    this.heavyWeightThreshold = 20,
    this.pasabayMaxWeightKg = 50,
    this.enabledDeliveryTypes = const ['express', 'pasabay', 'heavy_express'],
  });

  /// Default fallback if API fails
  /// ✅ These match SystemConfig defaults in backend
  factory DeliveryFees.defaults() {
    return const DeliveryFees(
      express: 80,
      pasabay: 20,
      heavyExpress: 100,
      base: 50,
      baseDistance: 1,
      perKm: 10,
      freeDeliveryEnabled: false,
      freeDeliveryThreshold: 1000,
      expressSurcharge: 30,
      heavySurcharge: 50,
    );
  }

  factory DeliveryFees.fromJson(Map<String, dynamic> json) {
    return DeliveryFees(
      express: (json['express'] as num?)?.toDouble() ?? 80,
      pasabay: (json['pasabay'] as num?)?.toDouble() ?? 20,
      heavyExpress: (json['heavy_express'] as num?)?.toDouble() ?? 100,
      heavyTypeThresholdKg: (json['heavyTypeThresholdKg'] as num?)?.toDouble() ??
          (json['loadCapacityKg'] as num?)?.toDouble() ??
          (json['heavyWeightThreshold'] as num?)?.toDouble() ??
          20,
      heavyWeightThreshold:
          (json['heavyWeightThreshold'] as num?)?.toDouble() ?? 20,
      // F16: gate on the EFFECTIVE ceiling. The configured pasabayMaxWeightKg is subsumed by
      // heavy-forcing whenever it exceeds the load capacity (the default 50 vs 20 can never fire),
      // so the server sends what actually binds. Falls back to the raw value for an older backend.
      pasabayMaxWeightKg: (json['pasabayEffectiveMaxKg'] as num?)?.toDouble() ??
          (json['pasabayMaxWeightKg'] as num?)?.toDouble() ??
          50,
      base: (json['base'] as num?)?.toDouble() ?? 50,
      baseDistance: (json['baseDistance'] as num?)?.toDouble() ?? 1,
      perKm: (json['perKm'] as num?)?.toDouble() ?? 10,
      freeDeliveryEnabled: json['freeDeliveryEnabled'] as bool? ?? false,
      freeDeliveryThreshold:
          (json['freeDeliveryThreshold'] as num?)?.toDouble() ?? 1000,
      expressSurcharge: (json['expressSurcharge'] as num?)?.toDouble() ?? 30,
      heavySurcharge: (json['heavySurcharge'] as num?)?.toDouble() ?? 50,
      enabledDeliveryTypes: (json['enabledDeliveryTypes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['express', 'pasabay', 'heavy_express'],
    );
  }

  /// Get fee for delivery type (at base distance)
  double getFeeForType(String deliveryType) {
    switch (deliveryType) {
      case 'express':
        return express;
      case 'pasabay':
        return pasabay;
      case 'heavy_express':
        return heavyExpress;
      default:
        return base;
    }
  }

  /// ✅ Calculate fee based on actual distance
  /// Formula: base + (extraKm × perKm) + surcharge
  double calculateDistanceBasedFee(double distanceKm, String deliveryType) {
    // Flat-fee types are distance-independent.
    if (deliveryType == 'pasabay') return pasabay;

    // Calculate extra distance beyond base
    final extraKm = (distanceKm - baseDistance).clamp(0.0, double.infinity);
    final distanceFee = extraKm * perKm;

    // Get surcharge for delivery type
    double surcharge = 0;
    switch (deliveryType) {
      case 'express':
        surcharge = express - base;
        break;
      case 'heavy_express':
        surcharge = heavyExpress - base;
        break;
    }

    return base + distanceFee + surcharge;
  }
}

// ============================================================================
// MUNICIPALITY FEES (dynamic fee thresholds + customer guidance from DB)
// ============================================================================

/// Response from GET /api/municipalities/:name/fees
class MunicipalityFeesResponse {
  final DynamicFees dynamicFees;
  final CustomerGuidance customerGuidance;

  const MunicipalityFeesResponse({
    required this.dynamicFees,
    required this.customerGuidance,
  });

  factory MunicipalityFeesResponse.fromJson(Map<String, dynamic> json) {
    return MunicipalityFeesResponse(
      dynamicFees: DynamicFees.fromJson(
          json['dynamicFees'] as Map<String, dynamic>? ?? {}),
      customerGuidance: CustomerGuidance.fromJson(
          json['customerGuidance'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class DynamicFees {
  final bool enabled;
  final List<FeeThreshold> thresholds;

  const DynamicFees({this.enabled = false, this.thresholds = const []});

  factory DynamicFees.fromJson(Map<String, dynamic> json) {
    return DynamicFees(
      enabled: json['enabled'] as bool? ?? false,
      thresholds: (json['thresholds'] as List?)
              ?.map((t) =>
                  FeeThreshold.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class FeeThreshold {
  final double? maxOrderValue;
  final double vendorFeeMultiplier;
  final double deliveryFeeMultiplier;
  final String label;

  const FeeThreshold({
    this.maxOrderValue,
    this.vendorFeeMultiplier = 1.0,
    this.deliveryFeeMultiplier = 1.0,
    this.label = '',
  });

  factory FeeThreshold.fromJson(Map<String, dynamic> json) {
    return FeeThreshold(
      maxOrderValue: (json['maxOrderValue'] as num?)?.toDouble(),
      vendorFeeMultiplier:
          (json['vendorFeeMultiplier'] as num?)?.toDouble() ?? 1.0,
      deliveryFeeMultiplier:
          (json['deliveryFeeMultiplier'] as num?)?.toDouble() ?? 1.0,
      label: json['label'] as String? ?? '',
    );
  }
}

class CustomerGuidance {
  final String feeExplanation;
  final GuidanceTooltips tooltips;

  const CustomerGuidance({
    this.feeExplanation = '',
    this.tooltips = const GuidanceTooltips(),
  });

  factory CustomerGuidance.fromJson(Map<String, dynamic> json) {
    return CustomerGuidance(
      feeExplanation: json['feeExplanation'] as String? ?? '',
      tooltips: GuidanceTooltips.fromJson(
          json['tooltips'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class GuidanceTooltips {
  final String deliveryFee;
  final String platformFee;
  final String freeDelivery;
  final String crossMunicipality;

  const GuidanceTooltips({
    this.deliveryFee = '',
    this.platformFee = '',
    this.freeDelivery = '',
    this.crossMunicipality = '',
  });

  factory GuidanceTooltips.fromJson(Map<String, dynamic> json) {
    return GuidanceTooltips(
      deliveryFee: json['deliveryFee'] as String? ?? '',
      platformFee: json['platformFee'] as String? ?? '',
      freeDelivery: json['freeDelivery'] as String? ?? '',
      crossMunicipality: json['crossMunicipality'] as String? ?? '',
    );
  }
}

/// ✅ Custom exception for order cooldown
class CooldownException implements Exception {
  final String message;
  final int? remainingMinutes;

  CooldownException(this.message, {this.remainingMinutes});

  @override
  String toString() => message;
}

/// A checkout the server refused, or could not confirm. [message] is written for
/// the shopper and is shown as-is.
/// One store that cannot deliver to the chosen address.
class BlockedStore {
  final String storeName;
  final String storeMunicipality;

  /// 'outside_area' | 'store_location_missing'
  final String reason;
  const BlockedStore(this.storeName, this.storeMunicipality, this.reason);
}

/// Answer of POST /api/checkout/delivery-area-check — the same rule createOrder
/// enforces (trenda_backend utils/deliveryArea.js).
class DeliveryAreaCheck {
  final bool ok;
  final String addressMunicipality;
  final String message;
  final List<BlockedStore> blocked;
  const DeliveryAreaCheck({
    required this.ok,
    required this.addressMunicipality,
    required this.message,
    required this.blocked,
  });

  /// Could not ask the server. Never blocks — createOrder still enforces.
  factory DeliveryAreaCheck.unknown() => const DeliveryAreaCheck(
      ok: true, addressMunicipality: '', message: '', blocked: []);

  factory DeliveryAreaCheck.fromJson(Map<String, dynamic> j) => DeliveryAreaCheck(
        ok: j['ok'] != false,
        addressMunicipality: j['addressMunicipality']?.toString() ?? '',
        message: j['message']?.toString() ?? '',
        blocked: [
          for (final b in (j['blocked'] is List ? j['blocked'] as List : const []))
            if (b is Map)
              BlockedStore(
                b['storeName']?.toString() ?? 'A store',
                b['storeMunicipality']?.toString() ?? '',
                b['reason']?.toString() ?? 'outside_area',
              ),
        ],
      );
}

class CheckoutException implements Exception {
  final String message;
  const CheckoutException(this.message);

  @override
  String toString() => message;
}

/// The `message` of a JSON error body, or null.
String? _messageOf(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['message'] is String) {
      final m = (decoded['message'] as String).trim();
      return m.isEmpty ? null : m;
    }
  } catch (_) {
    // Not JSON — a host error page.
  }
  return null;
}
