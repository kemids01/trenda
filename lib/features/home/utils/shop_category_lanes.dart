// lib/features/home/utils/shop_category_lanes.dart
// The Shop tab's quick-lane buttons: the five lanes it always had, then one per
// store-category page (trenda_shared kShopCategoryPages — the server's tree).
// Pure data, so the order and the routes are testable.
import 'package:flutter/material.dart';
import 'package:trenda_shared/models/ad_placement.dart' show kShopCategoryPages;

typedef ShopLane = ({String label, IconData icon, String route, Color color});

/// Route of a store-category page.
String shopCategoryRoute(String groupKey) => '/shop-category/$groupKey';

/// Short labels for the small buttons; the page itself shows the full name.
const Map<String, ({String label, IconData icon, Color color})> _kCategoryLook = {
  'pharmacy-health': (label: 'Pharmacy', icon: Icons.local_pharmacy_rounded, color: Color(0xFFDC2626)),
  'hardware-construction': (label: 'Hardware', icon: Icons.construction_rounded, color: Color(0xFFEA580C)),
  'agriculture-farming': (label: 'Farming', icon: Icons.agriculture_rounded, color: Color(0xFF65A30D)),
  'motor-auto': (label: 'Motor & Auto', icon: Icons.two_wheeler_rounded, color: Color(0xFF1D4ED8)),
  'electronics-gadgets': (label: 'Gadgets', icon: Icons.devices_rounded, color: Color(0xFF7C3AED)),
  'fashion-beauty': (label: 'Fashion', icon: Icons.checkroom_rounded, color: Color(0xFFDB2777)),
  'home-living': (label: 'Home', icon: Icons.chair_rounded, color: Color(0xFF0891B2)),
  'school-office': (label: 'School', icon: Icons.school_rounded, color: Color(0xFFCA8A04)),
  'pet-supplies': (label: 'Pets', icon: Icons.pets_rounded, color: Color(0xFF9333EA)),
  'booking-reservations': (label: 'Booking', icon: Icons.hotel_rounded, color: Color(0xFF0F766E)),
};

/// Colour + icon for a category page (falls back for a key the app does not know).
({String label, IconData icon, Color color}) shopCategoryLook(String groupKey) =>
    _kCategoryLook[groupKey] ??
    (label: groupKey, icon: Icons.storefront_rounded, color: const Color(0xFF475569));

/// Every Shop tab button, in order.
List<ShopLane> shopLanes() => [
      (label: 'All items', icon: Icons.grid_view_rounded, route: '/products-grid', color: const Color(0xFF2563EB)),
      (label: 'On sale', icon: Icons.local_offer_rounded, route: '/category/sale', color: const Color(0xFFDC2626)),
      (label: 'Shops', icon: Icons.storefront_rounded, route: '/category/stores', color: const Color(0xFF0F766E)),
      // Fresh market (vegetables, fruit, meat, fish). Vendor ads live in the
      // bottom bar's Vendor Ads tab.
      (label: 'Palengke', icon: Icons.shopping_basket_rounded, route: '/category/palengke', color: const Color(0xFF15803D)),
      (label: 'Services', icon: Icons.handyman_rounded, route: '/category/services', color: const Color(0xFF6B3A6E)),
      for (final page in kShopCategoryPages)
        (
          label: shopCategoryLook(page.key).label,
          icon: shopCategoryLook(page.key).icon,
          route: shopCategoryRoute(page.key),
          color: shopCategoryLook(page.key).color,
        ),
    ];
