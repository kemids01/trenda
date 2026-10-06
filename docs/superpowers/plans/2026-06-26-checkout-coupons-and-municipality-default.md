# Checkout Coupons (F1) + No Hardcoded Municipality Default (F3) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the mock client-side promo system with the live backend coupon API, and remove the hardcoded 'Tuguegarao City' municipality default.

**Architecture:** Both fixes are frontend-only in `trenda_frontend`. F1 wires the existing `PromoCodeWidget` to `POST /api/coupons/validate` (advisory preview) and sends the code via `CheckoutRequest` so `createOrder` re-validates authoritatively. F3 drops the hardcoded city, seeding the browsing municipality from `selected_municipality ?? home_municipality ?? null` and prompting when null.

**Tech Stack:** Flutter, Riverpod (StateNotifier), `package:http`, `shared_preferences`, `flutter_test`. Spec: `docs/superpowers/specs/2026-06-26-checkout-coupons-and-municipality-default-design.md`.

**Test command:** `flutter test <path>` (run from `trenda_frontend/`). Analyze: `flutter analyze lib`.

---

## File Structure

**F1 (coupons):**
- `lib/features/checkout/data/checkout_repository.dart` — MODIFY: add `CouponValidation` class, pure `parseCouponValidationResponse`, and `validateCoupon` HTTP method.
- `lib/features/checkout/providers/promo_provider.dart` — REWRITE: reshape `PromoState`, replace mock `PromoNotifier` with an injected-validator version, wire provider to the repository.
- `lib/features/checkout/models/checkout_model.dart` — MODIFY: add optional `coupon` to `CheckoutRequest`.
- `lib/features/checkout/presentation/promo_code_widget.dart` — MODIFY: new state shape.
- `lib/features/checkout/presentation/checkout_page.dart` — MODIFY: subtract discount in totals; pass `coupon`.
- Tests: `test/features/checkout/coupon_parser_test.dart`, `promo_notifier_test.dart`, `checkout_request_test.dart`.

**F3 (municipality):**
- `lib/features/core/providers/municipality_provider.dart` — MODIFY: pure `resolveInitialMunicipality`, drop `_defaultCity`.
- `lib/features/core/widgets/municipality_switcher.dart` — MODIFY: null-safe browsing muni + "Select area" prompt.
- `lib/features/home/presentation/map_picker_page.dart` — MODIFY (minor): relabel the pre-GPS camera seed.
- Test: `test/features/core/municipality_resolve_test.dart`.

---

## Task 1: Coupon response model + pure parser

**Files:**
- Modify: `lib/features/checkout/data/checkout_repository.dart`
- Test: `test/features/checkout/coupon_parser_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/checkout/coupon_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/data/checkout_repository.dart';

void main() {
  group('parseCouponValidationResponse', () {
    test('200 success returns ok with discount and type', () {
      final r = parseCouponValidationResponse(
        200,
        '{"success":true,"data":{"code":"SAVE10","discount":50.0,"type":"percentage","finalTotal":450.0}}',
      );
      expect(r.ok, true);
      expect(r.discount, 50.0);
      expect(r.type, 'percentage');
      expect(r.message, isNull);
    });

    test('404 returns not-ok with backend message', () {
      final r = parseCouponValidationResponse(
        404,
        '{"success":false,"message":"Invalid coupon code"}',
      );
      expect(r.ok, false);
      expect(r.discount, 0);
      expect(r.message, 'Invalid coupon code');
    });

    test('400 min-purchase returns not-ok with message', () {
      final r = parseCouponValidationResponse(
        400,
        '{"success":false,"message":"Minimum purchase of ₱500 required"}',
      );
      expect(r.ok, false);
      expect(r.message, contains('Minimum purchase'));
    });

    test('unparseable body returns safe not-ok', () {
      final r = parseCouponValidationResponse(200, '<html>oops</html>');
      expect(r.ok, false);
      expect(r.message, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/checkout/coupon_parser_test.dart`
Expected: FAIL — `CouponValidation` / `parseCouponValidationResponse` undefined.

- [ ] **Step 3: Add the model + parser**

In `lib/features/checkout/data/checkout_repository.dart`, after the imports (the file already imports `dart:convert`, `package:http/http.dart as http`, `firebase_auth`), add at top level (above `class CheckoutRepository`):

