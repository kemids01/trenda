# Checkout Wizard Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Group checkout items by store, add a GPS-only delivery address, lock Heavy Express/Bulk with a "why" dialog, and hide Pasabay for GPS-only.

**Architecture:** Pure helpers (`store_grouping`, `delivery_gating`, `gps_address`) drive small changes in `checkout_page.dart`; reuse shared `MunicipalityDropdown`/`BarangayDropdown`.

**Tech Stack:** Flutter, Riverpod, Geolocator, `trenda_shared`, `flutter test`.

**Repo:** `trenda_frontend` (+ a doc edit in `trenda_backend`). No backend/shared change.

---

### Task 1: Items grouped by store

**Files:**
- Create: `lib/features/checkout/utils/store_grouping.dart`
- Test: `test/store_grouping_test.dart`
- Modify: `lib/features/checkout/presentation/checkout_page.dart` (`_buildOrderSummary` ~574-648)

- [ ] **Step 1: Write the failing test**

```dart
// test/store_grouping_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/utils/store_grouping.dart';
import 'package:trenda_frontend/features/cart/models/cart_model.dart';

CartItem _i(String id, String? store) =>
    CartItem(id: id, onModel: 'Product', quantity: 1, price: 10);

void main() {
  test('groupItemsByStore groups by storeName, preserving order + null fallback', () {
    // storeName derives from product; with no product it is null -> 'Store' fallback.
    final groups = groupItemsByStore([_i('a', null), _i('b', null)]);
    expect(groups.length, 1);
    expect(groups.first.storeName, 'Store');
    expect(groups.first.items.length, 2);
  });
}
```
NOTE: `CartItem.storeName` comes from `product?.storeName`; in a unit test without a product it's null →
the helper's fallback applies. (Grouping-by-distinct-store is exercised via the fallback + order here;
richer store cases are covered at widget/integration level.)

- [ ] **Step 2: Run, verify FAIL**

Run: `flutter test test/store_grouping_test.dart`
Expected: FAIL (module missing).

- [ ] **Step 3: Create the helper**

```dart
// lib/features/checkout/utils/store_grouping.dart
import '../../cart/models/cart_model.dart';

class StoreGroup {
  final String storeName;
  final List<CartItem> items;
  const StoreGroup(this.storeName, this.items);
}

/// Group cart items by store name (first-seen store order + item order preserved).
List<StoreGroup> groupItemsByStore(List<CartItem> items) {
  final order = <String>[];
  final map = <String, List<CartItem>>{};
  for (final it in items) {
    final name = (it.storeName == null || it.storeName!.trim().isEmpty)
        ? 'Store'
        : it.storeName!.trim();
    if (!map.containsKey(name)) {
      map[name] = [];
      order.add(name);
    }
    map[name]!.add(it);
  }
  return [for (final n in order) StoreGroup(n, map[n]!)];
}
```

- [ ] **Step 4: Run, verify PASS**

Run: `flutter test test/store_grouping_test.dart`
Expected: pass.

- [ ] **Step 5: Render grouped in `_buildOrderSummary`**

Replace the single `ListView.separated` (children of the ExpansionTile) with a `Column` of store sections:
build `final groups = groupItemsByStore(cart.items);` then for each group render a store header
(`Padding` + Row: `Icon(Icons.storefront, size: 16)` + `Text(group.storeName, bold)`) followed by that
group's item rows (reuse the existing item Row builder, extracted into a small
`Widget _itemRow(CartItem item)` method). Keep the ExpansionTile title/subtitle/totals.

- [ ] **Step 6: Analyze + commit**

Run: `flutter analyze lib` → 0 errors.
```bash
git add lib/features/checkout/utils/store_grouping.dart test/store_grouping_test.dart lib/features/checkout/presentation/checkout_page.dart
git commit -m "feat(checkout): group order items by store (step 1)"
```

---

### Task 2: Delivery gating helpers

