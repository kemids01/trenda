# Delivery Fee-Preview Correctness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make the client-side delivery-fee preview correct — `bulk` returns its flat estimate in `calculateDistanceBasedFee`, and the Heavy Express picker label stops implying a flat price.

**Architecture:** Pure-logic fix in `DeliveryFees` (unit-tested) + one label string. Client-only; no backend.

**Tech Stack:** Flutter. Tests: `flutter test <path>`; analyze: `flutter analyze lib`. From `trenda_frontend`.

**Branch:** `feat/delivery-fee-preview` (already created; spec committed). Local-only repo.

**Verified anchors (2026-06-28):**
- `lib/features/checkout/data/checkout_repository.dart` — `class DeliveryFees` (~L382); `getFeeForType` (~L453);
  `calculateDistanceBasedFee` (~L472) — its first statement short-circuits `pasabay`:
  `if (deliveryType == 'pasabay') { return pasabay; }`.
- `lib/features/checkout/presentation/checkout_page.dart` — heavy_express option (~L909-914):
  `'For heavy items (₱${fees.heavyExpress.toStringAsFixed(0)})'`.

---

### Task 1: Fix the pure fee math + label (TDD)

**Files:**
- Modify: `lib/features/checkout/data/checkout_repository.dart`
- Modify: `lib/features/checkout/presentation/checkout_page.dart`
- Test: `test/delivery_fees_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/delivery_fees_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/data/checkout_repository.dart';

const _fees = DeliveryFees(
  express: 80, pasabay: 20, heavyExpress: 100, bulk: 200,
  base: 50, baseDistance: 1, perKm: 10,
);

void main() {
  group('getFeeForType', () {
    test('maps each type', () {
      expect(_fees.getFeeForType('standard'), 50);
      expect(_fees.getFeeForType('express'), 80);
      expect(_fees.getFeeForType('pasabay'), 20);
      expect(_fees.getFeeForType('heavy_express'), 100);
      expect(_fees.getFeeForType('bulk'), 200);
      expect(_fees.getFeeForType('mystery'), 50); // default -> base
    });
  });

  group('calculateDistanceBasedFee', () {
    test('flat types are distance-independent', () {
      expect(_fees.calculateDistanceBasedFee(0.5, 'pasabay'), 20);
      expect(_fees.calculateDistanceBasedFee(99, 'pasabay'), 20);
      expect(_fees.calculateDistanceBasedFee(0.5, 'bulk'), 200); // the fix
      expect(_fees.calculateDistanceBasedFee(99, 'bulk'), 200);
    });
    test('distance types add extra-km * perKm + surcharge', () {
      expect(_fees.calculateDistanceBasedFee(1, 'standard'), 50);   // no extra
      expect(_fees.calculateDistanceBasedFee(3, 'standard'), 70);   // +2km*10
      expect(_fees.calculateDistanceBasedFee(3, 'express'), 100);   // 50+20+(80-50)
      expect(_fees.calculateDistanceBasedFee(3, 'heavy_express'), 120); // 50+20+(100-50)
      expect(_fees.calculateDistanceBasedFee(3, 'mystery'), 70);    // base+distance, no surcharge
    });
  });
}
```

- [ ] **Step 2: Run it, confirm it fails**

Run: `flutter test test/delivery_fees_test.dart`
Expected: FAIL on the `bulk` cases (currently returns `base + distance` = e.g. `50` at 0.5km, not `200`).
(The other cases should already pass — they pin existing behavior.)

- [ ] **Step 3: Fix `calculateDistanceBasedFee`**

In `lib/features/checkout/data/checkout_repository.dart`, replace the leading pasabay short-circuit:
```dart
    // Pasabay is flat fee regardless of distance
    if (deliveryType == 'pasabay') {
      return pasabay;
    }
```
with both flat types:
```dart
    // Flat-fee types are distance-independent.
    if (deliveryType == 'pasabay') return pasabay;
    if (deliveryType == 'bulk') return bulk;
```
Leave the rest of the method (extra-km/perKm + per-type surcharge switch, `return base + distanceFee + surcharge`) unchanged.

- [ ] **Step 4: Run the test, confirm PASS.**

- [ ] **Step 5: Fix the Heavy Express label**

In `lib/features/checkout/presentation/checkout_page.dart`, the `_buildDeliveryOption('heavy_express', ...)` call (~L909-914), change the description argument:
`'For heavy items (₱${fees.heavyExpress.toStringAsFixed(0)})'`
→ `'For heavy items (from ₱${fees.heavyExpress.toStringAsFixed(0)})'`

- [ ] **Step 6: Analyze + commit**

Run: `flutter analyze lib/features/checkout` → 0 errors.
```bash
git add lib/features/checkout/data/checkout_repository.dart lib/features/checkout/presentation/checkout_page.dart test/delivery_fees_test.dart
git commit -m "fix(checkout): bulk flat in delivery fee calc + honest Heavy Express label (P7)"
```

---

### Task 2: Verify + finish

**Files:** none (verification).

- [ ] **Step 1:** `flutter analyze lib` → 0 errors.
- [ ] **Step 2:** `flutter test` → the new `delivery_fees_test.dart` passes; only the pre-existing boilerplate `widget_test.dart` fail remains; no NEW failures.
- [ ] **Step 3:** Finish the branch via `superpowers:finishing-a-development-branch` — merge `--no-ff` into local `main`, delete `feat/delivery-fee-preview`. Update CLAUDE.md §17 with a concise P7-done entry (note deferred: server-estimate adoption; `CalculatedDeliveryFee.fallback` divergence).

---

## Self-review checklist
- Spec coverage: bulk flat in `calculateDistanceBasedFee` + honest heavy label + pure tests (T1); verify + finish (T2). ✓
- Test math matches the method (base50/perKm10/baseDistance1): standard@3=70, express@3=100, heavy@3=120, bulk flat 200, pasabay flat 20. ✓
- No backend/shared change → rule #7 N/A. ✓
