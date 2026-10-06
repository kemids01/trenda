// lib/features/home/presentation/main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trenda_frontend/features/home/presentation/shop_tab.dart';
import '../../auth/data/providers.dart';
import '../../auth/application/state.dart';
import '../../core/providers/tab_provider.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/providers/websocket_provider.dart';
import '../../core/services/notification_sound_service.dart';
import '../../core/widgets/city_selection_dialog.dart';
import 'food_tab.dart';
import '../../ads/utils/ad_click_handler.dart';
import '../../ads/providers/ads_provider.dart' show AdKind;
import 'ads_tab.dart';
import 'widgets/profile_avatar_button.dart';
import 'coming_soon_page.dart';
import 'trenda_hub_tab.dart';
import 'widgets/municipality_pill.dart';
import 'widgets/keyboard_docked_bar.dart';
import 'widgets/shop_dock.dart';
import 'widgets/trenda_brandmark.dart';

/// Helper to get icon for order status
IconData _getStatusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return Icons.check_circle;
    case 'pickup_started':
      return Icons.directions_bike;
    case 'out_for_delivery':
      return Icons.local_shipping;
    case 'arriving_at_customer':
      return Icons.pin_drop;
    case 'delivered':
      return Icons.celebration;
    default:
      return Icons.notifications;
  }
}

/// Helper to get color for order status
Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return Colors.blue;
    case 'pickup_started':
      return Colors.orange;
    case 'out_for_delivery':
      return Colors.teal;
    case 'arriving_at_customer':
      return Colors.green;
    case 'delivered':
      return Colors.green;
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.blueGrey;
  }
}

/// ----------------------
/// CONNECTIVITY BANNER STATE
/// ----------------------
class ConnectivityBannerState {
  final bool isRetrying;
  final bool showBackOnline;

  const ConnectivityBannerState({
    this.isRetrying = false,
    this.showBackOnline = false,
  });

  ConnectivityBannerState copyWith({bool? isRetrying, bool? showBackOnline}) {
    return ConnectivityBannerState(
      isRetrying: isRetrying ?? this.isRetrying,
      showBackOnline: showBackOnline ?? this.showBackOnline,
    );
  }
}

/// ----------------------
/// CONNECTIVITY BANNER NOTIFIER
/// ----------------------
class ConnectivityBannerNotifier
    extends StateNotifier<ConnectivityBannerState> {
  final Ref ref;

  ConnectivityBannerNotifier(this.ref) : super(const ConnectivityBannerState());

  Future<void> retryConnection() async {
    state = state.copyWith(isRetrying: true);
    await Future.delayed(const Duration(milliseconds: 500));
    ref.invalidate(connectivityStatusProvider);
    await Future.delayed(const Duration(milliseconds: 800));
    state = state.copyWith(isRetrying: false);
  }

  void triggerBackOnline() {
    state = state.copyWith(showBackOnline: true);
    Future.delayed(const Duration(seconds: 2), () {
      state = state.copyWith(showBackOnline: false);
    });
  }
}

/// ----------------------
/// PROVIDER
/// ----------------------
final connectivityBannerProvider =
    StateNotifierProvider<ConnectivityBannerNotifier, ConnectivityBannerState>(
  (ref) => ConnectivityBannerNotifier(ref),
);