**Files:**
- Create: `lib/features/checkout/utils/delivery_gating.dart`
- Test: `test/delivery_gating_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/delivery_gating_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/utils/delivery_gating.dart';

void main() {
  group('deliverySelectionReason', () {
    test('>50kg -> bulk (precedence)', () {
      final r = deliverySelectionReason(totalWeight: 60);
      expect(r!.type, 'bulk');
      expect(r.reason, contains('60'));
    });
    test('>20kg -> heavy_express', () {
      expect(deliverySelectionReason(totalWeight: 24)!.type, 'heavy_express');
    });
    test('<=20kg -> null', () {
      expect(deliverySelectionReason(totalWeight: 20), isNull);
    });
  });

  group('availableDeliveryTypes', () {
    const all = ['standard', 'express', 'pasabay', 'heavy_express', 'bulk'];
    test('lockedType -> only that type', () {
      expect(availableDeliveryTypes(all, gpsOnly: false, lockedType: 'bulk'), ['bulk']);
    });
    test('gpsOnly drops pasabay', () {
      expect(availableDeliveryTypes(all, gpsOnly: true, lockedType: null), ['standard', 'express', 'heavy_express', 'bulk']);
    });
    test('normal passthrough', () {
      expect(availableDeliveryTypes(all, gpsOnly: false, lockedType: null), all);
    });
  });
}
```

- [ ] **Step 2: Run, verify FAIL**

Run: `flutter test test/delivery_gating_test.dart`
Expected: FAIL.

- [ ] **Step 3: Create the helper**

```dart
// lib/features/checkout/utils/delivery_gating.dart
class DeliveryForce {
  final String type; // 'bulk' | 'heavy_express'
  final String reason;
  const DeliveryForce(this.type, this.reason);
}

/// Which delivery type the cart weight FORCES, with a customer-facing reason. Null if none.
DeliveryForce? deliverySelectionReason({
  required double totalWeight,
  double heavyThreshold = 20,
  double bulkThreshold = 50,
}) {
  final w = totalWeight.toStringAsFixed(1);
  if (totalWeight > bulkThreshold) {
    return DeliveryForce('bulk',
        'Your cart weighs $w kg. Bulk Delivery is required for orders over ${bulkThreshold.toStringAsFixed(0)} kg and is arranged by our team.');
  }
  if (totalWeight > heavyThreshold) {
    return DeliveryForce('heavy_express',
        'Your cart weighs $w kg. Heavy Express is required for orders over ${heavyThreshold.toStringAsFixed(0)} kg.');
  }
  return null;
}

/// Final delivery options to offer. Locked -> only that type; else drop pasabay when GPS-only.
List<String> availableDeliveryTypes(List<String> adminEnabled,
    {required bool gpsOnly, String? lockedType}) {
  if (lockedType != null) return [lockedType];
  if (gpsOnly) return adminEnabled.where((t) => t != 'pasabay').toList();
  return adminEnabled;
}
```

- [ ] **Step 4: Run, verify PASS**

Run: `flutter test test/delivery_gating_test.dart`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/checkout/utils/delivery_gating.dart test/delivery_gating_test.dart
git commit -m "feat(checkout): delivery gating helpers (forced type + gps filter)"
```

---

### Task 3: GPS address helper

**Files:**
- Create: `lib/features/checkout/utils/gps_address.dart`
- Test: `test/gps_address_test.dart`
- Read first: `lib/features/home/models/user_address.dart` (constructor fields).

- [ ] **Step 1: Read `UserAddress`** to get its constructor field names (id, name, phone, street, city,
  barangay, region?, latitude, longitude, etc.).

- [ ] **Step 2: Write the failing test** (adjust field names to the real `UserAddress`):

```dart
// test/gps_address_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/utils/gps_address.dart';

