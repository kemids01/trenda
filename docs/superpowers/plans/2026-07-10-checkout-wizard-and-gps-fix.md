# Checkout Wizard + GPS Capture Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the customer checkout from one long scrolling page into a 3-step wizard (Address+Contact → Items+Delivery+Promo+Payment → Review+Place Order) while preserving all business logic, and land the already-written GPS capture hardening.

**Architecture:** Single-file restructure of `checkout_page.dart`. Reuse every existing `_buildX` section builder; add a step header, an `IndexedStack` body, and a Back/Next/Place-Order bottom bar. Extract fee/total math into one shared record so the review step and the bar never diverge. Pure step-1 validity + GPS message mapping live in small tested util files.

**Tech Stack:** Flutter, Riverpod, `geolocator`, `go_router`. Spec: `docs/superpowers/specs/2026-07-10-checkout-wizard-and-gps-fix-design.md`.

**Working dir for all commands:** `C:/files 12 19 2025/files/TrendaV3/trenda_frontend`

---

## File Structure

- `lib/features/checkout/utils/location_capture.dart` — GPS capture helper + pure message mapper. **Already created.**
- `test/location_capture_test.dart` — GPS helper tests. **Already created (7 tests).**
- `lib/features/checkout/utils/checkout_wizard.dart` — NEW pure: step metadata + `checkoutStep1Valid`.
- `test/checkout_wizard_test.dart` — NEW: step-1 validity truth table + step order.
- `lib/features/checkout/presentation/checkout_page.dart` — MODIFY: GPS call sites (done), then wizard restructure.

---

## Task 1: Land the GPS capture fix (code already written — verify & commit)

The helper, its test, and both call-site rewires are already in the working tree. This task
verifies and commits them.

**Files:**
- Create (done): `lib/features/checkout/utils/location_capture.dart`
- Create (done): `test/location_capture_test.dart`
- Modify (done): `lib/features/checkout/presentation/checkout_page.dart` (`_captureGps`, `_detectMyLocation`, imports)

- [ ] **Step 1: Run the GPS test**

Run: `flutter test test/location_capture_test.dart`
Expected: `+7: All tests passed!`

- [ ] **Step 2: Analyze the touched files**

Run: `flutter analyze lib/features/checkout/presentation/checkout_page.dart lib/features/checkout/utils/location_capture.dart`
Expected: 0 errors (2 pre-existing `Radio` `deprecated_member_use` infos on checkout_page.dart lines ~1379–1381 are OK).

- [ ] **Step 3: Commit**

```bash
git add lib/features/checkout/utils/location_capture.dart test/location_capture_test.dart lib/features/checkout/presentation/checkout_page.dart
git commit -m "fix(checkout): harden GPS capture (service check, timeout, friendly errors)"
```

---

## Task 2: Pure wizard helper — `checkoutStep1Valid` + step metadata (TDD)

**Files:**
- Create: `lib/features/checkout/utils/checkout_wizard.dart`
- Test: `test/checkout_wizard_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/checkout_wizard_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/checkout_wizard_test.dart`
Expected: FAIL — `checkout_wizard.dart` / `checkoutStep1Valid` not defined (compile error).

- [ ] **Step 3: Write the implementation**

