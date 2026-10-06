# Trenda Delivery Options — Full Flow, Examples & Scenarios

**Audience:** engineers + ops. **As-built** as of 2026-06-28 (includes the P7 fee-preview fix).
**Sources:** `trenda_frontend/lib/features/checkout/{presentation/checkout_page.dart,data/checkout_repository.dart}`,
`trenda_backend/controllers/checkoutController.js`, `trenda_backend/models/Order.js`, CLAUDE.md §8.

> **One sentence:** the customer picks a delivery option at checkout (some auto-selected by weight/distance);
> the app shows a **client-side estimate**; the **backend §8 cascade is authoritative** for the charged fee.

---

## 1. The five delivery options

| Option | `deliveryType` | When it's for | Fee model (client estimate) | Picker label |
|---|---|---|---|---|
| **Standard** | `standard`* | Nearby orders (≤ 1km, all vendors) | flat **base** (₱50 default), distance-gated | "Standard Delivery — Within 1km only (starts at ₱base)" |
| **Express** | `express` | Priority/fast | **base + extra-km×perKm + ₱30** surcharge | "Express Delivery — Priority delivery (+₱surcharge)" |
| **Pasabay** | `pasabay` | Cost-saving, batched with neighbors | **flat ₱20** (distance-independent) | "Pasabay (Recommended) — save up to 70%" (default) |
| **Heavy Express** | `heavy_express` | Heavy items (> 20kg) | **base + extra-km×perKm + ₱50** surcharge | "Heavy Express — For heavy items (from ₱heavyExpress)" |
| **Bulk** | `bulk` | Large/heavy orders (> 50kg) | **flat estimate ₱200**; final fee confirmed by ops | "Bulk Delivery — Est. ₱bulk; final fee confirmed before dispatch" |

\* `standard` is a client/legacy type; the backend treats `standard` as an alias for `express`
(`checkoutController` normalizes `'standard' → 'express'`). The backend's valid set is
`['express','pasabay','heavy_express','bulk']`.

**Default selection:** `pasabay` (labelled "Recommended").

---

## 2. Fee configuration (client defaults — `DeliveryFees.defaults()`)

These come from `GET /api/config/delivery-fees` (override-aware §8 cascade); the values below are the
client fallback defaults when the API is unavailable.

| Field | Default | Meaning |
|---|---|---|
| `base` | ₱50 | base fee (covers up to `baseDistance`) |
| `baseDistance` | 1 km | distance included in the base fee |
| `perKm` | ₱10 | charged per km beyond `baseDistance` |
| `express` | ₱80 | express fee at base distance (→ ₱30 surcharge over base) |
| `pasabay` | ₱20 | flat pasabay fee |
| `heavyExpress` | ₱100 | heavy express fee at base distance (→ ₱50 surcharge over base) |
| `bulk` | ₱200 | flat bulk estimate |
| `expressSurcharge` | ₱30 | |
| `heavySurcharge` | ₱50 | |
| `crossMunicipalitySurcharge` | ₱100 | added when crossing municipalities |
| `freeDeliveryThreshold` | ₱1000 | (when free delivery enabled) order total that zeroes the fee |

---

## 3. Fee formulas (`DeliveryFees`)

**`getFeeForType(type)`** — fee at base distance: `standard→base`, `express→express`, `pasabay→pasabay`,
`heavy_express→heavyExpress`, `bulk→bulk`, unknown→`base`.

**`calculateDistanceBasedFee(distanceKm, type)`** — the fee shown in the order summary when the address has
coordinates:
- **Flat types** (distance-independent): `pasabay → pasabay`, `bulk → bulk`.
- **Distance types**: `base + extraKm·perKm + surcharge`, where
  `extraKm = max(0, distanceKm − baseDistance)` and
  `surcharge`: `standard → 0`, `express → express − base`, `heavy_express → heavyExpress − base`.
- **Unknown type** → `base + extraKm·perKm` (no surcharge).

> **P7 fix:** before this fix, `bulk` fell through to `base + distance` (wrong); it is now flat `bulk`.
> The Heavy Express label now says **"from ₱X"** because distance is added on top of `heavyExpress`.

---

## 4. Auto-selection & gating (checkout, `_buildDeliveryTypeSection`)

`totalWeight = Σ (item.weight ?? 0.5kg) × quantity`. `maxVendorDistance` = farthest cart vendor (Haversine).

1. **Bulk auto-select:** `totalWeight > 50kg` → force `bulk` (takes precedence). Bulk is excluded from the
   distance calc (uses the flat estimate; ops confirm the final fee).
2. **Heavy auto-select:** `totalWeight > 20kg` (and not bulk) → force `heavy_express`. While forced heavy,
   Standard/Express/Pasabay are disabled.
3. **Standard gating:** Standard is enabled only if **every** cart vendor is within **1.0 km**
   (`standardEnabled = maxVendorDistance ≤ 1.0`). If Standard is disabled and the user had it selected and
   weight isn't heavy → selection coerces to `express`.
