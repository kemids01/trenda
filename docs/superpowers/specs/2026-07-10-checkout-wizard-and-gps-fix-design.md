# Customer Checkout Wizard + GPS Capture Fix — Design

Date: 2026-07-10
App: `trenda_frontend` (Customer App)
Primary file: `lib/features/checkout/presentation/checkout_page.dart` (~2750 lines)

## Problem

1. **Checkout is a single long scrolling page**, not the step wizard the product intent
   called for. Everything (address, contact, items, payment, delivery, promo) lives in one
   `SingleChildScrollView`, with an orange checklist guide at the top and a "Confirm Order"
   popup dialog on Place Order.
2. **GPS capture is buggy** (already fixed this session — documented here for completeness):
   - `_captureGps()` (GPS-only address mode) had **no location-services-enabled check** and
     **no timeout** → if device location was off it threw a raw exception and silently yanked
     the user back to saved-address; if the fix never resolved it hung on "Getting your
     location…" forever.
   - `_detectMyLocation()` (map-picker flow) surfaced raw `Error: TimeoutException...` text and
     **returned silently with no message** on permission denied / deniedForever.

## Goals

- Convert checkout into a **3-step wizard** with a progress header, Back/Next navigation, and
  per-step validation gating.
- **Preserve all existing business logic** — GPS/saved-address, §8 fee cascade + distance,
  pasabay fee preview, closed-store block/warn, promo, place-order. This is a UI/flow
  reorganization, not a logic rewrite.
- Ship the GPS capture hardening behind one shared, tested helper.

## Non-Goals

- No backend changes.
- No change to the fee cascade, pasabay logic, or the checkout request payload.
- No extraction of each step into separate widget files (rejected — see Approach).
- No redesign of the delivery-type gating rules (heavy/bulk auto-lock, pasabay GPS-only hide).

## GPS Fix (DONE this session)

New `lib/features/checkout/utils/location_capture.dart`:

- `GpsCaptureResult` — value type carrying either a `Position` or a user-facing `error`; never
  throws. `ok` getter.
- `gpsFailureMessage(Object error)` — **pure**, unit-tested. Maps
  `LocationServiceDisabledException` / `TimeoutException` / `PermissionDeniedException` (and
  string-sniffed unknowns) to clear guidance; safe generic fallback.
- `captureCurrentPosition({timeout = 12s})` — one hardened path: `isLocationServiceEnabled`
  check → permission check/request → `getCurrentPosition` with `LocationSettings(high, timeLimit)`
  → returns `GpsCaptureResult`. Never hangs, never throws.

Both call sites rewired:

- `_captureGps()` — uses the helper; on failure **stays in GPS mode** (so the user can fix
  settings and tap Refresh; a GPS-only visitor has no saved address to fall back to) and shows
  the friendly message.
- `_detectMyLocation()` — uses the helper; friendly message on every failure mode (no more raw
  `Error: $e`, no more silent returns). Removed the now-duplicate inline service/permission code.

`import 'package:geolocator/geolocator.dart'` removed from `checkout_page.dart` (moved into the
util). Tests: `test/location_capture_test.dart` (7, all pass).

## Wizard Design

### Steps

1. **Address + Contact** — `_buildAddressSection` (saved/GPS toggle) + `_buildContactInfoSection`.
2. **Items + Delivery + Promo + Payment** — `_buildOrderSummary` + `DynamicFeeBanner` +
   `_buildDeliveryTypeSection` + `PromoCodeWidget` + `_buildPaymentMethodSection`.
3. **Review + Place Order** — read-only summary (items, delivery method, address, contact) + the
   fee/total breakdown, with "Edit" links jumping back to step 1/2.

### Approach: single-file restructure, reuse existing section builders

Lowest risk. The 12+ existing `_buildX` section methods and every provider watch stay as-is; we
only add wizard scaffolding around them. Extracting each step into its own `ConsumerStatefulWidget`
would require threading ~10 pieces of shared mutable state + `TextEditingController`s across files
for no user-facing gain — rejected as a regression risk.

### New structure in `checkout_page.dart`

- `int _currentStep = 0` state field.
- `_buildStepHeader()` — `●──○──○  Step N of 3` progress indicator with step labels
  (Address / Delivery / Review). Replaces the checklist guide.
- Body becomes:
  ```
  Column(
    children: [
      _buildStepHeader(),
      Expanded(child: IndexedStack(index: _currentStep, children: [step1, step2, step3])),
      _buildWizardBottomBar(cart),
    ],
  )
  ```
  `IndexedStack` keeps all three steps mounted so scroll position, form controllers, and
  fee-provider watches behave exactly like today. Each step body is its own
  `SingleChildScrollView` wrapping the reused section builders.
