// lib/features/checkout/utils/checkout_wizard.dart
//
// Pure helpers for the 3-step checkout wizard: step metadata (order pinned by
// tests) and step-1 validity. The widget calls checkoutStep1Valid so the Next
// gate and _canPlaceOrder never drift.
import 'package:trenda_shared/trenda_shared.dart' show PhoneValidator;

/// One wizard step: its zero-based [index] and short header [label].
class CheckoutStep {
  final int index;
  final String label;
  const CheckoutStep(this.index, this.label);
}

const List<CheckoutStep> kCheckoutSteps = [
  CheckoutStep(0, 'Address'),
  CheckoutStep(1, 'Delivery'),
  CheckoutStep(2, 'Review'),
];

/// True when step 1 (address + contact) is complete enough to advance:
/// city + street + barangay all non-empty, a non-blank name, and a valid phone.
bool checkoutStep1Valid({
  required String? city,
  required String? street,
  required String? barangay,
  required String name,
  required String phone,
}) {
  if ((city ?? '').trim().isEmpty) return false;
  if ((street ?? '').trim().isEmpty) return false;
  if ((barangay ?? '').trim().isEmpty) return false;
  if (name.trim().isEmpty) return false;
  return PhoneValidator.validate(phone.trim()).isValid;
}