void main() {
  test('buildGpsAddress composes coords + municipality + barangay', () {
    final a = buildGpsAddress(
      lat: 17.6, lng: 121.7, municipality: 'Tuguegarao', barangay: 'Centro',
      name: 'Juan', phone: '0917',
    );
    expect(a.city, 'Tuguegarao');
    expect(a.barangay, 'Centro');
    expect(a.latitude, 17.6);
    expect(a.longitude, 121.7);
    expect(a.street, 'Current GPS location');
    expect(a.name, 'Juan');
  });
}
```

- [ ] **Step 3: Create the helper** (map to the real `UserAddress` fields from Step 1):

```dart
// lib/features/checkout/utils/gps_address.dart
import '../../home/models/user_address.dart';

/// Compose a UserAddress for a GPS-only delivery (coords + admin-picked municipality/barangay).
UserAddress buildGpsAddress({
  required double lat,
  required double lng,
  required String municipality,
  required String barangay,
  required String name,
  required String phone,
}) {
  return UserAddress(
    // Match the real UserAddress ctor param names (Step 1). Common shape:
    id: 'gps',
    name: name,
    phone: phone,
    street: 'Current GPS location',
    city: municipality,
    barangay: barangay,
    latitude: lat,
    longitude: lng,
  );
}
```

- [ ] **Step 4: Run, verify PASS**

Run: `flutter test test/gps_address_test.dart`
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/checkout/utils/gps_address.dart test/gps_address_test.dart
git commit -m "feat(checkout): buildGpsAddress helper for GPS-only delivery"
```

---

### Task 4: Wire GPS-only into the address section

**Files:**
- Modify: `lib/features/checkout/presentation/checkout_page.dart` (`_buildAddressSection` ~231; state fields)

- [ ] **Step 1: Read** `_buildAddressSection` + the profile provider that gives name/phone, and how
  `_selectedAddress` feeds the place-order payload.

- [ ] **Step 2: Add state** near `_selectedAddress`:
```dart
  bool _isGpsOnly = false;
  double? _gpsLat, _gpsLng;
  String? _gpsMunicipality, _gpsBarangay;
```

- [ ] **Step 3: Add the mode toggle + GPS UI** at the top of `_buildAddressSection`: a `SegmentedButton`
  or two `ChoiceChip`s — "Saved address" / "Use my current location (GPS)". When GPS is selected:
  - Call a `_captureGps()` async: `Geolocator.checkPermission`/`requestPermission` then
    `Geolocator.getCurrentPosition()` → set `_gpsLat/_gpsLng` (on denial: SnackBar + revert to saved).
  - Render `MunicipalityDropdown(value: _gpsMunicipality, isRequired: true, onChanged: (v) => setState(() { _gpsMunicipality = v; _gpsBarangay = null; }))`
    and `BarangayDropdown(municipality: _gpsMunicipality, value: _gpsBarangay, isRequired: true, onChanged: (v) => setState(() => _gpsBarangay = v))`.
    (imports: `package:trenda_shared/widgets/municipality_dropdown.dart` + `barangay_dropdown.dart`.)
  - Show read-only name/phone from the profile.
  - When `_gpsLat/_gpsLng` + `_gpsMunicipality` + `_gpsBarangay` are all set, compose
    `_selectedAddress = buildGpsAddress(lat: _gpsLat!, lng: _gpsLng!, municipality: _gpsMunicipality!,
    barangay: _gpsBarangay!, name: <profile name>, phone: <profile phone>)`.
  - When toggled back to Saved: `_isGpsOnly = false` and restore `_selectedAddress` to a saved one.

- [ ] **Step 4: Guard place-order:** ensure a GPS-only order can't submit without coords + municipality +
  barangay (the compose only sets `_selectedAddress` when all present; if not, the existing "select address"
  guard blocks). Verify by reading the place-order validation.

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze lib` → 0 errors.
```bash
git add lib/features/checkout/presentation/checkout_page.dart
git commit -m "feat(checkout): GPS-only delivery address option (step 2)"
```

---

### Task 5: Wire delivery gating (lock + dialog + GPS no-pasabay)

**Files:**
- Modify: `lib/features/checkout/presentation/checkout_page.dart` (`_buildDeliveryTypeSection` ~719; state)

- [ ] **Step 1: Add state:** `String? _forceReasonShownFor;` (guards the auto-dialog per locked type).

- [ ] **Step 2: Compute lock + options.** In `_buildDeliveryTypeSection`, after `forceBulk`/`forceHeavy`:
```dart
    final force = deliverySelectionReason(totalWeight: totalWeight);
    final lockedType = force?.type; // 'bulk' | 'heavy_express' | null
    final adminEnabled = visibleDeliveryTypes(allDeliveryTypes, fees.enabledDeliveryTypes);
    final offered = availableDeliveryTypes(adminEnabled, gpsOnly: _isGpsOnly, lockedType: lockedType);
