# Spec 1b — Heavy auto-select by admin threshold + remove `bulk` from checkout

**Date:** 2026-08-21
**Repos:** `trenda_backend` (1-line add + test → commit **and push origin/main**, LIVE on Render) ·
`trenda_frontend` (checkout refactor → local `main` only, no push). No admin app change.
**Part of:** the Logistics epic (Spec 1 shipped the Heavy Delivery page with the editable
`heavyWeightThreshold`; this makes the customer app actually consume it).

## Goal
Heavy (`heavy_express`) is auto-selected and locked (never manually chosen) whenever cart weight
exceeds the **admin-configured** `heavyWeightThreshold` (set on the Heavy Delivery page), instead of a
hardcoded 20 kg. Remove the half-wired `bulk` delivery option from the customer checkout entirely
(it merged into Heavy platform-wide).

## Backend (`trenda_backend`)
`routes/publicDeliveryRoutes.js` → `GET /api/config/delivery-fees`: add one field to the response:
```js
heavyWeightThreshold: settings.heavyWeightThreshold,
```
The dormant `bulk` fee field stays in the response for now (harmless once the app ignores it; removed
in Spec 3's backend cleanup). Test: extend `test/integration/deliveryFeesNoStandard.test.js` (it already
seeds `heavyWeightThreshold = 999`) to assert the response carries `heavyWeightThreshold === 999`.

## Frontend (`trenda_frontend`)
1. **`data/checkout_repository.dart` `DeliveryFees`:**
   - Add `final double heavyWeightThreshold;` (default **20**), parsed from `json['heavyWeightThreshold']`.
   - Remove the `bulk` field, its constructor param + defaults, its `fromJson` parse, and the `'bulk'`
     cases in `getFeeForType` / `calculateDistanceBasedFee`.
   - Drop `'bulk'` from the default `enabledDeliveryTypes` (both the const default and the fromJson fallback).
2. **`utils/delivery_gating.dart` `deliverySelectionReason`:**
   - Delete the `bulk` branch and the `bulkThreshold` param. Keep only the heavy branch, driven by
     `heavyThreshold` (still defaulting to 20). Update the `DeliveryForce.type` doc comment to `'heavy_express'`.
3. **`presentation/checkout_page.dart`:**
   - Remove `_bulkWeightThreshold`, the `forceBulk` block, `'bulk'` from `allDeliveryTypes`, the Bulk
     option card (`offered.contains('bulk')`), the `'📦 Bulk'` `_buildStep3` label case, and the
     `'Bulk Delivery'` banner ternary (banner always reads **"Heavy Express auto-selected …"**).
   - Replace hardcoded `totalWeight > 20` with `totalWeight > fees.heavyWeightThreshold`.
   - Pass the admin threshold into the gate: `deliverySelectionReason(totalWeight: totalWeight,
     heavyThreshold: fees.heavyWeightThreshold)`.
4. **New test** `test/checkout/delivery_gating_test.dart` (trenda_frontend has no test dir yet — create it):
   pure `deliverySelectionReason` behavior — below threshold → null; above → `heavy_express` lock; custom
   threshold honored; no `bulk` ever returned.

## Decisions (locked)
- Customer-facing label stays **"Heavy Express"** (no copy churn).
- Threshold is **global** (single `DeliverySettings.heavyWeightThreshold`); per-muni/barangay is Spec 3.
- Comparison stays `>` (matches backend `weight > heavyWeightThreshold`).
- Admin pausing heavy while a cart exceeds threshold keeps today's force behavior; reconciling is Spec 3.

## Verification
- Backend: `node --experimental-vm-modules node_modules/jest/bin/jest.js test/integration/deliveryFeesNoStandard.test.js` green; then push origin/main.
- Frontend: `flutter test test/checkout/delivery_gating_test.dart` green; `flutter analyze lib` no new errors.
- Manual: cart under threshold → express/pasabay selectable; over threshold → Heavy Express locked banner, no Bulk option anywhere.

## Non-goals (Spec 3)
Backend `bulk` field removal; per-barangay/muni heavy threshold; pause-vs-force reconciliation.