Create `lib/features/checkout/utils/checkout_wizard.dart`:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/checkout_wizard_test.dart`
Expected: PASS (all groups green).

- [ ] **Step 5: Commit**

```bash
git add lib/features/checkout/utils/checkout_wizard.dart test/checkout_wizard_test.dart
git commit -m "feat(checkout): pure wizard step metadata + step-1 validity helper"
```

---

## Task 3: Extract `_computeCheckoutTotals` from `_buildBottomBar` (no behavior change)

Pull the fee/total computation (currently inline at the top of `_buildBottomBar`,
`checkout_page.dart` ~lines 1598–1723) into a method returning a record, so the wizard's review
step and bottom bar share one source. `_buildBottomBar` stays otherwise identical for now.

**Files:**
- Modify: `lib/features/checkout/presentation/checkout_page.dart`

- [ ] **Step 1: Add the record typedef and the compute method**

Add this typedef just above `class _CheckoutPageState` (top of the file, after imports):

```dart
/// All the fee/total figures the checkout UI displays. Computed once per build
/// (watches delivery-fee / checkout-fee / pasabay / promo providers) and shared
/// by the fee breakdown, the review step, and the bottom bar.
typedef CheckoutTotals = ({
  double subtotal,
  double discount,
  double shippingFee, // per-type display fee before free-shipping / cross-muni
  double crossMuniSurcharge,
  double finalShippingFee,
  double total,
  double? distanceKm,
  bool isFreeShippingEligible,
  bool isCrossMunicipality,
  String? vendorMunicipality,
});
```

Add this method to `_CheckoutPageState` (place it directly above `_buildBottomBar`). Its body is
the computation currently inside `_buildBottomBar` from `final deliveryFeesAsync = ...` down to the
`final total = rawTotal < 0 ? 0.0 : rawTotal;` line — moved verbatim, then returning the record:

```dart
CheckoutTotals _computeCheckoutTotals(CartModel cart) {
  final deliveryFeesAsync = ref.watch(deliveryFeesProvider);
  final deliveryFees = deliveryFeesAsync.valueOrNull ?? DeliveryFees.defaults();

  double shippingFee = deliveryFees.getFeeForType(_selectedDeliveryType);
  double? distanceKm;

  final cartWeight =
      cart.items.fold<double>(0, (s, i) => s + (i.weight ?? 0.5) * i.quantity);
  VendorDistance? fv;
  final custLat = _selectedAddress?.latitude;
  final custLng = _selectedAddress?.longitude;

  if (custLat != null && custLng != null && cart.items.isNotEmpty) {
    final vendorCoords = <List<double>>[];
    for (final i in cart.items) {
      final loc = i.location;
      if (loc != null && loc.coordinates.length >= 2) {
        vendorCoords
            .add([loc.coordinates[0].toDouble(), loc.coordinates[1].toDouble()]);
      }
    }
    fv = farthestVendor(vendorCoords, custLat, custLng);
    if (fv != null) {
      distanceKm = fv.distanceKm;
      final localFee =
          deliveryFees.calculateDistanceBasedFee(distanceKm, _selectedDeliveryType);
      final feeAsync = ref.watch(checkoutFeeProvider((
        deliveryType: _selectedDeliveryType,
        municipality: _selectedAddress!.city,
        barangay: _selectedAddress!.barangay ?? '',
        weight: cartWeight,
        itemCount: cart.items.length,
        orderTotal: cart.subtotal,
        vendorLat: fv.lat,
        vendorLng: fv.lng,
        customerLat: custLat,
        customerLng: custLng,
      )));
      shippingFee =
          feeAsync.maybeWhen(data: (f) => f.totalFee, orElse: () => localFee);
    }
  }

  if (_selectedDeliveryType == 'pasabay' && _selectedAddress != null) {
    final municipality = _selectedAddress!.city;
    final barangay = _selectedAddress!.barangay ?? '';
    if (barangay.isNotEmpty && municipality.isNotEmpty) {
      double normalFee = deliveryFees.express;
      final localExpress = distanceKm != null
          ? deliveryFees.calculateDistanceBasedFee(distanceKm, 'express')
          : deliveryFees.express;
      if (fv != null && custLat != null && custLng != null) {
        final exAsync = ref.watch(checkoutFeeProvider((
          deliveryType: 'express',
          municipality: municipality,
          barangay: barangay,
          weight: cartWeight,
          itemCount: cart.items.length,
          orderTotal: cart.subtotal,
          vendorLat: fv.lat,
          vendorLng: fv.lng,
          customerLat: custLat,
          customerLng: custLng,
        )));
        normalFee =
            exAsync.maybeWhen(data: (f) => f.totalFee, orElse: () => localExpress);
      } else {
        normalFee = localExpress;
      }
      final previewsAsync = ref.watch(pasabayFeePreviewProvider((
        municipality: municipality,
        barangay: barangay,
        normalFee: normalFee,
      )));
      final previews = previewsAsync.valueOrNull ?? [];
      if (previews.isNotEmpty) {
        final selectedId = _selectedBatchTypeId ?? previews.first.batchType?.id;
        final selectedPreview = previews.firstWhere(
          (p) => p.batchType?.id == selectedId,
          orElse: () => previews.first,
        );
        shippingFee =
            selectedPreview.feeInfo?.discountedFee ?? deliveryFees.pasabay;
      }
    }
  }

  final isFreeShippingEligible = deliveryFees.freeDeliveryEnabled &&
      cart.subtotal >= deliveryFees.freeDeliveryThreshold;

  bool isCrossMunicipality = false;
  double crossMuniSurcharge = 0.0;
  String? vendorMunicipality;
  if (_selectedAddress != null && cart.items.isNotEmpty) {
    final customerCity = _selectedAddress!.city.toLowerCase().trim();
    final storeMuni = cart.items.first.location?.city ?? '';
    vendorMunicipality = storeMuni;
    if (storeMuni.isNotEmpty && customerCity.isNotEmpty) {
      isCrossMunicipality = storeMuni.toLowerCase().trim() != customerCity;
      if (isCrossMunicipality) {
        crossMuniSurcharge = deliveryFees.crossMunicipalitySurcharge;
      }
    }
  }

  final finalShippingFee = isFreeShippingEligible
      ? crossMuniSurcharge
      : shippingFee + crossMuniSurcharge;
  final couponDiscount = ref.watch(promoProvider).discount;
  final rawTotal = cart.subtotal + finalShippingFee - couponDiscount;
  final total = rawTotal < 0 ? 0.0 : rawTotal;

  return (
    subtotal: cart.subtotal,
    discount: couponDiscount,
    shippingFee: shippingFee,
    crossMuniSurcharge: crossMuniSurcharge,
    finalShippingFee: finalShippingFee,
    total: total,
    distanceKm: distanceKm,
    isFreeShippingEligible: isFreeShippingEligible,
    isCrossMunicipality: isCrossMunicipality,
    vendorMunicipality: vendorMunicipality,
  );
}
```

- [ ] **Step 2: Rewrite `_buildBottomBar`'s head to use the record**

In `_buildBottomBar`, DELETE the moved computation (everything from `final deliveryFeesAsync = ...`
through `final total = rawTotal < 0 ? 0.0 : rawTotal;`) and replace it with:

```dart
final deliveryFees =
    ref.watch(deliveryFeesProvider).valueOrNull ?? DeliveryFees.defaults();