```dart
/// Result of a coupon validation call (POST /api/coupons/validate).
class CouponValidation {
  final bool ok;
  final double discount;
  final String? type;
  final String? message;

  const CouponValidation({
    required this.ok,
    this.discount = 0,
    this.type,
    this.message,
  });
}

/// Pure parser for the /api/coupons/validate response.
/// Testable without http/Firebase. 200+success → ok with discount/type;
/// anything else → not-ok with the backend message.
CouponValidation parseCouponValidationResponse(int statusCode, String body) {
  Map<String, dynamic> json;
  try {
    json = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return const CouponValidation(ok: false, message: 'Could not validate coupon');
  }
  if (statusCode == 200 && json['success'] == true) {
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return CouponValidation(
      ok: true,
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      type: data['type'] as String?,
    );
  }
  return CouponValidation(
    ok: false,
    message: (json['message'] as String?) ?? 'Invalid coupon code',
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/checkout/coupon_parser_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/checkout/data/checkout_repository.dart test/features/checkout/coupon_parser_test.dart
git commit -m "feat(checkout): add coupon validation response model + pure parser (F1)"
```

---

## Task 2: validateCoupon HTTP method on CheckoutRepository

**Files:**
- Modify: `lib/features/checkout/data/checkout_repository.dart`

No new test (Firebase-coupled token; parsing already covered by Task 1). Verified via analyze.

- [ ] **Step 1: Add the method**

Inside `class CheckoutRepository`, add a method (e.g. after `createCheckout`):

```dart
/// Validate a coupon for live Apply-time feedback. Advisory only —
/// createOrder re-validates server-side and is authoritative.
Future<CouponValidation> validateCoupon(String code, double cartTotal) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const CouponValidation(
          ok: false, message: 'Please sign in to use a coupon');
    }
    final token = await user.getIdToken();
    final res = await http.post(
      Uri.parse('$baseUrl/api/coupons/validate'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'code': code, 'cartTotal': cartTotal}),
    );
    return parseCouponValidationResponse(res.statusCode, res.body);
  } catch (e) {
    return const CouponValidation(
        ok: false, message: 'Could not validate coupon. Try again.');
  }
}
```

- [ ] **Step 2: Verify analyze is clean**

Run: `flutter analyze lib/features/checkout/data/checkout_repository.dart`
Expected: No new issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/checkout/data/checkout_repository.dart
git commit -m "feat(checkout): add validateCoupon http method (F1)"
```

---

## Task 3: Reshape PromoState + PromoNotifier (real validation)

**Files:**
- Rewrite: `lib/features/checkout/providers/promo_provider.dart`
- Test: `test/features/checkout/promo_notifier_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/checkout/promo_notifier_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/data/checkout_repository.dart';
import 'package:trenda_frontend/features/checkout/providers/promo_provider.dart';

