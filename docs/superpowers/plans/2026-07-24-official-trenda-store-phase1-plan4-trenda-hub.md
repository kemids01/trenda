# Official Trenda Store — Phase 1, Plan 4: Frontend Trenda Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development / executing-plans. Verify with `flutter analyze lib` (0 errors) + `flutter test` (existing suite green). LOCAL commits only (Flutter apps NEVER push).

**Goal:** Replace the Trenda Hub tab placeholder in `trenda_frontend` with a real Official Trenda Store section that lists official products (municipality-scoped) with gold badges + price comparison, tapping into the existing product details page.

**Architecture:** Reuse the existing `ProductsRepository`/`ProductModel` (official-store endpoint returns the same `Product` shape). Add one repository method + one municipality-scoped provider + a `TrendaHubTab` widget mounted at `main_screen.dart` tab index 2 (currently a `ComingSoonPage`). Tapping a product uses the existing `/product/:id` route.

**Tech Stack:** Flutter + Riverpod, `trenda_shared`.

**Backend endpoint (LIVE):** `GET /api/official-store/products?municipality=&category=&search=&page=&limit=` → `{ success, data: { products, pagination } }` where each product is a normal `Product` shape (maps to `ProductModel`). Also `GET /api/official-store/products/:id`.

**Reference (READ before implementing — mirror):** `trenda_shared/data/products_repository.dart` (how `fetchPublicProducts` builds the request/parses `{data:{products}}` — copy its HTTP client + parsing), `trenda_shared/models/product_model.dart` (has `basePrice`/`compareAtPrice`/images/etc.), `lib/features/products/providers/products_provider.dart` (`publicProductsProvider` + `municipalityProvider` scoping), `lib/features/products/presentation/products_grid_screen.dart` (the product card/grid widget to reuse), `lib/features/home/presentation/main_screen.dart` (tab list ~line 220; index 2 is the `ComingSoonPage` titled 'Trenda Hub'), `lib/features/home/presentation/shop_tab.dart` (a real home-tab layout to mirror for banner/sections/search).

---

### Task 1: Repository method for official-store products

**Files:**
- Modify: `trenda_shared/data/products_repository.dart` (ADDITIVE — new method only; do NOT change existing methods/signatures)

- [ ] **Step 1** Read `products_repository.dart` — note the HTTP client used (http/dio), base URL, auth header handling for public calls, and how `fetchPublicProducts` parses `data.products` into `List<ProductModel>` + returns a result object (note that result type; reuse it).
- [ ] **Step 2** Add `fetchOfficialStoreProducts({String? municipality, String? category, String? search, int limit = 50, int page = 1})` that GETs `/api/official-store/products` with those query params and parses the SAME `{data:{products}}` shape into the same result type `fetchPublicProducts` returns. Pure addition.
- [ ] **Step 3** `flutter analyze` the shared package (or the frontend which imports it) → 0 new errors.
- [ ] **Step 4** Commit (in `trenda_shared`, LOCAL): `feat(official): shared repo fetchOfficialStoreProducts`.

Note: `trenda_shared` is additive-only and shared by all apps — adding a method is safe; do NOT alter `ProductModel` or existing methods. Commit shared changes in the `trenda_shared` repo separately from the frontend repo.

---

### Task 2: Provider

**Files:**
- Create: `lib/features/home/providers/official_store_provider.dart` (frontend)

- [ ] **Step 1** Mirror `publicProductsProvider`:
```dart
final officialStoreProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final repo = ref.watch(productsRepositoryProvider);
  final municipality = ref.watch(municipalityProvider);
  final result = await repo.fetchOfficialStoreProducts(municipality: municipality, limit: 50);
  return result.products;
});
```
(Add a `.family` variant for category filtering only if the tab needs it — YAGNI otherwise.)
- [ ] **Step 2** `flutter analyze lib/features/home/providers/official_store_provider.dart` → 0 errors.
- [ ] **Step 3** Commit (frontend): `feat(official): trenda hub official-store provider`.

---

### Task 3: `TrendaHubTab` widget + mount

**Files:**
- Create: `lib/features/home/presentation/trenda_hub_tab.dart`
- Modify: `lib/features/home/presentation/main_screen.dart` (replace the index-2 `ComingSoonPage` with `const TrendaHubTab()`)

- [ ] **Step 1** Build `TrendaHubTab` (ConsumerWidget) mirroring `shop_tab.dart` structure:
  - Header/banner: "Official Trenda Store" with a gold accent.
  - Watches `officialStoreProductsProvider`; loading/empty/error states like `shop_tab`.
  - A grid/list of official products reusing the SAME product card widget `products_grid_screen.dart` uses (import and reuse it — do NOT build a new card). Since every product in this tab is official, render the gold "OFFICIAL TRENDA PRODUCT" badge on each card (a small overlay/wrapper is fine if the shared card has no badge slot) and show price comparison (strike `compareAtPrice`, highlight `basePrice`, show savings) — reuse `lib/features/products/utils/price_display.dart` if it exists.
  - A simple search field + optional category chips filtering the loaded list client-side (keep minimal).
  - Tap a product → `GoRouter.of(context).push('/product/${product.id}')` (confirm the exact product route from `main_screen.dart`/router).
- [ ] **Step 2** In `main_screen.dart`, replace the index-2 `ComingSoonPage(title:'Trenda Hub', ...)` with `const TrendaHubTab()`. Leave the other tabs untouched.
- [ ] **Step 3** `flutter analyze lib` → 0 errors.
- [ ] **Step 4** Commit (frontend): `feat(official): Trenda Hub Official Store section`.

---

### Task 4: Verify

- [ ] **Step 1** `flutter analyze lib` → 0 errors (paste). If the shared method was added, analyze passes with it.
- [ ] **Step 2** `flutter test` → existing suite green (paste summary). If a test references the tab list/ComingSoonPage count, update it.
- [ ] **Step 3** Commit any fixups.

---

## Self-Review (author)
- **Spec coverage:** §5.1 + §11 — official store products render in the Trenda Hub tab, municipality-scoped, gold badge + price comparison, tap → existing product details. Uses the LIVE `/api/official-store/products`.
- **Reuse discipline:** existing `ProductsRepository`/`ProductModel`/product card/product route — no new model, no new HTTP stack, no new details page. One additive shared method.
- **Deferred (YAGNI):** featured/deals/trending carousels beyond a single grid, advanced filters, wishlist wiring — a clean single official grid satisfies Phase 1; expand later if asked.
- **Two repos:** `trenda_shared` change commits in the shared repo (LOCAL); frontend changes commit in the frontend repo (LOCAL). Neither pushes.
- **Placeholder note:** exact result type of `fetchPublicProducts`, the product card widget name, and the product route string must be read from the code by the implementer and reused verbatim.