final t = _computeCheckoutTotals(cart);
final shippingFee = t.shippingFee;
final distanceKm = t.distanceKm;
final isFreeShippingEligible = t.isFreeShippingEligible;
final isCrossMunicipality = t.isCrossMunicipality;
final crossMuniSurcharge = t.crossMuniSurcharge;
final vendorMunicipality = t.vendorMunicipality;
final finalShippingFee = t.finalShippingFee;
final couponDiscount = t.discount;
final total = t.total;
final remainingForFree = deliveryFees.freeDeliveryThreshold - cart.subtotal;
final freeShippingProgress = deliveryFees.freeDeliveryEnabled
    ? (cart.subtotal / deliveryFees.freeDeliveryThreshold).clamp(0.0, 1.0)
    : 0.0;
```

Leave the rest of `_buildBottomBar` (the banners, summary rows, button) unchanged — every local
it referenced now exists with the same name and value.

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/features/checkout/presentation/checkout_page.dart`
Expected: 0 errors (only the 2 pre-existing `Radio` infos).

- [ ] **Step 4: Run the checkout test suite**

Run: `flutter test test/checkout_fee_provider_test.dart test/delivery_fees_test.dart test/closed_store_action_test.dart`
Expected: all PASS (pure refactor — no behavior change).

- [ ] **Step 5: Commit**

```bash
git add lib/features/checkout/presentation/checkout_page.dart
git commit -m "refactor(checkout): extract _computeCheckoutTotals shared by bar and review"
```

---

## Task 4: Shared fee breakdown widget `_buildFeeBreakdown` (DRY prep for the review step)

Extract the banners + summary rows + total (currently the body of `_buildBottomBar` from the
free-shipping banner down to the Total row, ~lines 1743–1927) into a reusable method the bottom
bar AND the review step render. The bottom bar keeps its container + button; only the inner
breakdown moves.

**Files:**
- Modify: `lib/features/checkout/presentation/checkout_page.dart`

- [ ] **Step 1: Add `_buildFeeBreakdown`**

