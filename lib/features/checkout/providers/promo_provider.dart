// lib/features/checkout/providers/promo_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/checkout_repository.dart';
import 'checkout_provider.dart'; // checkoutRepositoryProvider

/// A function that validates a coupon code against the backend.
typedef CouponValidator = Future<CouponValidation> Function(
    String code, double cartTotal);

/// Promo/coupon state. Discount/type come from the server, never computed locally.
class PromoState {
  final String? appliedCode;
  final double discount;
  final String? type;
  final bool isLoading;
  final String? error;

  const PromoState({
    this.appliedCode,
    this.discount = 0,
    this.type,
    this.isLoading = false,
    this.error,
  });
}

class PromoNotifier extends StateNotifier<PromoState> {
  final CouponValidator _validate;

  PromoNotifier(this._validate) : super(const PromoState());

  /// Validates [code] against the backend (advisory preview).
  /// The authoritative discount is recomputed by createOrder at checkout.
  Future<bool> applyPromoCode(String code, double cartTotal) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      state = const PromoState(error: 'Enter a promo code');
      return false;
    }

    state = const PromoState(isLoading: true);
    final result = await _validate(normalized, cartTotal);

    if (result.ok) {
      state = PromoState(
        appliedCode: normalized,
        discount: result.discount,
        type: result.type,
      );
      return true;
    }

    state = PromoState(error: result.message ?? 'Invalid promo code');
    return false;
  }

  void removePromoCode() {
    state = const PromoState();
  }
}

final promoProvider = StateNotifierProvider<PromoNotifier, PromoState>((ref) {
  final repo = ref.read(checkoutRepositoryProvider);
  return PromoNotifier((code, cartTotal) => repo.validateCoupon(code, cartTotal));
});
