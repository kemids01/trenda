// lib/features/core/router/app_router.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_frontend/features/cart/presentation/cart_page.dart';
import 'package:trenda_frontend/features/chat/presentation/conversations_page.dart';
import 'package:trenda_frontend/features/chat/presentation/chat_page.dart';
import 'package:trenda_frontend/features/home/presentation/ad_details_page.dart';
import 'package:trenda_frontend/features/home/presentation/profile_page.dart';
import 'package:trenda_frontend/features/products/presentation/product_details_page.dart';
import 'package:trenda_shared/widgets/popup_ad.dart';
import '../../reviews/presentation/product_reviews_page.dart';
import '../../installment/screens/installment_wizard_screen.dart';
import '../../installment/screens/my_installments_screen.dart';
import '../../installment/screens/installment_payment_screen.dart';
import '../../wallet/screens/customer_wallet_screen.dart';
import '../../wallet/screens/customer_recharge_screen.dart';
import '../../giftcards/screens/gift_cards_screen.dart';
import '../../giftcards/screens/gift_card_help_screen.dart';
import '../../auth/data/providers.dart';
import '../../auth/presentation/login_page.dart';
import '../../auth/presentation/splash_page.dart';
import '../../home/presentation/main_screen.dart';
import 'package:trenda_shared/models/ad_model.dart';
import '../../search/presentation/search_page.dart';
import '../../search/providers/search_everything_provider.dart'
    show SearchScope;
import '../../checkout/presentation/checkout_page.dart';
import '../../checkout/presentation/order_confirmation_page.dart';
import '../../orders/presentation/orders_page.dart';
import '../../orders/presentation/order_details_page.dart';
import '../../orders/presentation/my_returns_page.dart';
import '../../home/presentation/addresses_page.dart';
import '../../notifications/presentation/notifications_page.dart';
import '../../products/presentation/comparison_page.dart';
import '../../vendors/screens/vendor_store_screen.dart';
import '../../vendors/screens/category_products_screen.dart'; // ✅ NEW: Category products
import '../../search/presentation/barcode_scanner_page.dart';
import '../../onboarding/presentation/onboarding_page.dart';
import '../../wishlist/presentation/wishlist_page.dart';
import '../../products/presentation/recently_viewed_page.dart';
import '../../products/presentation/product_browse_page.dart';
import '../../products/presentation/bundles_grid_screen.dart'; // ✅ NEW
import '../../products/presentation/bundle_details_page.dart'; // ✅ NEW
import '../../home/presentation/category_screen.dart';
import '../../home/presentation/official_store_page.dart';
import '../../home/presentation/official_collection_page.dart';
import '../../home/presentation/ad_showcase_page.dart';
import '../../home/presentation/ads_section_page.dart';
import '../../home/presentation/city_picker_page.dart';
import '../../home/presentation/shop_section_page.dart';
import '../../home/presentation/flash_sale_page.dart';
import '../../home/presentation/shop_category_page.dart';
import '../../home/providers/shop_sections_provider.dart';
import '../../home/providers/official_collections_provider.dart';
import '../widgets/swipe_down_to_dismiss.dart';
import 'package:trenda_shared/core/taps/taps.dart';

/// ----------------------
/// App Routes
/// ----------------------
class Routes {
  static const splash = '/';
  static const login = '/login';
  static const main = '/main';
  static const adDetails = '/ad-details';
  static const chat = '/chat';
  static const chatConversations = '/chat/conversations';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orderConfirmation = '/order-confirmation/:id';
  static const orders = '/orders';
  static const orderDetails = '/orders/:id';
  static const productDetails = '/product/:id';
  static const search = '/search';
  static const addresses = '/addresses';
  static const notifications = '/notifications';
  static const compare = '/compare';
  static const vendor = '/vendor/:id';
  static const store =
      '/store/:id'; // Alias for vendor/store page from Stores tab
  static const scanner = '/scanner';
  static const barcodeScanner = '/barcode-scanner';
  static const onboarding = '/onboarding';
  static const wishlist = '/wishlist';
  static const recentlyViewed = '/recently-viewed';
  static const productsGrid = '/products-grid';
  static const bundlesGrid = '/bundles'; // ✅ NEW
  static const bundleDetails = '/bundles/:id'; // ✅ NEW
  static const category = '/category/:type';
  static const wallet = '/wallet';
  static const walletRecharge = '/wallet/recharge';
  static const giftCards = '/gift-cards';
  static const giftCardsHelp = '/gift-cards/help';
  static const myReturns = '/my-returns';
  static const officialStore = '/official-store';
  static const officialCollection = '/official-collection';
  static const shopSection = '/shop-section';
  static const flashSale = '/flash-sale';
  static const shopCategory = '/shop-category';
  static const adsSection = '/ads-section';
  static const adShowcase = '/ad-showcase';
  // The city picker (was the Local tab, which became Food on 2026-09-25).
  static const city = '/city';
  // Profile left the bottom bar (its slot is Vendor Ads); opened from the
  // top-right avatar.
  static const profile = '/profile';
}