/// ----------------------
/// MAIN SCREEN
/// ----------------------
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  static const String _cityDialogShownKey = 'city_dialog_shown';

  @override
  void initState() {
    super.initState();
    // Show city selection dialog on first launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowCityDialog();
    });
  }

  Future<void> _checkAndShowCityDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool(_cityDialogShownKey) ?? false;

    if (!hasShown && mounted) {
      await showCitySelectionDialog(context);
      await prefs.setBool(_cityDialogShownKey, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(selectedTabProvider);
    final authState = ref.watch(authNotifierProvider);
    final connectivity = ref.watch(connectivityStatusProvider);
    final bannerState = ref.watch(connectivityBannerProvider);

    final isOffline = connectivity.asData?.value == false;

    // The dock (search + QR + cart) belongs to the shopping tabs only — Live
    // and Profile have nothing for it to act on, so it is not built there.
    // Food is shopping, so it gets the marketplace dock.
    final ShopDockMode? dockMode = switch (currentIndex) {
      0 => ShopDockMode.shop,
      1 => ShopDockMode.trenda,
      2 => ShopDockMode.food,
      _ => null,
    };

    // While the keyboard is up the shopper is typing, not navigating: the nav
    // bar is dropped so the dock's search field sits straight on the keyboard
    // and the results keep as much of the screen as possible.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    // The auth flow asks for the Profile page (it has no BuildContext, and
    // after sign-in the router may have just reset the stack to /main). Only
    // open it from here when this screen is on top — if Profile is already
    // showing, a second copy would stack on it.
    ref.listen<int>(profileOpenRequestProvider, (prev, next) {
      if (prev == next) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (ModalRoute.of(context)?.isCurrent ?? true) context.push('/profile');
      });
    });

    // Connectivity listener for back online banner
    ref.listen(connectivityStatusProvider, (prev, next) {
      final prevVal = prev?.asData?.value;
      final nextVal = next.asData?.value;
      if (prevVal == false && nextVal == true) {
        ref.read(connectivityBannerProvider.notifier).triggerBackOnline();
      }
    });

    // 🆕 Order status notification listener - show snackbar for key updates
    ref.listen(orderStatusNotificationProvider, (prev, next) {
      if (next != null && (prev?.timestamp != next.timestamp)) {
        // Play notification sound
        ref.read(notificationSoundProvider).playOrderUpdateSound();

        // Show snackbar with order status update
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _getStatusIcon(next.status),
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (next.orderNumber.isNotEmpty)
                        Text(
                          'Order #${next.orderNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      Text(next.message),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: _getStatusColor(next.status),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => context.push('/orders'),
            ),
          ),
        );
      }
    });

    final tabs = [
      const ShopTab(), // 0: SHOP - Redesigned home
      const TrendaHubTab(), // 1: TRENDA - Official Trenda Store
      const FoodTab(), // 2: FOOD - restaurants (city picker moved to /city)
      const ComingSoonPage(
        // 3: LIVE - Coming Soon
        title: 'Trenda Live',
        description:
            'Watch live shopping streams and vendor broadcasts. Coming soon!',
        icon: Icons.live_tv_rounded,
      ),
      // 4: VENDOR ADS — the same list as Shop ▸ Ads, as a destination of its
      // own. Profile moved to the avatar at the top right (/profile).
      AdsTab(
        kind: AdKind.vendor,
        onAdTap: (ad) => handleAdClick(context, ad),
      ),
    ];

    final isInteractionDisabled =
        authState.status == AuthStatus.loading || bannerState.isRetrying;

    Widget mainContent = Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: tabs[currentIndex],
        ),

        // 🔴 Offline Banner
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          top: isOffline || bannerState.isRetrying ? 0 : -50,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isOffline ? 1 : 0,
            child: Container(
              height: 50,
              color: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        "No Internet Connection",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: bannerState.isRetrying
                        ? null
                        : () => ref
                            .read(connectivityBannerProvider.notifier)
                            .retryConnection(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                    ),
                    child: bannerState.isRetrying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("Retry"),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 🟢 Back Online Banner
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          top: bannerState.showBackOnline ? 0 : -50,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: bannerState.showBackOnline ? 1 : 0,
            child: Container(
              height: 50,
              color: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Row(
                children: [
                  Icon(Icons.wifi, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    "Back Online",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 🔹 Loading Overlay
        if (authState.status == AuthStatus.loading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );

    final isTablet = MediaQuery.of(context).size.width > 600;

    if (isTablet) {
      return SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: isInteractionDisabled
                  ? null
                  : (index) =>
                      ref.read(selectedTabProvider.notifier).state = index,
              labelType: NavigationRailLabelType.all,
              // Tablet layout has no app bar, so the profile avatar sits at
              // the top of the rail instead.
              leading: const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 12),
                child: ProfileAvatarButton(),
              ),
              // Must mirror the bottom bar below — same order, same `tabs` list.
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.shopping_bag_rounded),
                  label: Text('Shop'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.storefront_rounded),
                  label: Text('Trenda'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.restaurant_rounded),
                  label: Text('Food'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.live_tv_rounded),
                  label: Text('Live'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.campaign_rounded),
                  label: Text('Vendor Ads'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: mainContent),
          ],
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 14,
          // Brand lockup (monogram + the admin-configured platform name) with
          // the active municipality beside it — it scopes every price and shelf
          // in the app, so it belongs where it is always visible.
          title: Row(
            children: [
              const TrendaBrandMark(),
              const SizedBox(width: 10),
              const Flexible(child: MunicipalityPill()),
            ],
          ),
          // Search, QR scan and cart all moved into the shop dock above the
          // bottom navigation bar — within thumb reach, and only on the two
          // tabs that can use them.
          // Profile lives here now (its bottom-bar slot became Vendor Ads).
          actions: const [
            ProfileAvatarButton(),
            SizedBox(width: 12),
          ],
        ),
        body: AbsorbPointer(
          absorbing: isInteractionDisabled,
          child: mainContent,
        ),
        // KeyboardDockedBar: Scaffold never lifts this slot for the keyboard,
        // so without it the dock's search field sat BEHIND the keyboard.
        bottomNavigationBar: KeyboardDockedBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dockMode != null) ShopDock(mode: dockMode),
              if (!keyboardOpen)
                BottomNavigationBar(
                  currentIndex: currentIndex,
                  onTap: isInteractionDisabled
                      ? null
                      : (index) =>
                          ref.read(selectedTabProvider.notifier).state = index,
                  type: BottomNavigationBarType.fixed,
                  showSelectedLabels: true,
                  showUnselectedLabels: true,
                  items: const [
                    BottomNavigationBarItem(
                        icon: Icon(Icons.shopping_bag_rounded), label: 'Shop'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.storefront_rounded), label: 'Trenda'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.restaurant_rounded), label: 'Food'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.live_tv_rounded), label: 'Live'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.campaign_rounded),
                        label: 'Vendor Ads'),
                  ],
                ),
            ],
          ),
        ),
      );
    }
  }
}
