# Design — Real Checkout Coupons (F1) + No Hardcoded Municipality Default (F3)

**Date:** 2026-06-26
**App:** trenda_frontend (Customer App)
**Scope:** frontend-only. Both backends are already live and customer-callable; no backend changes.
**Source:** trenda_frontend audit 2026-06-26 (CLAUDE.md §17 findings F1, F3).

These are two independent fixes bundled in one spec. They share no code and can ship separately.

---

## F1 — Wire checkout coupons to the real backend

### Problem
`checkout/providers/promo_provider.dart` is a fully client-side **mock**: it hardcodes promo codes
(`SAVE10`/`NEWUSER`/`FREESHIP`), validates them with a fake 500 ms delay, and computes the discount
locally. It is mounted in checkout via `PromoCodeWidget(orderTotal: cart.subtotal)` in
`checkout_page.dart`. But:

- the discount is **never subtracted** from the displayed total (`total = subtotal + shippingFee`), and
- `CheckoutRequest.toJson()` sends **no coupon field**,

so the real backend coupon system (`Coupon.validateForCheckout`, live since merge 8ea8c88) is entirely
unused. Net effect: the user types a code, sees "discount applied", and nothing happens — misleading UX.
**Not a fraud risk** (the server is never tricked and the user is not charged less); the bug is a dead
feature plus a misleading display.

### Backend contract (already live — verified 2026-06-26)
- `POST /api/coupons/validate` (Bearer token, customer-callable; mounted at `app.js:498`)
  - Request body: `{ code: String, cartTotal: Number }`
  - `200 → { success: true, data: { code, discount, type, finalTotal } }`
  - `404 → { success: false, message: "Invalid coupon code" }`
  - `400 → { success: false, message }` (expired / usage-limit / already-used / min-purchase)
- `POST /api/checkout/create-order` accepts an optional `coupon` (String) in the request body.
  `createOrder` re-validates server-side via `Coupon.validateForCheckout(code, { userId, subtotal })`,
  returns `400` on invalid, sets `order.discount`, zeroes `order.shippingFee` for a `free_shipping`
  coupon, and computes `order.total = subtotal + shippingFee − discount`. Coupon usage is recorded
  post-commit (non-blocking). **This is the authoritative path.**

### Source of truth
`/validate` is **advisory** — used only for instant Apply-time feedback and the on-screen estimate.
`createOrder` re-validates and its returned `order.discount` / `order.total` are what the order/receipt
actually reflect. The frontend never trusts the preview for the real charge.

### Changes
1. **`checkout/providers/promo_provider.dart`**
   - Delete the mock `_promoCodes` map and the client-side `PromoCode.calculateDiscount` math.
   - Reshape `PromoState` to: `{ String? appliedCode, double discount, String? type, String? error, bool isLoading }`.
     `discount`/`type` come from the server response, not local computation.
   - `applyPromoCode(code)` calls the validate endpoint with `{ code, cartTotal: subtotal }`:
     - `200` → store `appliedCode`, `discount`, `type`; clear error.
     - `400`/`404` → store the backend `message` in `error`; leave `appliedCode` null.
   - `removePromoCode()` clears `appliedCode`/`discount`/`error`.
   - The notifier takes the cart subtotal at apply time (passed by the widget) so validation uses the
     same `cartTotal` the server will see.
2. **Coupon validate call**
   - Add a `validateCoupon(code, cartTotal)` method to `checkout/data/checkout_repository.dart`
     (Bearer token, same `package:http` pattern as the surrounding checkout code — Dio migration is a
     separate audit item, out of scope here). Returns a small result `{ ok, discount, type, message }`.
3. **`checkout/models/checkout_model.dart`**
   - `CheckoutRequest` gains an optional `String? coupon`; `toJson()` adds `if (coupon != null) 'coupon': coupon`.
