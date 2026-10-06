// Which payment methods checkout may offer, per the shipping municipality.
// Checkout used to read only the GLOBAL flags, so a COD-only city still showed both options and the
// server rejected the choice at submit.
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/logic/payment_availability.dart';

void main() {
  group('paymentAvailabilityFromJson', () {
    test('treats an absent key as enabled, mirroring the backend', () {
      final a = paymentAvailabilityFromJson({});
      expect(a!.cashOnDelivery, isTrue);
      expect(a.onlinePayment, isTrue);
      expect(a.source, PaymentFlagSource.municipality);
    });

    test('only an explicit false disables a method', () {
      final a = paymentAvailabilityFromJson({'cashOnDelivery': false, 'onlinePayment': true})!;
      expect(a.cashOnDelivery, isFalse);
      expect(a.onlinePayment, isTrue);
    });

    test('null payload means "we have no municipality answer"', () {
      expect(paymentAvailabilityFromJson(null), isNull);
    });
  });

  group('resolvePaymentAvailability', () {
    test('the municipality answer wins — it is what the server enforces', () {
      final r = resolvePaymentAvailability(
        municipality: paymentAvailabilityFromJson({'cashOnDelivery': true, 'onlinePayment': false}),
        globalCashOnDelivery: true,
        globalOnlinePayment: true, // global says online is fine; the city says no
      );
      expect(r.onlinePayment, isFalse);
      expect(r.source, PaymentFlagSource.municipality);
    });

    test('falls back to the global flags before an address is chosen', () {
      final r = resolvePaymentAvailability(globalCashOnDelivery: true, globalOnlinePayment: false);
      expect(r.cashOnDelivery, isTrue);
      expect(r.onlinePayment, isFalse);
      expect(r.source, PaymentFlagSource.global);
    });

    test('falls back to COD-only when nothing is known', () {
      expect(resolvePaymentAvailability(), PaymentAvailability.fallback);
      expect(PaymentAvailability.fallback.cashOnDelivery, isTrue);
    });

    test('never leaves the customer with no way to pay', () {
      // A stale or partial payload that disables everything would make the order unplaceable.
      // Keep COD and let the server have the final say.
      final r = resolvePaymentAvailability(
        municipality: paymentAvailabilityFromJson({'cashOnDelivery': false, 'onlinePayment': false}),
      );
      expect(r.anyEnabled, isTrue);
      expect(r.cashOnDelivery, isTrue);
    });

    test('same guard applies to the global flags', () {
      final r = resolvePaymentAvailability(globalCashOnDelivery: false, globalOnlinePayment: false);
      expect(r.cashOnDelivery, isTrue);
      expect(r.source, PaymentFlagSource.global);
    });

    test('a COD-only city keeps COD and drops online', () {
      final r = resolvePaymentAvailability(
        municipality: paymentAvailabilityFromJson({'cashOnDelivery': true, 'onlinePayment': false}),
      );
      expect(r.cashOnDelivery, isTrue);
      expect(r.onlinePayment, isFalse);
    });
  });
}
