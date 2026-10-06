// lib/models/ad_placement.dart
// Canonical official-ad placement slots. MUST stay in sync with the backend
// mirror in utils/adPlacements.js. Phase 1 lists ONLY slots an app renders.
class AdPlacementSlot {
  final String id;
  final String app; // 'vendor' | 'frontend' | 'supplier'
  final String page;
  final String section;
  final String label;
  final int recWidth;
  final int recHeight;
  const AdPlacementSlot({
    required this.id,
    required this.app,
    required this.page,
    required this.section,
    required this.label,
    required this.recWidth,
    required this.recHeight,
  });
  /// Edge-to-edge slot whose creative is stretched to fit (never cropped).
  bool get isFullWidthHero => kFullWidthHeroSlotIds.contains(id);

  /// e.g. "3:1", "5:3".
  String get ratioLabel {
    int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
    final d = gcd(recWidth, recHeight);
    return '${recWidth ~/ d}:${recHeight ~/ d}';
  }

  /// Every slot draws its creative stretched to fit (BoxFit.fill), never
  /// cropped — so the hint says so.
  String get sizeHint =>
      'Recommended $recWidth×$recHeight px ($ratioLabel)${isFullWidthHero ? ' · full width' : ''}'
      ' — other sizes are stretched to fit · JPG/PNG · < 2 MB';
}

/// The MAIN image of a vendor / service ad (`photos[0]`): the Vendor Ads and
/// Services list cards and the ad details header are all locked to this 6:5
/// shape, so a 1200×1000 upload shows whole on every phone. (Official ads use
/// their slot's shape instead; the Ads & Services band its own square
/// `carouselImage`; the See-all page its 9:16 `seeAllImage`.)
const int kAdListingImageWidth = 1200;
const int kAdListingImageHeight = 1000;
const double kAdListingImageAspect = kAdListingImageWidth / kAdListingImageHeight;

/// The FULL-WIDTH hero slots: edge to edge, as tall as the Shop tab's
/// Featured ad (~1.64–1.68:1 on a 360–412dp phone), and drawn BoxFit.fill so
/// the whole creative is always visible. Their recommended size is 1200×720
/// (5:3); a creative of another ratio is stretched to fit, not cropped.
const Set<String> kFullWidthHeroSlotIds = {
  'frontend.official_hub.top',
  'frontend.food.top',
};

