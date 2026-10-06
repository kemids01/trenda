# Design — Delivery Fee-Preview Correctness [P7]

**Date:** 2026-06-28
**Repo:** trenda_frontend (customer app; client-only — no backend change)
**Scope:** P7 (delivery options). Fixes two correctness issues in the client-side delivery-fee preview shown
at checkout. (Switching to the server estimate endpoint is explicitly deferred.)

## Problem
The checkout delivery-option picker is mature (Standard / Express / Pasabay / Heavy Express / Bulk, with
weight + distance gating). Two concrete fee-preview bugs (in `features/checkout/data/checkout_repository.dart`
`DeliveryFees` + `features/checkout/presentation/checkout_page.dart`):

1. **`calculateDistanceBasedFee` ignores `bulk`.** Its switch handles `standard`/`express`/`heavy_express`
   (and short-circuits `pasabay` as flat), but `bulk` falls through to `base + extraKm·perKm` — ignoring
   the `bulk` estimate entirely. Currently masked because the checkout total excludes `bulk` from the
   distance branch (`_selectedDeliveryType != 'bulk'`), but it is a latent bug in a pure, reusable function.
2. **Heavy Express label vs. computed fee mismatch.** The option is labeled `For heavy items (₱{heavyExpress})`
   (reads flat), but when the address has coordinates the order total uses
   `calculateDistanceBasedFee(distance, 'heavy_express')` = `heavyExpress + extraKm·perKm` — so the summary
   line exceeds the labeled price. Misleading.

## Decision (from brainstorming)
- Make the pure fee math correct (`bulk` flat) and the Heavy Express label honest (`from ₱X`).
- Keep `express`/`standard`/`heavy_express` distance-based (consistent with the server §8 cascade); the
  bug is the **label**, not the math.
- Defer: using the server `/api/config/calculate-delivery-fee` estimate; the `CalculatedDeliveryFee.fallback`
  divergence (degraded API-failure path).

## Changes

### 1. `DeliveryFees.calculateDistanceBasedFee` — `checkout_repository.dart`
Flat-fee types short-circuit; distance types unchanged. Replace the leading `pasabay` short-circuit with:
```dart
    // Flat-fee types are distance-independent.
    if (deliveryType == 'pasabay') return pasabay;
    if (deliveryType == 'bulk') return bulk;
```
The rest (extraKm·perKm + per-type surcharge for standard/express/heavy_express, default `base + distance`)
is unchanged. Net effect: `bulk` now returns the flat `bulk` estimate (matching `getFeeForType('bulk')` and
the picker's "Est. ₱{bulk}" label).

### 2. Heavy Express label — `checkout_page.dart`
In `_buildDeliveryTypeSection`, change the heavy_express option description:
`'For heavy items (₱${fees.heavyExpress.toStringAsFixed(0)})'`
→ `'For heavy items (from ₱${fees.heavyExpress.toStringAsFixed(0)})'`
(consistent with Standard's "starts at ₱X" and Bulk's "Est. ₱X" honesty.)

## Testing
- `test/delivery_fees_test.dart` (pure, on `DeliveryFees`):
  - `getFeeForType`: standard→base, express→express, pasabay→pasabay, heavy_express→heavyExpress,
    bulk→bulk, unknown→base.
  - `calculateDistanceBasedFee` with a known `DeliveryFees` (base 50, perKm 10, baseDistance 1, express 80,
    heavyExpress 100, pasabay 20, bulk 200):
    - `pasabay` at any distance → 20 (flat).
    - `bulk` at any distance → 200 (flat).  ← the fix
    - `standard` at 1km → 50 (no extra); at 3km → 50 + 2·10 = 70.
    - `express` at 3km → 50 + 20 + (80−50) = 100.
    - `heavy_express` at 3km → 50 + 20 + (100−50) = 120.
    - unknown type at 3km → 50 + 20 = 70.
- `flutter analyze lib` → 0 errors. Full suite stays green (only the pre-existing boilerplate fail).

## Out of scope
- Server-estimate endpoint adoption; `CalculatedDeliveryFee.fallback` rework; backend/shared changes;
  weight/auto-selection logic (unchanged).