void main() {
  group('PromoNotifier', () {
    test('valid code sets appliedCode + discount, clears error', () async {
      final n = PromoNotifier(
        (code, total) async =>
            const CouponValidation(ok: true, discount: 50, type: 'percentage'),
      );
      final ok = await n.applyPromoCode('save10', 500);
      expect(ok, true);
      expect(n.state.appliedCode, 'SAVE10'); // normalized upper-case
      expect(n.state.discount, 50);
      expect(n.state.error, isNull);
      expect(n.state.isLoading, false);
    });

    test('invalid code sets error, leaves appliedCode null', () async {
      final n = PromoNotifier(
        (code, total) async =>
            const CouponValidation(ok: false, message: 'Invalid coupon code'),
      );
      final ok = await n.applyPromoCode('NOPE', 500);
      expect(ok, false);
      expect(n.state.appliedCode, isNull);
      expect(n.state.discount, 0);
      expect(n.state.error, 'Invalid coupon code');
    });

    test('empty code short-circuits with error, no validator call', () async {
      var called = false;
      final n = PromoNotifier((code, total) async {
        called = true;
        return const CouponValidation(ok: true, discount: 10);
      });
      final ok = await n.applyPromoCode('   ', 500);
      expect(ok, false);
      expect(called, false);
      expect(n.state.error, isNotNull);
    });

    test('removePromoCode resets state', () async {
      final n = PromoNotifier(
        (code, total) async => const CouponValidation(ok: true, discount: 50),
      );
      await n.applyPromoCode('SAVE10', 500);
      n.removePromoCode();
      expect(n.state.appliedCode, isNull);
      expect(n.state.discount, 0);
      expect(n.state.error, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/checkout/promo_notifier_test.dart`
Expected: FAIL — new `PromoNotifier(...)` signature / `PromoState.appliedCode` don't exist yet.

- [ ] **Step 3: Rewrite the provider**

Replace the ENTIRE contents of `lib/features/checkout/providers/promo_provider.dart` with:

```dart
// lib/features/checkout/providers/promo_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/checkout_repository.dart';
import 'checkout_provider.dart'; // checkoutRepositoryProvider

/// A function that validates a coupon code against the backend.
typedef CouponValidator = Future<CouponValidation> Function(
    String code, double cartTotal);

/// Promo/coupon state. Discount/type come from the server, never computed locally.
class PromoState {
  final String? appliedCode;
  final double discount;
  final String? type;
  final bool isLoading;
  final String? error;

  const PromoState({
    this.appliedCode,
    this.discount = 0,
    this.type,
    this.isLoading = false,
    this.error,
  });
}

class PromoNotifier extends StateNotifier<PromoState> {
  final CouponValidator _validate;

  PromoNotifier(this._validate) : super(const PromoState());

  /// Validates [code] against the backend (advisory preview).
  /// The authoritative discount is recomputed by createOrder at checkout.
  Future<bool> applyPromoCode(String code, double cartTotal) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      state = const PromoState(error: 'Enter a promo code');
      return false;
    }

    state = const PromoState(isLoading: true);
    final result = await _validate(normalized, cartTotal);

    if (result.ok) {
      state = PromoState(
        appliedCode: normalized,
        discount: result.discount,
        type: result.type,
      );
      return true;
    }

    state = PromoState(error: result.message ?? 'Invalid promo code');
    return false;
  }

  void removePromoCode() {
    state = const PromoState();
  }
}

final promoProvider = StateNotifierProvider<PromoNotifier, PromoState>((ref) {
  final repo = ref.read(checkoutRepositoryProvider);
  return PromoNotifier((code, cartTotal) => repo.validateCoupon(code, cartTotal));
});
```

NOTE: this deletes the old mock `_promoCodes`, `PromoCode`, `PromoType`, `calculateDiscount`, and the dead `promoDiscountProvider` (it had zero references outside this file — verified). `promo_code_widget.dart` (Task 5) is the only consumer and is updated next.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/checkout/promo_notifier_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/checkout/providers/promo_provider.dart test/features/checkout/promo_notifier_test.dart
git commit -m "feat(checkout): reshape PromoNotifier to use real backend validation (F1)"
```

---

## Task 4: Add coupon field to CheckoutRequest

**Files:**
- Modify: `lib/features/checkout/models/checkout_model.dart`
- Test: `test/features/checkout/checkout_request_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/checkout/checkout_request_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/models/checkout_model.dart';

void main() {
  group('CheckoutRequest.toJson', () {
    final items = [CheckoutItem(productId: 'p1', quantity: 2)];

    test('includes coupon when set', () {
      final json = CheckoutRequest(
        shippingAddress: const {'city': 'X'},
        paymentMethod: PaymentMethod.cod,
        items: items,
        coupon: 'SAVE10',
      ).toJson();
      expect(json['coupon'], 'SAVE10');
    });

    test('omits coupon when null', () {
      final json = CheckoutRequest(
        shippingAddress: const {'city': 'X'},
        paymentMethod: PaymentMethod.cod,
        items: items,
      ).toJson();
      expect(json.containsKey('coupon'), false);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/checkout/checkout_request_test.dart`
Expected: FAIL — `coupon` named parameter doesn't exist.

- [ ] **Step 3: Add the field**

In `lib/features/checkout/models/checkout_model.dart`, modify `CheckoutRequest`:

```dart
class CheckoutRequest {
  final Map<String, dynamic> shippingAddress;
  final PaymentMethod paymentMethod;
  final String deliveryType;
  final List<CheckoutItem> items;
  final String? batchTypeId;
  final String? coupon;

  CheckoutRequest({
    required this.shippingAddress,
    required this.paymentMethod,
    required this.items,
    this.deliveryType = 'express', // Default to express
    this.batchTypeId,
    this.coupon,
  });

  Map<String, dynamic> toJson() => {
        'shippingAddress': shippingAddress,
        'paymentMethod': {
          'type': paymentMethod.name,
        },
        'deliveryType': deliveryType,
        if (batchTypeId != null) 'batchTypeId': batchTypeId,
        if (coupon != null && coupon!.isNotEmpty) 'coupon': coupon,
        'cartItems': items
            .map((e) => e.toJson())
            .toList(), // ✅ Backend accepts both 'items' and 'cartItems'
      };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/checkout/checkout_request_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/checkout/models/checkout_model.dart test/features/checkout/checkout_request_test.dart
git commit -m "feat(checkout): add optional coupon field to CheckoutRequest (F1)"
```

---

## Task 5: Update PromoCodeWidget to the new state shape

**Files:**
- Modify: `lib/features/checkout/presentation/promo_code_widget.dart`

No unit test (UI widget; logic covered by Task 3). Verified via analyze.

- [ ] **Step 1: Update the applied-promo display**

In `promo_code_widget.dart`, replace the applied-promo block (currently `if (promoState.appliedPromo != null) ...[` through its closing `],` — lines ~62–109) with:

```dart
          // Applied coupon display
          if (promoState.appliedCode != null) ...[
            AppSpacing.verticalSM,
            Container(
              padding: AppSpacing.paddingSM,
              decoration: BoxDecoration(
                color: AppColors.successContainer,
                borderRadius: AppSpacing.borderRadiusSM,
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 18),
                  AppSpacing.horizontalSM,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          promoState.appliedCode!,
                          style: AppTypography.labelLarge,
                        ),
                        Text(
                          'Coupon applied',
                          style: AppTypography.asSecondary(
                              AppTypography.labelSmall),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '-₱${promoState.discount.toStringAsFixed(2)}',
                    style: AppTypography.withColor(
                      AppTypography.titleSmall,
                      AppColors.success,
                    ),
                  ),
                  AppSpacing.horizontalXS,
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      ref.read(promoProvider.notifier).removePromoCode();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
```

- [ ] **Step 2: Update the input block (apply call + remove the mock hint)**

Replace the input block (`if (_isExpanded && promoState.appliedPromo == null) ...[` through its closing `],` — lines ~112–155) with:

```dart
          // Input field (when expanded and no coupon applied)
          if (_isExpanded && promoState.appliedCode == null) ...[
            AppSpacing.verticalMD,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter promo code',
                      isDense: true,
                      contentPadding: AppSpacing.paddingSM,
                      errorText: promoState.error,
                    ),
                  ),
                ),
                AppSpacing.horizontalSM,
                ElevatedButton(
                  onPressed: promoState.isLoading
                      ? null
                      : () async {
                          final success = await ref
                              .read(promoProvider.notifier)
                              .applyPromoCode(
                                  _controller.text, widget.orderTotal);
                          if (success) {
                            _controller.clear();
                          }
                        },
                  child: promoState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Apply'),
                ),
              ],
            ),
          ],
```

(The `Try: SAVE10, NEWUSER, or FREESHIP` hint is removed — those were mock codes.)

- [ ] **Step 2b: Verify analyze**

Run: `flutter analyze lib/features/checkout/presentation/promo_code_widget.dart`
Expected: No issues (no remaining references to `appliedPromo`/`calculateDiscount`).

- [ ] **Step 3: Commit**

```bash
git add lib/features/checkout/presentation/promo_code_widget.dart
git commit -m "feat(checkout): wire PromoCodeWidget to server coupon state (F1)"
```

---

## Task 6: Apply discount in checkout totals + send coupon

**Files:**
- Modify: `lib/features/checkout/presentation/checkout_page.dart`

No unit test (large stateful screen; the discount math is trivial and the providers are tested). Verified via analyze + the full suite.

- [ ] **Step 1: Import the promo provider**

At the top of `checkout_page.dart`, with the other `../providers/...` imports, add:

```dart
import '../providers/promo_provider.dart';
```

- [ ] **Step 2: Subtract discount in the order-summary total (~line 1459)**

Find:

```dart
    final total = cart.subtotal + finalShippingFee;
```

Replace with:

```dart
    final couponDiscount = ref.watch(promoProvider).discount;
    final rawTotal = cart.subtotal + finalShippingFee - couponDiscount;
    final total = rawTotal < 0 ? 0.0 : rawTotal;
```

Then add a discount row in the summary — find the subtotal row (`_buildSummaryRow('Subtotal', ...)` ~line 1579) and immediately after its statement add:

```dart
            if (couponDiscount > 0)
              _buildSummaryRow(
                  'Discount', '-₱${couponDiscount.toStringAsFixed(2)}'),
```

- [ ] **Step 3: Subtract discount in the confirm dialog (~line 2141)**

In `_showOrderConfirmation`, find:

```dart
    final total = cart.subtotal + deliveryFee;
```

Replace with:

```dart
    final couponDiscount = ref.read(promoProvider).discount;
    final rawTotal = cart.subtotal + deliveryFee - couponDiscount;
    final total = rawTotal < 0 ? 0.0 : rawTotal;
```

Then, in the dialog content, find the delivery-fee confirm row:

```dart
            _buildConfirmRow('🛵 Delivery Fee', deliveryFee > 0
                ? '₱${deliveryFee.toStringAsFixed(2)}'
                : 'FREE'),
```

and immediately after it add:

```dart
            if (couponDiscount > 0)
              _buildConfirmRow(
                  '🏷️ Discount', '-₱${couponDiscount.toStringAsFixed(2)}'),
```

- [ ] **Step 4: Pass the coupon into CheckoutRequest (~line 2350)**

In the `CheckoutRequest(...)` constructor call, after `deliveryType: _selectedDeliveryType,` and `batchTypeId: targetBatchTypeId,`, add:

```dart
        coupon: ref.read(promoProvider).appliedCode,
```

- [ ] **Step 5: Verify analyze**

Run: `flutter analyze lib/features/checkout/presentation/checkout_page.dart`
Expected: No new issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/checkout/presentation/checkout_page.dart
git commit -m "feat(checkout): apply coupon discount to totals + send code to backend (F1)"
```

---

## Task 7: Pure municipality resolver + drop hardcoded default

**Files:**
- Modify: `lib/features/core/providers/municipality_provider.dart`
- Test: `test/features/core/municipality_resolve_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/core/municipality_resolve_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trenda_frontend/features/core/providers/municipality_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('resolveInitialMunicipality', () {
    test('prefers saved selected_municipality', () async {
      final p = await prefsWith({
        'selected_municipality': 'Aparri',
        'home_municipality': 'Solana',
      });
      expect(resolveInitialMunicipality(p), 'Aparri');
    });

    test('falls back to home_municipality when no selection', () async {
      final p = await prefsWith({'home_municipality': 'Solana'});
      expect(resolveInitialMunicipality(p), 'Solana');
    });

    test('returns null when neither is set', () async {
      final p = await prefsWith({});
      expect(resolveInitialMunicipality(p), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/core/municipality_resolve_test.dart`
Expected: FAIL — `resolveInitialMunicipality` undefined.

- [ ] **Step 3: Add the resolver + drop the hardcoded default**

In `lib/features/core/providers/municipality_provider.dart`:

Add a top-level function (above `class MunicipalityNotifier`):

```dart
/// Resolves the initial browsing municipality from persisted prefs.
/// Saved selection wins; else the registered home municipality; else null
/// (the UI prompts the user to pick). No hardcoded default (coding rule #3).
String? resolveInitialMunicipality(SharedPreferences prefs) {
  return prefs.getString('selected_municipality') ??
      prefs.getString('home_municipality');
}
```

Then change `MunicipalityNotifier` — remove the `_defaultCity` constant and seed from the resolver:

```dart
class MunicipalityNotifier extends StateNotifier<String?> {
  static const String _key = 'selected_municipality';

  MunicipalityNotifier() : super(null) {
    _loadMunicipality();
  }

  Future<void> _loadMunicipality() async {
    final prefs = await SharedPreferences.getInstance();
    state = resolveInitialMunicipality(prefs);
  }

  Future<void> setMunicipality(String? municipality) async {
    final prefs = await SharedPreferences.getInstance();
    if (municipality == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, municipality);
    }
    state = municipality;
  }

  Future<void> clearMunicipality() async {
    await setMunicipality(null);
  }
}
```

(The literal `'home_municipality'` matches `HomeMunicipalityNotifier._key` in the same file. `setMunicipality`/`clearMunicipality`/the other providers are unchanged.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/core/municipality_resolve_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/core/providers/municipality_provider.dart test/features/core/municipality_resolve_test.dart
git commit -m "fix(core): seed municipality from prefs/home, drop hardcoded Tuguegarao default (F3)"
```

---

## Task 8: Null-safe municipality switcher

**Files:**
- Modify: `lib/features/core/widgets/municipality_switcher.dart`

No unit test (UI widget). Verified via analyze.

- [ ] **Step 1: Make the displayed muni null-safe in `build`**

Replace lines 13–16:

```dart
    final currentMuni = ref.watch(municipalityProvider) ?? 'Tuguegarao City';
    final homeMuni = ref.watch(homeMunicipalityProvider);
    final isBrowsingOther = homeMuni != null &&
        currentMuni.toLowerCase() != homeMuni.toLowerCase();
```

with:

```dart
    final currentMuni = ref.watch(municipalityProvider);
    final homeMuni = ref.watch(homeMunicipalityProvider);
    final isBrowsingOther = currentMuni != null &&
        homeMuni != null &&
        currentMuni.toLowerCase() != homeMuni.toLowerCase();
    final label = currentMuni ?? 'Select area';
```

Then in the `Text(...)` that renders the chip (currently `child: Text(currentMuni, ...)` ~line 43), change `currentMuni` to `label`:

```dart
              child: Text(
                label,
```

- [ ] **Step 2: Make the picker's current selection null-safe**

In `_showMunicipalityPicker`, replace line 62:

```dart
    final currentMuni = ref.read(municipalityProvider) ?? 'Tuguegarao City';
```

with:

```dart
    final currentMuni = ref.read(municipalityProvider);
```

Then update the `isSelected` computation inside the list builder (currently `final isSelected = muni.toLowerCase() == currentMuni.toLowerCase();` ~line 139):

```dart
                          final isSelected = currentMuni != null &&
                              muni.toLowerCase() == currentMuni.toLowerCase();
```

- [ ] **Step 3: Verify analyze**

Run: `flutter analyze lib/features/core/widgets/municipality_switcher.dart`
Expected: No issues (no remaining `'Tuguegarao City'` literal).

- [ ] **Step 4: Commit**

```bash
git add lib/features/core/widgets/municipality_switcher.dart
git commit -m "fix(core): switcher shows 'Select area' when no municipality chosen (F3)"
```

---

## Task 9: Relabel map-picker pre-GPS camera seed (minor)

**Files:**
- Modify: `lib/features/home/presentation/map_picker_page.dart`

No test (a constant rename; the picker already auto-centers on device GPS via `_goToCurrentLocation()` on open).

- [ ] **Step 1: Rename the constant + fix the misleading comment**

Replace (line ~43–44):

```dart
  // Default to Tuguegarao City, Philippines
  static const _defaultLocation = LatLng(17.6132, 121.7270);
```

with:

```dart
  // Pre-GPS camera seed only — overridden by device GPS on open
  // (see _goToCurrentLocation in initState). Not a data-scoping default.
  static const _fallbackCamera = LatLng(17.6132, 121.7270);
```

Then update its single use in `initState` (line ~49):

```dart
    _selectedLocation = widget.initialLocation ?? _fallbackCamera;
```

- [ ] **Step 2: Verify analyze**

Run: `flutter analyze lib/features/home/presentation/map_picker_page.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/map_picker_page.dart
git commit -m "chore(home): relabel map-picker pre-GPS camera seed, drop Tuguegarao label (F3)"
```

---

## Task 10: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: all tests pass — the 4 new test files (coupon_parser, promo_notifier, checkout_request, municipality_resolve) plus the pre-existing `widget_test.dart`.

- [ ] **Step 2: Run analyze on lib**

Run: `flutter analyze lib`
Expected: 0 errors. (Pre-existing 12 warnings / 26 info from the audit are acceptable and unrelated — confirm no NEW warnings from the changed files: promo_provider, promo_code_widget, checkout_page, checkout_model, checkout_repository, municipality_provider, municipality_switcher, map_picker_page.)

- [ ] **Step 3: Grep to confirm the mock + hardcoded default are gone**

Run: `grep -rn "SAVE10\|NEWUSER\|FREESHIP\|_defaultCity\|appliedPromo" lib`
Expected: no matches.
Run: `grep -rn "Tuguegarao" lib`
Expected: no matches (the map-picker label is now neutral).

- [ ] **Step 4: Commit any final fixups (if needed)**

```bash
git add -A
git commit -m "test: verify coupons + municipality default end to end (F1, F3)"
```

---

## Notes / Out of scope
- Backend `free_shipping` preview mismatch (`/validate` previews ₱0 while `createOrder` zeroes shipping) — logged backend follow-up in the spec; not fixed here. The on-screen estimate for a free-shipping coupon will understate the saving but the order charges correctly.
- F2 (mock Q&A), F4 (http→Dio), F5 (Firestore sessions), F6 (dead-code warnings), F7 (setState volume) — separate audit items, not in this plan.
- No remote on `trenda_frontend` — commits stay local on `main`.