const List<AdPlacementSlot> kAdPlacementSlots = [
  AdPlacementSlot(
    id: 'vendor.dashboard.performance_top',
    app: 'vendor',
    page: 'Dashboard',
    section: 'Top of Performance Overview',
    label: 'Vendor App › Dashboard › Top of Performance Overview',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.home.hero',
    app: 'frontend',
    page: 'Home (Shop)',
    section: 'Top hero banner',
    label: 'Consumer App › Home › Top hero banner',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'supplier.dashboard.top',
    app: 'supplier',
    page: 'Dashboard',
    section: 'Top of dashboard',
    label: 'Supplier App › Dashboard › Top',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.product.details_top',
    app: 'frontend',
    page: 'Product Details',
    section: 'Top of product details',
    label: 'Consumer App › Product Details › Top',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.category.top',
    app: 'frontend',
    page: 'Category',
    section: 'Top of category / search results',
    label: 'Consumer App › Category › Top of results',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'vendor.orders.top',
    app: 'vendor',
    page: 'Orders',
    section: 'Top of orders list',
    label: 'Vendor App › Orders › Top',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'vendor.products.top',
    app: 'vendor',
    page: 'Products',
    section: 'Top of products list',
    label: 'Vendor App › Products › Top',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.cart.top',
    app: 'frontend',
    page: 'Cart',
    section: 'Top of cart',
    label: 'Consumer App › Cart › Top',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.vendor_store.top',
    app: 'frontend',
    page: 'Vendor Store',
    section: 'Below store header',
    label: 'Consumer App › Vendor Store › Below header',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.checkout.top',
    app: 'frontend',
    page: 'Checkout',
    section: 'Top of checkout',
    label: 'Consumer App › Checkout › Top',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.order_success.top',
    app: 'frontend',
    page: 'Order Success',
    section: 'Order confirmation',
    label: 'Consumer App › Order Success › Top',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.search.top',
    app: 'frontend',
    page: 'Search',
    section: 'Top of search results',
    label: 'Consumer App › Search › Top of results',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'vendor.dashboard.reseller_earnings_top',
    app: 'vendor',
    page: 'Dashboard',
    section: 'Top of Reseller Earnings',
    label: 'Vendor App › Dashboard › Top of Reseller Earnings',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'vendor.dashboard.tools_top',
    app: 'vendor',
    page: 'Dashboard',
    section: 'Top of Tools',
    label: 'Vendor App › Dashboard › Top of Tools',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'vendor.dashboard.recent_activity_top',
    app: 'vendor',
    page: 'Dashboard',
    section: 'Top of Recent Activity',
    label: 'Vendor App › Dashboard › Top of Recent Activity',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'vendor.suppliers.top',
    app: 'vendor',
    page: 'Buy from Suppliers',
    section: 'Top of page',
    label: 'Vendor App › Buy from Suppliers › Top',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'vendor.store.bottom',
    app: 'vendor',
    page: 'My Store',
    section: 'Bottom of page',
    label: 'Vendor App › My Store › Bottom',
    recWidth: 1200,
    recHeight: 400,
  ),
  // "See all" page of a curated Shop-tab section (admin ▸ Shop Tab Sections).
  AdPlacementSlot(
    id: 'frontend.shop_section.top',
    app: 'frontend',
    page: 'Shop Section (See all)',
    section: 'Above the product grid',
    label: 'Consumer App › Shop Section › Above grid',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.shop_section.bottom',
    app: 'frontend',
    page: 'Shop Section (See all)',
    section: 'Below the product grid',
    label: 'Consumer App › Shop Section › Below grid',
    recWidth: 1200,
    recHeight: 400,
  ),
  // Between two curated Shop-tab bands — e.g. under "Daily Basics" and above
  // "Stores of the Week". Numbered rather than one id reused in every gap,
  // because a single slot would repeat the SAME ad down the page.
  AdPlacementSlot(
    id: 'frontend.shop.between_sections_1',
    app: 'frontend',
    page: 'Shop tab',
    section: 'Between section 1 and 2',
    label: 'Consumer App › Shop tab › Between bands 1–2',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.shop.between_sections_2',
    app: 'frontend',
    page: 'Shop tab',
    section: 'Between section 2 and 3',
    label: 'Consumer App › Shop tab › Between bands 2–3',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.shop.between_sections_3',
    app: 'frontend',
    page: 'Shop tab',
    section: 'Between section 3 and 4',
    label: 'Consumer App › Shop tab › Between bands 3–4',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.shop.between_sections_4',
    app: 'frontend',
    page: 'Shop tab',
    section: 'Between section 4 and 5',
    label: 'Consumer App › Shop tab › Between bands 4–5',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.shop.between_sections_5',
    app: 'frontend',
    page: 'Shop tab',
    section: 'Between section 5 and 6',
    label: 'Consumer App › Shop tab › Between bands 5–6',
    recWidth: 1200,
    recHeight: 400,
  ),
  // ── OFFICIAL TRENDA STORE tab (the consumer "Trenda Hub", main_screen idx 1)
  // and the two pages it opens into. Separate ids from the Shop tab's: the two
  // tabs are different inventory, and an advertiser buying the Official shelf
  // is buying first-party shoppers, not the general marketplace.
  AdPlacementSlot(
    id: 'frontend.official_hub.top',
    app: 'frontend',
    page: 'Official Store tab',
    section: 'Under the gold hero, above the collections',
    label: 'Consumer App › Official Store tab › Top',
    recWidth: 1200,
    recHeight: 720, // 5:3 — full-width hero, see kFullWidthHeroSlotIds
  ),
  AdPlacementSlot(
    id: 'frontend.official_hub.bottom',
    app: 'frontend',
    page: 'Official Store tab',
    section: 'Below the product grid',
    label: 'Consumer App › Official Store tab › Bottom',
    recWidth: 1200,
    recHeight: 400,
  ),
  // Between two collection carousels — e.g. under "Trending Now" and above
  // "Flash Sale". Numbered rather than one id reused in every gap, because a
  // single slot would repeat the SAME ad down the page.
  AdPlacementSlot(
    id: 'frontend.official_hub.between_collections_1',
    app: 'frontend',
    page: 'Official Store tab',
    section: 'Between collection 1 and 2',
    label: 'Consumer App › Official Store tab › Between collections 1–2',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.official_hub.between_collections_2',
    app: 'frontend',
    page: 'Official Store tab',
    section: 'Between collection 2 and 3',
    label: 'Consumer App › Official Store tab › Between collections 2–3',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.official_hub.between_collections_3',
    app: 'frontend',
    page: 'Official Store tab',
    section: 'Between collection 3 and 4',
    label: 'Consumer App › Official Store tab › Between collections 3–4',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.official_hub.between_collections_4',
    app: 'frontend',
    page: 'Official Store tab',
    section: 'Between collection 4 and 5',
    label: 'Consumer App › Official Store tab › Between collections 4–5',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.official_hub.between_collections_5',
    app: 'frontend',
    page: 'Official Store tab',
    section: 'Between collection 5 and 6',
    label: 'Consumer App › Official Store tab › Between collections 5–6',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.official_hub.between_collections_6',
    app: 'frontend',
    page: 'Official Store tab',
    section: 'Between collection 6 and 7',
    label: 'Consumer App › Official Store tab › Between collections 6–7',
    recWidth: 1200,
    recHeight: 400,
  ),
  // "See all" grid for ONE Official collection (route /official-collection).
  AdPlacementSlot(
    id: 'frontend.official_collection.top',
    app: 'frontend',
    page: 'Official Collection (See all)',
    section: 'Above the product grid',
    label: 'Consumer App › Official Collection › Above grid',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.official_collection.bottom',
    app: 'frontend',
    page: 'Official Collection (See all)',
    section: 'Below the product grid',
    label: 'Consumer App › Official Collection › Below grid',
    recWidth: 1200,
    recHeight: 400,
  ),
  // Full Official catalogue page behind the hero button (route /official-store).
  AdPlacementSlot(
    id: 'frontend.official_store.top',
    app: 'frontend',
    page: 'Official Store (full catalogue)',
    section: 'Above the product grid',
    label: 'Consumer App › Official Store page › Above grid',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.official_store.bottom',
    app: 'frontend',
    page: 'Official Store (full catalogue)',
    section: 'Below the product grid',
    label: 'Consumer App › Official Store page › Below grid',
    recWidth: 1200,
    recHeight: 400,
  ),
  // ── FOOD tab (main_screen idx 2) — the Official Trenda ads carousel at the
  // top. MUST stay in sync with utils/adPlacements.js on the backend.
  AdPlacementSlot(
    id: 'frontend.food.top',
    app: 'frontend',
    page: 'Food tab',
    section: 'Top of the Food tab, above the restaurant carousels',
    label: 'Consumer App › Food tab › Top',
    recWidth: 1200,
    recHeight: 720, // 5:3 — full-width hero, see kFullWidthHeroSlotIds
  ),
  // Palengke page (Shop tab ▸ Palengke) — under its stores row, above the
  // curated carousel and the fresh-market grid. MUST stay in sync with
  // utils/adPlacements.js on the backend.
  AdPlacementSlot(
    id: 'frontend.palengke.top',
    app: 'frontend',
    page: 'Palengke',
    section: 'Under the Palengke stores, above the products',
    label: 'Consumer App › Palengke › Under the stores',
    recWidth: 1200,
    recHeight: 400,
  ),
  // Shop tab category pages (2026-10-01) — one slot per store-category page,
  // under that category's stores. MUST stay in sync with utils/adPlacements.js.
  AdPlacementSlot(
    id: 'frontend.shop_category.pharmacy-health',
    app: 'frontend',
    page: 'Pharmacy & Health (Shop category page)',
    section: 'Under the stores, above the products',
    label: 'Consumer App › Shop › Pharmacy & Health › Under the stores',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.shop_category.hardware-construction',
    app: 'frontend',
    page: 'Hardware & Construction (Shop category page)',
    section: 'Under the stores, above the products',
    label: 'Consumer App › Shop › Hardware & Construction › Under the stores',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.shop_category.agriculture-farming',
    app: 'frontend',
    page: 'Agriculture & Farming (Shop category page)',
    section: 'Under the stores, above the products',
    label: 'Consumer App › Shop › Agriculture & Farming › Under the stores',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.shop_category.motor-auto',
    app: 'frontend',
    page: 'Motor & Auto (Shop category page)',
    section: 'Under the stores, above the products',
    label: 'Consumer App › Shop › Motor & Auto › Under the stores',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.shop_category.electronics-gadgets',
    app: 'frontend',
    page: 'Electronics & Gadgets (Shop category page)',
    section: 'Under the stores, above the products',
    label: 'Consumer App › Shop › Electronics & Gadgets › Under the stores',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.shop_category.fashion-beauty',
    app: 'frontend',
    page: 'Fashion & Beauty (Shop category page)',
    section: 'Under the stores, above the products',
    label: 'Consumer App › Shop › Fashion & Beauty › Under the stores',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.shop_category.home-living',
    app: 'frontend',
    page: 'Home & Living (Shop category page)',
    section: 'Under the stores, above the products',
    label: 'Consumer App › Shop › Home & Living › Under the stores',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.shop_category.school-office',
    app: 'frontend',
    page: 'School & Office Supplies (Shop category page)',
    section: 'Under the stores, above the products',
    label: 'Consumer App › Shop › School & Office Supplies › Under the stores',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.shop_category.pet-supplies',
    app: 'frontend',
    page: 'Pet Supplies (Shop category page)',
    section: 'Under the stores, above the products',
    label: 'Consumer App › Shop › Pet Supplies › Under the stores',
    recWidth: 1200,
    recHeight: 400,
  ),
  AdPlacementSlot(
    id: 'frontend.shop_category.booking-reservations',
    app: 'frontend',
    page: 'Booking & Reservations (Shop category page)',
    section: 'Under the stores, above the products',
    label: 'Consumer App › Shop › Booking & Reservations › Under the stores',
    recWidth: 1200,
    recHeight: 400,
  ),
];

