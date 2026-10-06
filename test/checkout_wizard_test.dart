import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/utils/checkout_wizard.dart';

void main() {
  group('kCheckoutSteps', () {
    test('has 3 ordered steps with the expected labels', () {
      expect(kCheckoutSteps.length, 3);
      expect(kCheckoutSteps[0].label, 'Address');
      expect(kCheckoutSteps[1].label, 'Delivery');
      expect(kCheckoutSteps[2].label, 'Review');
      expect([for (final s in kCheckoutSteps) s.index], [0, 1, 2]);
    });
  });

  group('checkoutStep1Valid', () {
    ({String? city, String? street, String? barangay, String name, String phone})
        base() => (
              city: 'Tuguegarao City',
              street: '123 Rizal St',
              barangay: 'Centro',
              name: 'Juan Dela Cruz',
              phone: '09171234567',
            );

    bool call(({String? city, String? street, String? barangay, String name, String phone}) a) =>
        checkoutStep1Valid(
          city: a.city, street: a.street, barangay: a.barangay,
          name: a.name, phone: a.phone,
        );

    test('valid when all present and phone valid', () {
      expect(call(base()), isTrue);
    });
    test('invalid when city missing', () {
      final a = base();
      expect(call((city: '', street: a.street, barangay: a.barangay, name: a.name, phone: a.phone)), isFalse);
      expect(call((city: null, street: a.street, barangay: a.barangay, name: a.name, phone: a.phone)), isFalse);
    });
    test('invalid when street missing', () {
      final a = base();
      expect(call((city: a.city, street: '', barangay: a.barangay, name: a.name, phone: a.phone)), isFalse);
    });
    test('invalid when barangay missing', () {
      final a = base();
      expect(call((city: a.city, street: a.street, barangay: '', name: a.name, phone: a.phone)), isFalse);
      expect(call((city: a.city, street: a.street, barangay: null, name: a.name, phone: a.phone)), isFalse);
    });
    test('invalid when name blank', () {
      final a = base();
      expect(call((city: a.city, street: a.street, barangay: a.barangay, name: '   ', phone: a.phone)), isFalse);
    });
    test('invalid when phone invalid', () {
      final a = base();
      expect(call((city: a.city, street: a.street, barangay: a.barangay, name: a.name, phone: '123')), isFalse);
    });
  });
}