/// ----------------------
/// GoRouter Provider
/// ----------------------
final goRouterProvider = Provider<GoRouter>((ref) {
  final repo = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: Routes.splash,
    // Freezes new taps for 400 ms on every route change (no double opens).
    observers: [TapGuardObserver()],
    refreshListenable: GoRouterRefreshStream(repo.authStateChanges),
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashPage(),
      ),

      GoRoute(
        path: Routes.login,
        builder: (_, __) => const LoginPage(),
      ),

      GoRoute(
        path: Routes.profile,
        builder: (_, __) => const ProfilePage(),
      ),

      GoRoute(
        path: Routes.main,
        builder: (_, __) => PopupAdHost(
          audience: 'frontend',
          onProductTap: (ctx, productId) => ctx.push('/product/$productId'),
          child: const MainScreen(),
        ),
      ),

      // 🟦 Ad Details Route
      GoRoute(
        path: Routes.adDetails,
        builder: (_, state) {
          final ad = state.extra;
          if (ad == null || ad is! AdModel) {
            return const Scaffold(
              body: Center(child: Text('Ad not found')),
            );
          }
          return AdDetailsPage(ad: ad);
        },
      ),
      //Product Details Page
      // See-through page: pulling the product down shows the page it was opened from.
      GoRoute(
        path: Routes.productDetails,
        pageBuilder: (context, state) {
          final productId = state.pathParameters['id'];
          if (productId == null || productId.isEmpty) {
            return const MaterialPage(
              child: Scaffold(body: Center(child: Text('Product not found'))),
            );
          }
          return swipeDismissiblePage(
            key: state.pageKey,
            child: ProductDetailsPage(productId: productId),
          );
        },
      ),
      // ⭐ Product Reviews ("See All") Route
      GoRoute(
        path: '/product/:id/reviews',
        builder: (context, state) {
          final productId = state.pathParameters['id'];
          if (productId == null || productId.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Product not found')),
            );
          }
          return ProductReviewsPage(
            productId: productId,
            productName: state.extra is String ? state.extra as String : null,
          );
        },
      ),
      // 💬 Conversations List Route
      GoRoute(
        path: Routes.chatConversations,
        builder: (_, __) => const ConversationsPage(),
      ),
      // 💬 Chat Page Route (by conversation ID)
      GoRoute(
        path: '${Routes.chat}/:conversationId',
        builder: (_, state) {
          final conversationId = state.pathParameters['conversationId'];
          if (conversationId == null || conversationId.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Invalid conversation')),
            );
          }
          return ChatPage(conversationId: conversationId);
        },
      ),

      // 🛒 Cart Page Route
      GoRoute(
        path: Routes.cart,
        builder: (_, __) => const CartPage(),
      ),

      // ❤️ Wishlist Page Route
      GoRoute(
        path: Routes.wishlist,
        builder: (_, __) => const WishlistPage(),
      ),

      // 👁️ Recently Viewed Page Route
      GoRoute(
        path: Routes.recentlyViewed,
        builder: (_, __) => const RecentlyViewedPage(),
      ),

      // 💳 Checkout Page Route
      GoRoute(
        path: Routes.checkout,
        builder: (_, __) => const CheckoutPage(),
      ),

      // ✅ Order Confirmation Route
      GoRoute(
        name: 'orderConfirmation', // Simple name for goNamed()
        path: Routes.orderConfirmation,
        builder: (_, state) {
          final orderId = state.pathParameters['id'];
          if (orderId == null || orderId.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Invalid Order ID')),
            );
          }
          return OrderConfirmationPage(
            orderId: orderId,
            // One order per store: how many the checkout was placed as (absent → 1).
            orderCount: int.tryParse(state.uri.queryParameters['parts'] ?? '') ?? 1,
          );
        },
      ),

      // 📦 Orders Page Route
      GoRoute(
        path: Routes.orders,
        builder: (_, __) => const OrdersPage(),
      ),

      // 📄 Order Details Route
      GoRoute(
        path: Routes.orderDetails,
        builder: (_, state) {
          final orderId = state.pathParameters['id'];
          if (orderId == null || orderId.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Order not found')),
            );
          }
          return OrderDetailsPage(orderId: orderId);
        },
      ),

      // ✅ Duplicate route removed - already defined at line 73
      GoRoute(
        path: Routes.search,
        // extra: {'scope': 'official'|'food', 'query': …} — the docks pass their tab's
        // scope; the barcode scanner passes the scanned code as the query.
        builder: (_, state) {
          final extra = state.extra is Map ? state.extra as Map : const {};
          return SearchPage(
            initialScope: SearchScope.fromParam(extra['scope']),
            initialQuery: (extra['query'] ?? '').toString(),
          );
        },
      ),

      // 📍 Addresses Page Route
      GoRoute(
        path: Routes.addresses,
        builder: (_, __) => const AddressesPage(),
      ),

      // 🔔 Notifications Page Route
      GoRoute(
        path: Routes.notifications,
        builder: (_, __) => const NotificationsPage(),
      ),

      // 📊 Compare Products Route
      GoRoute(
        path: Routes.compare,
        builder: (_, __) => const ComparisonPage(),
      ),

      // 🏠 Vendor Store Route (with follow functionality)
      GoRoute(
        path: Routes.vendor,
        builder: (context, state) => VendorStoreScreen(
          vendorId: state.pathParameters['id']!,
        ),
      ),

      // 🏪 Store Route (Alias for vendor page from Stores tab)
      GoRoute(
        path: Routes.store,
        builder: (context, state) => VendorStoreScreen(
          vendorId: state.pathParameters['id']!,
        ),
      ),

      // 📂 Vendor Category Products Route
      GoRoute(
        path: '/vendor/:vendorId/category/:categoryId',
        builder: (context, state) => CategoryProductsScreen(
          vendorId: state.pathParameters['vendorId']!,
          categoryId: state.pathParameters['categoryId']!,
        ),
      ),

      // 📷 Barcode Scanner Route
      GoRoute(
        path: Routes.scanner,
        builder: (_, __) => const BarcodeScannerPage(),
      ),

      // 📱 Onboarding Route
      GoRoute(
        path: Routes.onboarding,
        builder: (_, __) => const OnboardingPage(),
      ),

      // 📷 Barcode Scanner Route (Alias)
      GoRoute(
        path: Routes.barcodeScanner,
        builder: (_, __) => const BarcodeScannerPage(),
      ),

      // 🛍️ Products Grid Route
      GoRoute(
        path: Routes.productsGrid,
        builder: (_, __) => const ProductBrowsePage(mode: BrowseMode.allItems),
      ),

      // 📁 Category Route (ads, sale, stores, services)
      GoRoute(
        path: Routes.category,
        builder: (context, state) {
          final type = state.pathParameters['type'] ?? '';
          // "On sale" is a product grid, not a category listing: it carries the
          // same filters, curated carousel and cards as "All items", so it is
          // the same page in its other mode rather than a third grid.
          if (type == 'sale') {
            return const ProductBrowsePage(mode: BrowseMode.onSale);
          }
          // Palengke (fresh market) is the same page in its third mode.
          if (type == 'palengke') {
            return const ProductBrowsePage(mode: BrowseMode.palengke);
          }
          return CategoryScreen(category: type);
        },
      ),

      // 📦 Bundles Grid Route
      GoRoute(
        path: Routes.bundlesGrid,
        builder: (_, __) => const BundlesGridScreen(),
      ),

      // 📦 Bundle Details Route
      GoRoute(
        path: Routes.bundleDetails,
        builder: (_, state) {
          final bundleId = state.pathParameters['id'];
          if (bundleId == null || bundleId.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Bundle not found')),
            );
          }
          return BundleDetailsPage(bundleId: bundleId);
        },
      ),

      // 💳 Installment Wizard Route
      GoRoute(
        path: '/installment/apply',
        builder: (context, state) {
          final draft = state.extra as Map<String, dynamic>?;
          return InstallmentWizardScreen(draftApplication: draft);
        },
      ),

      // 📋 My Installments Route
      GoRoute(
        path: '/installment/my-applications',
        builder: (context, state) => const MyInstallmentsScreen(),
      ),

      // 💳 Installment Payments Route
      GoRoute(
        path: '/installment/payments/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return InstallmentPaymentScreen(applicationId: id);
        },
      ),

      // 💰 Wallet Route
      GoRoute(
        path: Routes.wallet,
        builder: (_, __) => const CustomerWalletScreen(),
      ),

      // 🎁 Gift Cards Route
      GoRoute(
        path: Routes.giftCards,
        builder: (_, __) => const GiftCardsScreen(),
      ),

      // 🎁 Gift Cards Help
      GoRoute(
        path: Routes.giftCardsHelp,
        builder: (_, __) => const GiftCardHelpScreen(),
      ),

      // 💰 Wallet Recharge Route
      GoRoute(
        path: Routes.walletRecharge,
        builder: (_, __) => const CustomerRechargeScreen(),
      ),

      // 📦 My Returns Route
      GoRoute(
        path: Routes.myReturns,
        builder: (_, __) => const MyReturnsPage(),
      ),

      // 🏛️ Official Trenda Store landing page
      GoRoute(
        path: Routes.officialStore,
        builder: (_, __) => const OfficialStorePage(),
      ),

      // 🏛️ Official Store collection "See all"
      GoRoute(
        path: Routes.officialCollection,
        builder: (context, state) {
          final collection = state.extra;
          if (collection is! StoreCollection) {
            return const OfficialStorePage();
          }
          return OfficialCollectionPage(collection: collection);
        },
      ),

      // 🗂️ Shop tab category page (one per store-category group): its stores,
      // an Official ad, then its products.
      GoRoute(
        path: '${Routes.shopCategory}/:key',
        builder: (context, state) =>
            ShopCategoryPage(groupKey: state.pathParameters['key'] ?? ''),
      ),

      // 🛍️ Curated Shop-tab section "See all" (admin ▸ Shop Tab Sections)
      GoRoute(
        path: Routes.shopSection,
        builder: (context, state) {
          final section = state.extra;
          // Deep-linked without the section object (cold start, shared link):
          // the Shop tab is where the bands live, so send them there.
          if (section is! ShopSection) return const MainScreen();
          return ShopSectionPage(section: section);
        },
      ),

      // ⚡ Flash Sale "See all" (admin ▸ ADVERTISING ▸ Flash Sales)
      GoRoute(
        path: Routes.flashSale,
        builder: (_, __) => const FlashSalePage(),
      ),

      // 📢 Ads & Services "See all" (admin ▸ ADVERTISING ▸ Ad Placements)
      GoRoute(
        path: Routes.city,
        builder: (_, __) => const CityPickerPage(),
      ),
      GoRoute(
        path: Routes.adsSection,
        builder: (context, state) {
          final args = state.extra;
          // Deep-linked without the section object (cold start, shared link):
          // the band lives on the Shop tab, so send them there.
          if (args is! AdsSectionPageArgs) return const MainScreen();
          return AdsSectionPage(section: args.section, kind: args.kind);
        },
      ),

      // 📖 Ad showcase — the advertiser's full-screen pages
      GoRoute(
        path: Routes.adShowcase,
        builder: (context, state) {
          final ad = state.extra;
          // No ad object (cold start, shared link) or no pages: there is nothing
          // to show, so fall back rather than opening an empty black screen.
          if (ad is! AdModel || ad.showcasePages.isEmpty) {
            return const MainScreen();
          }
          return AdShowcasePage(ad: ad);
        },
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final loggedIn = authState.user != null;
      final currentPath = state.matchedLocation;

      // Let splash page handle its own navigation (checks onboarding)
      if (currentPath == Routes.splash) return null;

      // Let onboarding page work without redirect
      if (currentPath == Routes.onboarding) return null;

      // Login → Main
      if (loggedIn && currentPath == Routes.login) return Routes.main;

      // Protected routes (require login). Every page that shows one account's
      // data belongs here — a signed-out visitor used to land on a blank My
      // Returns / Gift cards / Wishlist / Notifications page instead of login.
      final protectedRoutes = [
        Routes.cart,
        Routes.checkout,
        Routes.orders,
        Routes.chat,
        Routes.addresses,
        Routes.wallet,
        Routes.walletRecharge,
        Routes.myReturns,
        Routes.giftCards,
        Routes.wishlist,
        Routes.notifications,
        '/installment',
      ];
      // Help pages under a protected prefix stay readable signed out.
      const publicUnderProtected = [Routes.giftCardsHelp];

      if (!publicUnderProtected.contains(currentPath) &&
          protectedRoutes.any((route) => currentPath.startsWith(route))) {
        if (!loggedIn) {
          // Save intended destination
          return Routes.login;
        }
      }

      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.toString() ?? 'Unknown error',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go(Routes.main),
              icon: const Icon(Icons.home),
              label: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// ----------------------
/// Refresh GoRouter on auth changes
/// ----------------------
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription _subscription;

  GoRouterRefreshStream(Stream stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