4. **Pasabay** shows a batch selector + a per-barangay fee preview (`pasabayFeePreviewProvider`).

**Server enforcement** (`checkoutController.createOrder`, authoritative):
- `deliveryType` must be in `['express','pasabay','heavy_express','bulk']` (`standard`→`express`).
- **Pasabay rejected when `totalWeight ≥ 50kg`.**
- `totalWeight ≥ 30kg` must use `heavy_express` or `bulk` (lighter types rejected).
- Final charged fee = §8 cascade (MunicipalityFees override → DeliverySettings zone → global), not the
  client estimate. The client number is an **estimate/preview**.

---

## 5. Vehicle auto-assignment (backend `Order.js`)

Independent of `deliveryType`, the order's `vehicleType` is assigned by weight:
`> 300kg → truck`, `> 20kg → van/car`, else `motorcycle` (default; `bicycle` also possible).

---

## 6. Worked examples (using client defaults: base 50, perKm 10, baseDistance 1km, +₱30 express, +₱50 heavy)

| # | Cart | Distance | Auto / chosen | Estimated shipping |
|---|---|---|---|---|
| 1 | 2kg, single vendor 0.6km | 0.6 km | Standard available → **Standard** | **₱50** (within base distance) |
| 2 | 2kg, vendor 3km | 3 km | Standard disabled (>1km) → **Express** | 50 + (2×10) + 30 = **₱100** |
| 3 | 2kg, vendor 3km | 3 km | **Pasabay** (default) | **₱20** (flat) |
| 4 | 25kg, vendor 4km | 4 km | weight>20 → **Heavy Express** (forced) | 50 + (3×10) + 50 = **₱130** (label "from ₱100") |
| 5 | 60kg | any | weight>50 → **Bulk** (forced) | **₱200** estimate (ops confirm final) |
| 6 | 2kg, vendor 0.8km, total ₱1200, free-delivery enabled | 0.8 km | Standard | **₱0** (order ≥ ₱1000 threshold) |
| 7 | 2kg, vendor in next municipality 5km | 5 km | Express | 50 + (4×10) + 30 = ₱120 **+ ₱100 cross-municipality** = **₱220** |

> Examples are the **client estimate**. The receipt fee is the server §8 cascade and may differ when a
> municipality has fee overrides.

---

## 7. Scenarios (end-to-end)

**S1 — Neighbor pasabay (the happy path Trenda promotes).**
Customer 1.5km from vendor, 3kg cart, leaves the default **Pasabay**. Estimate ₱20. At checkout the order
joins a barangay batch; `pasabayFeePreviewProvider` shows the batched fee. Backend accepts (weight < 50kg).
Rider delivers with other batch orders.

**S2 — Out-of-range standard.**
Customer 2.3km away selects Standard. `standardEnabled=false` (>1km) → selection auto-switches to **Express**;
a hint explains "Standard available within 1km only". Estimate uses the express distance formula.

**S3 — Heavy item.**
Customer adds a 25kg appliance. Checkout auto-forces **Heavy Express** and disables the lighter options.
Picker shows "from ₱100"; the summary shows the distance-adjusted total (e.g. ₱130 at 4km). Backend requires
heavy_express/bulk for ≥30kg, so the choice is accepted; vehicle auto-assigned **van/car** (>20kg).

**S4 — Bulk order.**
Customer orders 60kg of goods. Checkout auto-forces **Bulk** (>50kg), excludes it from distance math, shows
the **flat ₱200 estimate** with "final fee confirmed before dispatch". Backend rejects pasabay/light types
(≥50kg → not pasabay; ≥30kg → heavy/bulk only). Ops arrange dispatch; vehicle may be **truck** (>300kg) or
van. The customer is told the final fee is confirmed before dispatch.

**S5 — Closed store (interaction with P2).**
If a cart store is closed, checkout blocks the order regardless of delivery option (server rejects;
client shows the closed-store dialog) — delivery options don't override store availability.

**S6 — API down (degraded).**
`GET /api/config/delivery-fees` fails → `DeliveryFees.defaults()` is used for the estimate, and a per-type
`CalculatedDeliveryFee.fallback` provides a coarse number. The order still submits; the backend computes the
authoritative fee.

---

## 8. Fee source (updated 2026-06-29 — #1 distance-based pricing)
- The checkout now displays the **authoritative** server fee via `checkoutFeeProvider` →
  `POST /api/config/calculate-delivery-fee`, which runs the distance-inclusive §8 cascade — **the same
  number the order is charged**. The local `DeliveryFees` formula is kept only as the **offline
  fallback** (loading/error). The fee is priced off the **farthest** cart vendor (`farthestVendor`).
- The delivery fee is now genuinely **distance-based** end-to-end (backend cascade gained
  `perKmFee`/`baseDistanceKm`, override-aware, all types).
- Free-delivery zeroing still applies only when `freeDeliveryEnabled` is set in config.
- **Remaining:** the pasabay batch-preview `normalFee` at two secondary sites still uses the local
  estimate; `CalculatedDeliveryFee.fallback` amounts can still diverge in the offline path.