Add this method to `_CheckoutPageState`. Move the widgets from `_buildBottomBar` — the
`if (deliveryFees.freeDeliveryEnabled && !isFreeShippingEligible) Container(...)` free-shipping
progress banner, the `if (isFreeShippingEligible) Container(...)` achieved banner, the
`if (isCrossMunicipality) Container(...)` warning, the `_buildSummaryRow('Subtotal', ...)` +
discount + cross-muni rows, the `InkWell(... _showFeeBreakdown ...)` delivery row, the
`if (isFreeShippingEligible) _buildSummaryRow('Delivery', 'FREE', ...)`, the `Divider`, and the
Total row — VERBATIM into this Column's children:

```dart
Widget _buildFeeBreakdown(CartModel cart, CheckoutTotals t) {
  final deliveryFees =
      ref.watch(deliveryFeesProvider).valueOrNull ?? DeliveryFees.defaults();
  final shippingFee = t.shippingFee;
  final distanceKm = t.distanceKm;
  final isFreeShippingEligible = t.isFreeShippingEligible;
  final isCrossMunicipality = t.isCrossMunicipality;
  final crossMuniSurcharge = t.crossMuniSurcharge;
  final vendorMunicipality = t.vendorMunicipality;
  final couponDiscount = t.discount;
  final total = t.total;
  final remainingForFree = deliveryFees.freeDeliveryThreshold - cart.subtotal;
  final freeShippingProgress = deliveryFees.freeDeliveryEnabled
      ? (cart.subtotal / deliveryFees.freeDeliveryThreshold).clamp(0.0, 1.0)
      : 0.0;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // <-- move the free-shipping/achieved/cross-muni banners + summary rows +
      //     delivery InkWell + Divider + Total row here VERBATIM from _buildBottomBar
    ],
  );
}
```

- [ ] **Step 2: Point `_buildBottomBar` at the shared breakdown**

In `_buildBottomBar`, replace the moved banner/row/Divider/Total widgets (the ones you just cut)
with a single `_buildFeeBreakdown(cart, t)` in the same position (immediately before the
`const SizedBox(height: 16)` that precedes the Place Order button). The `SafeArea > Column`
children become: `_buildFeeBreakdown(cart, t)`, `const SizedBox(height: 16)`, the button
`SizedBox`.

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/features/checkout/presentation/checkout_page.dart`
Expected: 0 errors (2 pre-existing `Radio` infos). If `remainingForFree`/`freeShippingProgress`
are now unused in `_buildBottomBar`, delete those two lines from `_buildBottomBar`.

- [ ] **Step 4: Commit**

```bash
git add lib/features/checkout/presentation/checkout_page.dart
git commit -m "refactor(checkout): extract reusable _buildFeeBreakdown"
```

---

## Task 5: Wizard scaffolding — step state, header, IndexedStack body, step bodies

Rework `build()`'s `data` branch into `header + IndexedStack + wizard bottom bar`, reusing the
existing section builders. This task adds the step bodies and header; Task 6 adds the new bottom
bar and deletes the old dialog/checklist.

**Files:**
- Modify: `lib/features/checkout/presentation/checkout_page.dart`

- [ ] **Step 1: Add the step state field and import**

Add the import near the other util imports:

```dart
import '../utils/checkout_wizard.dart';
```

Add to `_CheckoutPageState` (near `_isGpsOnly`):

```dart
int _currentStep = 0; // 0 Address+Contact, 1 Items+Delivery+Payment, 2 Review
```

- [ ] **Step 2: Add the step header**

```dart
Widget _buildStepHeader() {
  return Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        for (final step in kCheckoutSteps) ...[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: step.index <= _currentStep
                    ? const Color(0xFF1A237E)
                    : Colors.grey.shade300,
                child: step.index < _currentStep
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text('${step.index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: step.index <= _currentStep
                              ? Colors.white
                              : Colors.grey.shade600,
                        )),
              ),
              const SizedBox(height: 4),
              Text(step.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: step.index == _currentStep
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: step.index <= _currentStep
                        ? const Color(0xFF1A237E)
                        : Colors.grey.shade500,
                  )),
            ],
          ),
          if (step.index != kCheckoutSteps.last.index)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 16),
                color: step.index < _currentStep
                    ? const Color(0xFF1A237E)
                    : Colors.grey.shade300,
              ),
            ),
        ],
      ],
    ),
  );
}
```

- [ ] **Step 3: Add the three step bodies**

Reuse the exact section builders that are currently listed in `build()`'s Column.

```dart
Widget _buildStep1(UserProfileState profile) {
  return SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Delivery Address', Icons.place_outlined),
        _buildAddressSection(profile.addresses),
        const SizedBox(height: 24),
        _buildSectionTitle('Contact Info', Icons.person_outline),
        _buildContactInfoSection(),
      ],
    ),
  );
}

