import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/data/checkout_repository.dart';
import 'package:trenda_frontend/features/checkout/providers/promo_provider.dart';

void main() {
  group('PromoNotifier', () {
    test('valid code sets appliedCode + discount, clears error', () async {
      final n = PromoNotifier(
        (code, total) async =>
            const CouponValidation(ok: true, discount: 50, type: 'percentage'),
      );
      final ok = await n.applyPromoCode('save10', 500);
      expect(ok, true);
      expect(n.state.appliedCode, 'SAVE10');
      expect(n.state.discount, 50);
      expect(n.state.error, isNull);
      expect(n.state.isLoading, false);
    });

    test('invalid code sets error, leaves appliedCode null', () async {
      final n = PromoNotifier(
        (code, total) async =>
            const CouponValidation(ok: false, message: 'Invalid coupon code'),
      );
      final ok = await n.applyPromoCode('NOPE', 500);
      expect(ok, false);
      expect(n.state.appliedCode, isNull);
      expect(n.state.discount, 0);
      expect(n.state.error, 'Invalid coupon code');
    });

    test('empty code short-circuits with error, no validator call', () async {
      var called = false;
      final n = PromoNotifier((code, total) async {
        called = true;
        return const CouponValidation(ok: true, discount: 10);
      });
      final ok = await n.applyPromoCode('   ', 500);
      expect(ok, false);
      expect(called, false);
      expect(n.state.error, isNotNull);
    });

    test('removePromoCode resets state', () async {
      final n = PromoNotifier(
        (code, total) async => const CouponValidation(ok: true, discount: 50),
      );
      await n.applyPromoCode('SAVE10', 500);
      n.removePromoCode();
      expect(n.state.appliedCode, isNull);
      expect(n.state.discount, 0);
      expect(n.state.error, isNull);
    });
  });
}