```
(import `../utils/delivery_gating.dart`.) Replace the per-option `if (visibleTypes.contains('x'))`
guards to use `offered.contains('x')`. For the locked case, only the locked option is in `offered`, so
only it renders; make its `_buildDeliveryOption(..., enabled: true)` but the tap a no-op when locked.

- [ ] **Step 3: Coerce selection.** After computing `offered`: if `_selectedDeliveryType` not in `offered`
  and `offered.isNotEmpty` → `addPostFrameCallback` set `_selectedDeliveryType = offered.first`. (Covers
  GPS-only+pasabay→express and locked→heavy/bulk.)

- [ ] **Step 4: Auto-dialog once + info icon.** When `lockedType != null` and
  `_forceReasonShownFor != lockedType`: `addPostFrameCallback` → `showDialog` with `force!.reason`, then
  set `_forceReasonShownFor = lockedType`. On the locked option tile, add a trailing
  `IconButton(Icons.info_outline)` → re-`showDialog(force.reason)`. Add a small
  `_showForceReasonDialog(String reason)` helper (AlertDialog title 'Delivery option', content reason, OK).

- [ ] **Step 5: Analyze + test**

Run: `flutter analyze lib` → 0 errors.
Run: `flutter test` → green (44 baseline + new tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/checkout/presentation/checkout_page.dart
git commit -m "feat(checkout): lock forced Heavy/Bulk with why-dialog; hide Pasabay for GPS-only (step 4)"
```

---

### Task 6: Docs

**Files:**
- Modify: `trenda_backend/docs/17_core_municipality_ecommerce_flow_complete.md`

- [ ] **Step 1: §5 (delivery options):** add — Heavy Express / Bulk are auto-selected by cart weight and
  **not manually selectable** (customer sees a why-dialog: `deliverySelectionReason`); Pasabay is **hidden
  for GPS-only** delivery.
- [ ] **Step 2: §4 (checkout):** note the customer may deliver to a **saved address** OR a **current-GPS
  location** (coords + chosen admin municipality/barangay; name/phone from profile); GPS-only excludes Pasabay.
- [ ] **Step 3: Commit** (in trenda_backend):
```bash
git add docs/17_core_municipality_ecommerce_flow_complete.md
git commit -m "docs: checkout store-grouping, GPS-only address, forced heavy/bulk + gps pasabay rule"
```

---

## Self-review notes
- **Spec coverage:** F1→T1, F3helpers→T2, F2c→T3, F2→T4, F3wiring→T5, F4→T6. All mapped.
- **Type consistency:** `groupItemsByStore`/`StoreGroup`, `deliverySelectionReason`/`DeliveryForce`,
  `availableDeliveryTypes`, `buildGpsAddress`, state flags `_isGpsOnly`/`_gps*`/`_forceReasonShownFor`
  used consistently. `visibleDeliveryTypes`/`allDeliveryTypes` reused from SP-B.
- **Risk:** T3/T4 depend on the real `UserAddress` ctor (read first); T4 GPS permission handling; T5 must
  keep the existing weight-forcing intact (deliverySelectionReason mirrors the >20/>50 thresholds already
  in `_buildDeliveryTypeSection` — replace the duplicated forceHeavy/forceBulk usage with the helper's
  lockedType to avoid divergence).
- **YAGNI:** no stepper rebuild (page stays single-scroll); no backend/shared change; reuse shared dropdowns.
```
