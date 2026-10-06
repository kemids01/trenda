// lib/features/core/providers/tab_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom navigation tab index
/// 0=Shop, 1=Trenda, 2=Food, 3=Live, 4=Vendor Ads
///
/// Profile is NOT a tab any more (2026-09-30): it opens as its own page
/// (`/profile`) from the avatar at the top right. Anything that used to jump to
/// "tab 4" to show the profile must bump [profileOpenRequestProvider] instead —
/// setting the tab to 4 now opens Vendor Ads.
final selectedTabProvider = StateProvider<int>((ref) => 0);

const int kVendorAdsTabIndex = 4;

/// Ask the main screen to open the Profile page. A counter, not a bool, so two
/// requests in a row are two changes. The auth notifier has no BuildContext
/// (and the router may have just replaced the stack with /main after sign-in),
/// so the main screen owns the actual navigation.
final profileOpenRequestProvider = StateProvider<int>((ref) => 0);