/// The store-category groups with a Shop tab category page (and an ad slot),
/// in the order the Shop tab lists them. Mirrors backend
/// `SHOP_CATEGORY_PAGE_KEYS` and utils/storeCategoryTree2.js.
const List<({String key, String name})> kShopCategoryPages = [
  (key: 'pharmacy-health', name: 'Pharmacy & Health'),
  (key: 'hardware-construction', name: 'Hardware & Construction'),
  (key: 'agriculture-farming', name: 'Agriculture & Farming'),
  (key: 'motor-auto', name: 'Motor & Auto'),
  (key: 'electronics-gadgets', name: 'Electronics & Gadgets'),
  (key: 'fashion-beauty', name: 'Fashion & Beauty'),
  (key: 'home-living', name: 'Home & Living'),
  (key: 'school-office', name: 'School & Office Supplies'),
  (key: 'pet-supplies', name: 'Pet Supplies'),
  (key: 'booking-reservations', name: 'Booking & Reservations'),
];

/// The Official ad slot on a Shop category page. Take it from here, never build
/// the id by hand — an id the registry lacks is a slot nobody can fill.
String shopCategorySlotId(String groupKey) =>
    'frontend.shop_category.$groupKey';

/// The between-band slots, in gap order: index 0 is the gap after the FIRST
/// band, index 1 the gap after the second, and so on.
///
/// ⚠️ The app must take ids from here rather than building
/// `'frontend.shop.between_sections_$n'` by hand — an id the admin list does not
/// contain is a slot nobody can ever fill, and it fails silently because an
/// unsold slot renders as nothing.
///
/// A shop tab with more bands than this simply has no ad in the later gaps; the
/// bands sit next to each other exactly as they did before.
const List<String> kShopBetweenSectionSlotIds = [
  'frontend.shop.between_sections_1',
  'frontend.shop.between_sections_2',
  'frontend.shop.between_sections_3',
  'frontend.shop.between_sections_4',
  'frontend.shop.between_sections_5',
];