4. **`checkout/presentation/checkout_page.dart`**
   - Subtract `promoState.discount` from the displayed total in the order-summary rows
     (`total = subtotal + finalShippingFee − discount`; floor at 0).
   - Pass `coupon: promoState.appliedCode` into the `CheckoutRequest` built before `createCheckout`
     (~line 2350).
5. **`checkout/presentation/promo_code_widget.dart`**
   - Show the server discount (`promoState.discount`) and the backend error message; pass the current
     subtotal into `applyPromoCode`. Minimal change — it already watches `promoProvider`.

### Known caveat (logged, not fixed here — backend follow-up)
The `/validate` controller and the `validateForCheckout` static diverge slightly: `/validate` does not
handle `free_shipping` (it previews a ₱0 discount and `finalTotal = cartTotal`), whereas `createOrder`
zeroes the shipping fee for a free-shipping coupon. So a free-shipping coupon **previews inaccurately
but charges correctly**. Recommended backend follow-up: route `/validate` through the same
`validateForCheckout` static so preview == authoritative. Out of scope for this frontend change.

### Testing
Unit tests for the reshaped `PromoNotifier` against a fake `http` adapter:
- valid code → `appliedCode` + `discount` set, no error;
- `404` → error message set, `appliedCode` null;
- `400` min-purchase → error message surfaced, `appliedCode` null;
- `removePromoCode` clears state.

---

## F3 — Remove the hardcoded 'Tuguegarao City' default

### Problem
`core/providers/municipality_provider.dart` defines `_defaultCity = 'Tuguegarao City'` and seeds the
browsing-municipality state with it; `core/widgets/municipality_switcher.dart` falls back to the same
literal twice; `home/presentation/map_picker_page.dart` defaults its map camera to Tuguegarao. A new
user with no saved preference is silently scoped to Tuguegarao City regardless of where they are.
Violates coding rule #3 ("Never hardcode municipality_id, municipality name, or PSGC codes").

### Desired behavior
- Existing users with a saved selection: unaffected.
- A registered user with a home municipality: browses that municipality by default.
- A brand-new user with neither saved selection nor home municipality: browsing state is `null` and the
  UI prompts them to pick a municipality (from `availableMunicipalitiesProvider`). No silent wrong-city
  scoping.
- `canOrderProvider` already restricts ordering to the home municipality, so this change only affects
  the browsing/scoping default, not order eligibility.

### Changes
1. **`core/providers/municipality_provider.dart`**
   - Delete `_defaultCity`.
   - `MunicipalityNotifier` initial state → `null`. In `_loadMunicipality`, seed:
     `state = prefs.getString('selected_municipality') ?? prefs.getString('home_municipality')`
     (read the `home_municipality` key directly to avoid a cross-provider load race), else `null`.
   - `setMunicipality` / `clearMunicipality` unchanged.
2. **`core/widgets/municipality_switcher.dart`**
   - Replace both `ref.watch(municipalityProvider) ?? 'Tuguegarao City'` / `ref.read(... ) ?? 'Tuguegarao City'`
     fallbacks. When the browsing municipality is `null`, render a "Select municipality" prompt/label
     that opens the existing picker (options from `availableMunicipalitiesProvider`) instead of
     defaulting to a city.
3. **`home/presentation/map_picker_page.dart`** (minor)
   - Initial map camera: prefer the device GPS position (geolocator is already a dependency); if
     unavailable, use a neutral region-level camera. A last-resort fixed coordinate is acceptable
     (camera position is not data scoping), but drop the "Tuguegarao City" comment/label.

### Testing
Unit test for `MunicipalityNotifier` seed precedence with a mocked `SharedPreferences`:
- saved `selected_municipality` present → that value;
- only `home_municipality` present → home value;
- neither present → `null`.

---

## Out of scope (this spec)
- F2 (mock Q&A), F4 (raw http → Dio), F5 (Firestore device sessions), F6 (dead-code warnings),
  F7 (setState volume) — separate audit items.
- Showing a list of available coupons (`GET /api/coupons/available`) — code-entry only for now.
- Backend unification of `/validate` with `validateForCheckout` — logged follow-up above.