Widget _buildStep2(CartModel cart, CheckoutTotals totals) {
  final vendorMuni =
      cart.items.isNotEmpty ? (cart.items.first.location?.city ?? '') : '';
  return SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Order Items', Icons.shopping_bag_outlined),
        _buildOrderSummary(cart),
        const SizedBox(height: 24),
        if (vendorMuni.isNotEmpty)
          DynamicFeeBanner(orderTotal: cart.subtotal, municipality: vendorMuni),
        _buildSectionTitle('Delivery Option', Icons.local_shipping_outlined),
        _buildDeliveryTypeSection(cart),
        const SizedBox(height: 24),
        PromoCodeWidget(orderTotal: cart.subtotal),
        const SizedBox(height: 24),
        _buildSectionTitle('Payment', Icons.payment_outlined),
        _buildPaymentMethodSection(),
      ],
    ),
  );
}

Widget _buildStep3(CartModel cart, CheckoutTotals totals) {
  final deliveryLabel = switch (_selectedDeliveryType) {
    'standard' => '🚶 Standard',
    'express' => '🏍️ Express',
    'heavy_express' => '🚛 Heavy Express',
    'bulk' => '📦 Bulk',
    'pasabay' => '🤝 Pasabay',
    _ => _selectedDeliveryType,
  };
  return SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReviewCard(
          title: 'Delivery Address',
          onEdit: () => setState(() => _currentStep = 0),
          child: Text(
            '${_nameController.text.trim()} · ${_phoneController.text.trim()}\n'
            '${_selectedAddress?.street ?? ""}, ${_selectedAddress?.barangay ?? ""}, '
            '${_selectedAddress?.city ?? ""}',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        _buildReviewCard(
          title: 'Delivery Method',
          onEdit: () => setState(() => _currentStep = 1),
          child: Text(deliveryLabel, style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(height: 12),
        _buildSectionTitle('Order Items', Icons.shopping_bag_outlined),
        _buildOrderSummary(cart),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: _buildFeeBreakdown(cart, totals),
        ),
      ],
    ),
  );
}

Widget _buildReviewCard({
  required String title,
  required Widget child,
  required VoidCallback onEdit,
}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2C3E50))),
            TextButton(onPressed: onEdit, child: const Text('Edit')),
          ],
        ),
        const SizedBox(height: 4),
        child,
      ],
    ),
  );
}
```

- [ ] **Step 4: Rewire `build()`'s data branch to the wizard shell**

Replace the returned `Stack( SingleChildScrollView(...), Positioned(... _buildBottomBar) )` (the
whole widget returned from the inner `profileAsync.when` `data:` callback) with:

```dart
final totals = _computeCheckoutTotals(cart);
return Column(
  children: [
    _buildStepHeader(),
    Expanded(
      child: IndexedStack(
        index: _currentStep,
        children: [
          _buildStep1(profile),
          _buildStep2(cart, totals),
          _buildStep3(cart, totals),
        ],
      ),
    ),
    _buildWizardBottomBar(cart, totals),
  ],
);
```

`_buildWizardBottomBar` is added in Task 6 — this step will not compile until then; that's fine
for a subagent doing Tasks 5+6 together, otherwise stub it as
`Widget _buildWizardBottomBar(CartModel cart, CheckoutTotals totals) => const SizedBox.shrink();`
and replace it in Task 6.

- [ ] **Step 5: Add the stub bottom bar (temporary)**

```dart
Widget _buildWizardBottomBar(CartModel cart, CheckoutTotals totals) =>
    const SizedBox.shrink();
```

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/checkout/presentation/checkout_page.dart`
Expected: 0 errors. Unused-method warnings for `_buildBottomBar` / `_buildChecklistGuide` /
`_showOrderConfirmation` are expected here — they are removed in Task 6.

- [ ] **Step 7: Commit**

```bash
git add lib/features/checkout/presentation/checkout_page.dart
git commit -m "feat(checkout): wizard shell — step header, IndexedStack, step bodies"
```