- `_buildWizardBottomBar(cart)` replaces `_buildBottomBar`:
  - **Back** button on steps 2–3 (`setState(_currentStep--)`).
  - Primary button: **Next** on steps 1–2 (gated), **Place Order** on step 3 (gated by
    `_canPlaceOrder() && !_isProcessing` → calls `_placeOrder()` directly).
  - A compact running **Total** stays visible in the bar on all steps.
- Extract the fee/total computation currently inline in `_buildBottomBar` into
  `_computeCheckoutTotals(cart)` returning a small record
  `({double subtotal, discount, shippingFee, total, double? distanceKm, bool isFreeShipping,
  isCrossMunicipality, double crossMuniSurcharge, ...})` so the step-3 review breakdown, the
  free-shipping / cross-muni banners, and the bottom-bar total all read one source (no
  divergence). The existing banners/`_buildSummaryRow`/`_showFeeBreakdown` move into the step-2
  and step-3 bodies unchanged, fed by this record.

### Deletions

- `_showOrderConfirmation`, `_buildConfirmRow` — the Review step is the confirmation.
- `_buildChecklistGuide`, `_buildCheckItem` — replaced by the step progress header.

### Validation gating

- **Step 1 → Next**: address complete (`city` + `street` + `barangay` all non-empty) AND
  name non-empty AND phone valid (`PhoneValidator`). Extracted to pure, unit-tested
  `checkoutStep1Valid({required String? city, street, barangay, name, phone})`.
- **Step 2 → Next**: always enabled (a delivery type and payment method are always defaulted:
  `pasabay` / `cod`).
- **Step 3 → Place Order**: existing `_canPlaceOrder() && !_isProcessing`. Closed-store
  block/warn and phone re-validation stay inside `_placeOrder()` unchanged.

Advancing from step 1 is blocked until step 1 is valid, so a user cannot reach Review with an
incomplete address.

## New pure module

`lib/features/checkout/utils/checkout_wizard.dart`:

- `const kCheckoutSteps` — ordered step metadata (index, short label). Pins step order for tests.
- `bool checkoutStep1Valid({String? city, street, barangay, name, phone})` — reuses
  `PhoneValidator` for the phone check; the rest are non-empty checks. This mirrors the address
  portion of `_canPlaceOrder()` so the two never drift (the widget calls this helper).

## Data flow (unchanged)

Address/contact/delivery/payment/promo state lives on `_CheckoutPageState` exactly as today.
`_placeOrder()` builds the same `CheckoutRequest` (server-authoritative fee; client fee is
display-only) and navigates to `orderConfirmation` on success. The wizard only changes *when*
each section is visible, not *what* is submitted.

## Error handling

- GPS failures → friendly `SnackBar` via `gpsFailureMessage` (never raw exceptions, never
  silent).
- Place-order failures → existing provider-error `SnackBar` path, unchanged.
- Empty cart / loading / profile-error → existing `cartAsync.when` / `profileAsync.when`
  branches, unchanged (the wizard body only renders inside the `data` branch).

## Testing

- `test/location_capture_test.dart` — 7 tests (GPS message mapping + result type). **DONE.**
- `test/checkout_wizard_test.dart` — new: `checkoutStep1Valid` truth table (missing each field,
  invalid vs valid phone) + step metadata/order.
- `flutter analyze lib` — 0 errors (2 pre-existing `Radio` deprecation infos remain).
- Existing checkout suite (`checkout_fee_provider`, `closed_store_action`, `delivery_gating`,
  `gps_address`, `store_grouping`, `visible_delivery_types`, `farthest_vendor`,
  `delivery_fees`) stays green.
- Widget-level wizard navigation is not unit-tested (geolocator + many provider watches); it
  relies on `flutter analyze` + the reused, already-covered section builders. Manual device/web
  QA of the 3-step flow is the final gate.

## Risks / mitigations

- **Fee divergence between review and bar** → single `_computeCheckoutTotals` source.
- **Lost state on step change** → `IndexedStack` (not a `switch`) keeps steps mounted.
- **Reaching Review with bad address** → step-1 Next gate blocks it.
- **Behavior drift in place-order** → `_placeOrder()` body untouched; only its trigger moves
  from the confirm dialog to the step-3 button.

## Out of scope / deferred

- Manual device/browser QA of the wizard + GPS on a real device (recommended before release).
- Per-step widget extraction (future cleanup if the file needs further decomposition).
- Animated step transitions (static `IndexedStack` swap is sufficient).
