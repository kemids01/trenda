# Spec — Checkout Wizard Improvements (trenda_frontend)

**Date:** 2026-07-02
**Scope:** `trenda_frontend` checkout page + 2 small util files + tests; then update
`trenda_backend/docs/17_core_municipality_ecommerce_flow_complete.md`.
**Goal:** (1) group the items list by store name; (2) add a "GPS only" delivery-address option; (3) make
Heavy Express / Bulk auto-selected and non-manual with a "why" dialog; (4) hide Pasabay when GPS-only.
**Execution:** TDD for pure helpers, autonomous after this spec.

## Decisions (locked with user 2026-07-02)
- **GPS-only address:** capture current coordinates; customer picks municipality (admin
  `MunicipalityDropdown`) + barangay (`BarangayDropdown`); name/phone from profile; `street = "Current GPS
  location"`. No reverse-geocode dependency.
- **Forced type:** auto dialog once explaining why + a persistent info icon to reopen; other options
  disabled; the forced option cannot be changed.
- **GPS-only:** Pasabay is hidden; if selected, coerce to Express.

## Current state (grounded)
- Checkout is one scrolling page (`checkout_page.dart`), not a Stepper. Sections: order summary (items),
  address, delivery type, bottom bar/place-order.
- `_buildOrderSummary(cart)` (~574): flat `ListView` of `cart.items` (name/qty/price). `CartItem.storeName`
  getter exists.
- Address: `_selectedAddress` (`UserAddress?`), `_buildAddressSection(addresses)` (~231),
  `_showAddressSelector` (~403). Geolocator already used elsewhere.
- Delivery: `_buildDeliveryTypeSection(cart)` (~719) computes `forceBulk` (>50kg) / `forceHeavy` (>20kg)
  and already auto-selects them, but heavy/bulk options remain tappable. SP-B `visibleDeliveryTypes` +
  `enabledDeliveryTypes` filter options. Shared `MunicipalityDropdown`/`BarangayDropdown` available.

---

## Feature 1 — Items grouped by store

### F1a — Pure helper
`lib/features/checkout/utils/store_grouping.dart`:
`List<StoreGroup> groupItemsByStore(List<CartItem> items)` where
`class StoreGroup { final String storeName; final List<CartItem> items; }`. Groups by `storeName`
(fallback 'Store' when null/empty), preserving first-seen store order and item order. Pure/tested.

### F1b — Render
`_buildOrderSummary`: replace the flat list with per-store sections — a store-name header row
(store icon + name) then that store's item rows (existing row layout). Keep the ExpansionTile + totals.

---

## Feature 2 — GPS-only delivery address

### F2a — State + mode toggle
Add `bool _isGpsOnly = false;` and (for GPS) `double? _gpsLat, _gpsLng; String? _gpsMunicipality,
_gpsBarangay;`. In the address section, add a segmented/toggle: **"Saved address"** vs **"Use my current
location (GPS)"**.

### F2b — GPS capture + pickers
When GPS mode is chosen: request permission + `Geolocator.getCurrentPosition` → `_gpsLat/_gpsLng`
(show a loading/permission-denied message on failure). Render `MunicipalityDropdown(value: _gpsMunicipality,
onChanged: set + clear barangay)` + `BarangayDropdown(municipality: _gpsMunicipality, value: _gpsBarangay,
onChanged: set)`. Show name/phone (read-only) from the profile.

### F2c — Compose the address for submit
Add a pure helper `buildGpsAddress({lat, lng, municipality, barangay, name, phone})` →
`UserAddress` with `street: 'Current GPS location'`, `city/municipality`, `barangay`, `latitude`,
`longitude`, `name`, `phone`. On GPS mode with all fields set, set `_selectedAddress` to it. The existing
place-order path (reads `_selectedAddress`) is unchanged. (Read `UserAddress`'s fields first to match.)

---

## Feature 3 — Delivery gating

### F3a — Pure helpers
`lib/features/checkout/utils/delivery_gating.dart`:
- `DeliveryForce? deliverySelectionReason({required double totalWeight, double heavyThreshold = 20,
  double bulkThreshold = 50})` → `{type: 'bulk'|'heavy_express', reason: String}` or null.
  bulk (>bulkThreshold) takes precedence over heavy (>heavyThreshold). Reason text includes the weight,
  e.g. "Your cart weighs 24.0 kg. Heavy Express is required for orders over 20 kg."
- `List<String> availableDeliveryTypes(List<String> adminEnabled, {required bool gpsOnly,
  String? lockedType})` → if `lockedType != null` → `[lockedType]`; else `adminEnabled` minus `'pasabay'`
  when `gpsOnly`. (Composes with SP-B `visibleDeliveryTypes` which already intersects the known set.)

### F3b — Wire into `_buildDeliveryTypeSection`
- Compute `lockedType` from `forceBulk`/`forceHeavy`. Build the offered set via
  `availableDeliveryTypes(visibleFromAdmin, gpsOnly: _isGpsOnly, lockedType: lockedType)`.
- Render only those options; when `lockedType != null`, the locked option is selected and enabled, all
  others hidden/disabled; the locked tile shows an **info icon** → `_showForceReasonDialog(reason)`.
- **Auto dialog once:** when `lockedType` first becomes non-null for this cart, `addPostFrameCallback` →
  show the reason dialog once (guard with a `bool _forceReasonShown` keyed to the locked type).
- GPS-only: pasabay excluded (via `availableDeliveryTypes`); if `_selectedDeliveryType == 'pasabay'` and
  gpsOnly, coerce to `'express'`.

### Tests (F1a, F2c, F3a)
`test/store_grouping_test.dart`, `test/delivery_gating_test.dart`, `test/gps_address_test.dart`:
- `groupItemsByStore` groups + preserves order + null-store fallback.
- `deliverySelectionReason`: >50→bulk, >20→heavy, ≤20→null, boundary at exactly 20/50, bulk precedence.
- `availableDeliveryTypes`: lockedType→[locked]; gpsOnly drops pasabay; normal passthrough.
- `buildGpsAddress` sets street/coords/municipality/barangay from inputs.
- Widget-level (GPS capture, dialogs) verified via `flutter analyze lib` + suite (not unit-tested).

---

## Feature 4 — Docs
Update `trenda_backend/docs/17_core_municipality_ecommerce_flow_complete.md`:
- §5 (delivery options): Heavy Express / Bulk are **auto-selected by weight and NOT manually selectable**
  (customer sees a why-dialog); Pasabay is **hidden for GPS-only** delivery.
- §4 (checkout): the customer may deliver to a **saved address** OR a **current-GPS location** (coords +
  chosen municipality/barangay); GPS-only excludes Pasabay.

---

## Verification (definition of done)
- New unit tests green; `flutter analyze lib` 0 errors; suite green (44 baseline).
- Items grouped by store; GPS-only address composes a valid shippingAddress; forced heavy/bulk locked with
  a why-dialog; Pasabay hidden on GPS-only.
- Docs updated.

## Risks / notes
- **GPS permission / no coords:** if permission denied or coords unavailable, keep the customer on saved
  address and show a message; don't let a GPS-only order submit without coords + municipality + barangay.
- **Order requires** `shippingAddress.{name,phone,street,barangay}` — GPS-only fills all (name/phone from
  profile, street placeholder). Municipality drives the fee cascade/dispatch (§8).
- **Forced-type + GPS-only interaction:** locking (heavy/bulk) takes precedence in the options list; GPS
  pasabay-hiding only matters when not locked.
- Frontend-only; reuses shared dropdowns; no backend/shared change.