---

## Task 6: Wizard bottom bar (Back/Next/Place Order) + delete dead UI

Replace the stub bar with a real Back/Next/Place-Order bar, then remove the now-dead popup dialog,
checklist, and old bottom bar.

**Files:**
- Modify: `lib/features/checkout/presentation/checkout_page.dart`

- [ ] **Step 1: Implement `_buildWizardBottomBar`**

Replace the stub with:

```dart
Widget _buildWizardBottomBar(CartModel cart, CheckoutTotals totals) {
  final isLast = _currentStep == kCheckoutSteps.last.index;
  final canAdvance = _currentStep == 0 ? _isStep1Valid() : true;
  final primaryEnabled = isLast
      ? (_canPlaceOrder() && !_isProcessing)
      : canAdvance;

  return Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 10,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              Text(formatMoney(totals.total),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => setState(() => _currentStep -= 1),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back'),
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: primaryEnabled
                      ? (isLast
                          ? _placeOrder
                          : () => setState(() => _currentStep += 1))
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(isLast ? 'Place Order' : 'Next',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

bool _isStep1Valid() => checkoutStep1Valid(
      city: _selectedAddress?.city,
      street: _selectedAddress?.street,
      barangay: _selectedAddress?.barangay,
      name: _nameController.text,
      phone: _phoneController.text,
    );
```

- [ ] **Step 2: Delete the dead methods**

Delete these methods entirely from `checkout_page.dart` (they are no longer referenced):
- `_buildBottomBar` (the old one)
- `_showOrderConfirmation`
- `_buildConfirmRow`
- `_buildChecklistGuide`
- `_buildCheckItem`

Keep: `_buildFeeBreakdown`, `_buildSummaryRow`, `_showFeeBreakdown`, `_canPlaceOrder`,
`_placeOrder`, `_computeCheckoutTotals`, and all section builders.

- [ ] **Step 3: Analyze — must be clean**

Run: `flutter analyze lib/features/checkout/presentation/checkout_page.dart`
Expected: 0 errors, 0 warnings (2 pre-existing `Radio` infos only). If any "unused element"
warning remains, delete that method too.

- [ ] **Step 4: Full app analyze**

Run: `flutter analyze lib`
Expected: 0 errors (pre-existing infos only).

- [ ] **Step 5: Commit**

```bash
git add lib/features/checkout/presentation/checkout_page.dart
git commit -m "feat(checkout): Back/Next/Place-Order wizard bar; remove popup + checklist"
```

---

## Task 7: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full frontend test suite**

Run: `flutter test`
Expected: All pass except the known pre-existing boilerplate `widget_test.dart` counter failure
(documented in CLAUDE.md as the "1 pre-existing boilerplate fail"). The new
`location_capture_test.dart` and `checkout_wizard_test.dart` pass.

- [ ] **Step 2: Analyze the whole lib**

Run: `flutter analyze lib`
Expected: 0 errors / 0 warnings (only pre-existing infos).

- [ ] **Step 3: Manual QA checklist (record results; needs a device/browser — not runnable here)**

- Step 1 → Next disabled until saved OR GPS address complete + name + valid phone.
- GPS mode: with device location OFF, tap GPS → friendly "Location services are off" message,
  stays in GPS mode (no crash, no infinite spinner).
- Step 2 → Next always available; delivery type + payment persist when going Back then Next.
- Step 3 → review shows correct address/contact/method/items and the same Total as the bar; Edit
  links jump to steps 1/2; Place Order creates the order and routes to confirmation.

- [ ] **Step 4: Final commit (if any QA tweaks)**

```bash
git add -A
git commit -m "chore(checkout): wizard QA follow-ups"
```

---

## Notes for the implementer

- **Rule #1 (Riverpod):** all state is already `setState`-based inside this one page widget; keep
  the existing pattern (the page is a `ConsumerStatefulWidget` — do not introduce new providers).
- **Rule #15 (token efficiency):** show only changed lines when reporting.
- `formatMoney` is imported from `trenda_shared` already at the top of the file.
- Do NOT change `_placeOrder`, the `CheckoutRequest` payload, or any fee/pasabay logic — the wizard
  only reorganizes when sections are visible.
- If a subagent executes Task 5 and Task 6 separately, use the Task-5 stub bar so each task compiles.