/// The Official Store tab's between-collection slots, in gap order: index 0 is
/// the gap after the FIRST collection carousel, index 1 the gap after the
/// second, and so on.
///
/// ⚠️ Same rule as [kShopBetweenSectionSlotIds]: take ids from here, never build
/// `'frontend.official_hub.between_collections_$n'` by hand. An id the admin
/// registry does not contain cannot be sold, and it fails SILENTLY because an
/// unsold slot renders as nothing.
///
/// The cap is deliberate. Collections are admin-created and the list grows, so
/// a NEW collection automatically gets the next free gap; once the gaps run out
/// the later carousels simply sit next to each other, exactly as they do today.
const List<String> kOfficialHubBetweenCollectionSlotIds = [
  'frontend.official_hub.between_collections_1',
  'frontend.official_hub.between_collections_2',
  'frontend.official_hub.between_collections_3',
  'frontend.official_hub.between_collections_4',
  'frontend.official_hub.between_collections_5',
  'frontend.official_hub.between_collections_6',
];

AdPlacementSlot? adSlotById(String id) {
  for (final s in kAdPlacementSlots) {
    if (s.id == id) return s;
  }
  return null;
}

List<AdPlacementSlot> adSlotsForApp(String app) =>
    kAdPlacementSlots.where((s) => s.app == app).toList();

List<String> get kAdPlacementApps =>
    kAdPlacementSlots.map((s) => s.app).toSet().toList();

/// Pop Up ad audiences (one app per pop-up). MUST stay in sync with
/// POPUP_AUDIENCES in utils/adPlacements.js. Supplier/Rider pop-ups are
/// image-only (never tappable).
const List<String> kPopupAudiences = ['frontend', 'vendor', 'supplier', 'rider'];
const List<String> kPopupTappableAudiences = ['frontend', 'vendor'];

/// Human label for a pop-up audience (for admin UI).
String popupAudienceLabel(String audience) {
  switch (audience) {
    case 'frontend':
      return 'Customer app';
    case 'vendor':
      return 'Vendor app';
    case 'supplier':
      return 'Supplier app';
    case 'rider':
      return 'Rider app';
    default:
      return audience;
  }
}

enum OfficialAdDisplayMode { none, static, carousel }

OfficialAdDisplayMode officialAdDisplayMode(int count) {
  if (count <= 0) return OfficialAdDisplayMode.none;
  if (count == 1) return OfficialAdDisplayMode.static;
  return OfficialAdDisplayMode.carousel;
}
