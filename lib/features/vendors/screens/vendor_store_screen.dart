// lib/features/vendors/screens/vendor_store_screen.dart
// ============================================================================
// VENDOR STORE SCREEN - Customer View of Vendor's Store
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_frontend/features/core/widgets/frontend_official_ad_slot.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/vendor_follow_provider.dart';
import '../utils/hex_color.dart';
import '../utils/store_hours.dart';
import '../widgets/store_hero.dart';
import '../widgets/store_qr_sheet.dart';
import '../../stores/utils/storefront_style.dart';
import 'package:trenda_frontend/features/products/utils/price_display.dart';
import 'package:trenda_frontend/features/products/widgets/product_card_parts.dart';
import '../services/vendor_follow_service.dart';
import '../services/promotion_dialog_service.dart';
import '../../../widgets/promotion_dialog_popup.dart';
import '../../core/services/notification_sound_service.dart';
import '../../stores/widgets/closed_store_dialog.dart';
import '../widgets/vendor_category_carousels.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/utils/chat_errors.dart';
import 'package:trenda_shared/core/timezone.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class VendorStoreScreen extends ConsumerStatefulWidget {
  final String vendorId;

  const VendorStoreScreen({super.key, required this.vendorId});

  @override
  ConsumerState<VendorStoreScreen> createState() => _VendorStoreScreenState();
}

class _VendorStoreScreenState extends ConsumerState<VendorStoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  PromotionDialogData? _promoDialogData;

  /// The page is ONE scroll view; the selected tab's content is laid out as
  /// slivers inside it. It used to be a TabBarView of separate scroll views
  /// nested in the page, so dragging the products scrolled only the grid and
  /// the shopfront never collapsed.
  final ScrollController _scroll = ScrollController();

  /// A zero-height marker just above the tab bar, to find where it pins.
  final GlobalKey _tabsMarker = GlobalKey();
  int _shownTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
    _checkFollowStatus();
    _showPromotionDialogIfAvailable();
  }

  /// Show promotion dialog popup if vendor has one configured
  Future<void> _showPromotionDialogIfAvailable() async {
    // Wait for the screen to build first
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    try {
      final service = PromotionDialogService();
      final dialogData = await service.getVendorDialog(widget.vendorId);

      if (dialogData != null && dialogData.hasSlides && mounted) {
        setState(() => _promoDialogData = dialogData);

        // Respect showOnEveryVisit session setting
        if (!PromotionDialogService.shouldShowDialog(
            widget.vendorId, dialogData)) {
          return;
        }

        PromotionDialogService.markAsShown(widget.vendorId);

        _openPromotionDialog();
      }
    } catch (e) {
      // Silent failure - dialog is optional enhancement
    }
  }

  /// Open the promotion dialog popup
  void _openPromotionDialog() {
    if (_promoDialogData == null || !_promoDialogData!.hasSlides || !mounted) {
      return;
    }

    final service = PromotionDialogService();
    showPromotionDialog(
      context,
      data: _promoDialogData!,
      onImpressionTracked: (slideId) {
        service.trackImpression(widget.vendorId, slideId);
      },
      onProductClick: (slideId, productId) {
        service.trackProductClick(widget.vendorId, slideId);
      },
    );
  }

  Future<void> _checkFollowStatus() async {
    final followService = ref.read(vendorFollowServiceProvider);
    final isFollowing = await followService.isFollowing(widget.vendorId);
    if (mounted) {
      setState(() => _isFollowing = isFollowing);
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _isFollowLoading = true);

    final followService = ref.read(vendorFollowServiceProvider);
    final success = await followService.toggleFollow(widget.vendorId);

    if (success && mounted) {
      setState(() {
        _isFollowing = !_isFollowing;
        _isFollowLoading = false;
      });

      // Play sound on follow
      if (_isFollowing) {
        ref.read(notificationSoundProvider).playPromoSound();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('You\'ll be notified when this store adds new products!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unfollowed store')),
        );
      }
    } else {
      setState(() => _isFollowLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// A new tab starts at its own top: if the shopper had scrolled past the
  /// pinned tab bar, scroll back to where it pins — otherwise they would land
  /// in the middle of the new tab, at the old tab's depth.
  void _onTabChanged() {
    if (_tabController.index == _shownTab) return;
    _shownTab = _tabController.index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final marker = _tabsMarker.currentContext?.findRenderObject();
      if (marker == null || !marker.attached) return;
      final viewport = RenderAbstractViewport.maybeOf(marker);
      if (viewport == null) return;
      // The tab bar pins under the collapsed app bar, not at the very top.
      final pinnedAppBar = kToolbarHeight + MediaQuery.paddingOf(context).top;
      final tabsPinAt =
          viewport.getOffsetToReveal(marker, 0).offset - pinnedAppBar;
      if (_scroll.offset > tabsPinAt) {
        _scroll.jumpTo(tabsPinAt.clamp(0.0, _scroll.position.maxScrollExtent));
      }
    });
  }

  /// Swipe left/right on the page to change tab (the TabBarView used to give
  /// this for free). Horizontal carousels inside a tab win their own drags.
  void _onHorizontalSwipe(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v.abs() < 300) return;
    final next = _tabController.index + (v < 0 ? 1 : -1);
    if (next >= 0 && next < _tabController.length) {
      _tabController.animateTo(next);
    }
  }

  /// Share this shop: a real scannable QR, a working copy button, share sheet.
  void _showStoreQRCode(VendorProfile? profile) {
    showStoreQrSheet(
      context,
      vendorId: widget.vendorId,
      storeName: profile?.storeName ?? 'Store',
      logoUrl: profile?.logoUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendorProfile = ref.watch(vendorProfileProvider(widget.vendorId));

    return Scaffold(
      body: vendorProfile.when(
        data: (profile) => _buildContent(profile),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.store, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Store not found',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('ID: ${widget.vendorId}',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(VendorProfile? profile) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final seed = profile?.id.isNotEmpty == true ? profile!.id : widget.vendorId;
    // The vendor's own accent wins when they set one; otherwise the shop keeps
    // the awning colour it wears on the Stores street.
    final house = colorFromHex(
      profile?.accentColor,
      fallback: awningPaletteFor(seed, brightness: theme.brightness).stripe,
    );
    final open = profile?.isOpen ?? true;

    return GestureDetector(
      onHorizontalDragEnd: _onHorizontalSwipe,
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          // ── The shopfront ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 212,
            pinned: true,
            backgroundColor: scheme.surface,
            foregroundColor: scheme.onSurface,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsetsDirectional.only(start: 56, bottom: 14),
              title: LayoutBuilder(
                builder: (context, constraints) {
                  // Only name the shop once the facade has scrolled away — while
                  // it is open the fascia sign already says it, much larger.
                  final collapsed = constraints.biggest.height <= 0;
                  return AnimatedOpacity(
                    opacity: collapsed ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Text(
                      profile?.storeName ?? 'Store',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: scheme.onSurface,
                      ),
                    ),
                  );
                },
              ),
              background: StoreHero(
                seed: seed,
                storeName: profile?.storeName ?? 'Store',
                bannerUrl: profile?.bannerUrl,
                logoUrl: profile?.logoUrl,
                category: profile?.category,
                municipality: profile?.municipality,
                isOpen: open,
                isVerified: profile?.isVerified ?? false,
                isFeatured: profile?.isFeatured ?? false,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => _showStoreQRCode(profile),
                icon: const Icon(Icons.ios_share_rounded),
                tooltip: 'Share this shop',
              ),
            ],
          ),

          // Official Trenda ad (platform-owned) — below the store header
          const SliverToBoxAdapter(
            child: FrontendOfficialAdSlot(slotId: 'frontend.vendor_store.top'),
          ),

          // Closed Store Banner (if store is closed)
          if (profile != null && !profile.isOpen)
            SliverToBoxAdapter(
              child: ClosedStoreBanner(
                nextOpenTime: profile.nextOpenTime,
                nextOpenDay: profile.nextOpenDay,
                nextOpenAt: profile.nextOpenAt,
              ),
            ),

          // ── The counter: stats, hours, follow/chat, find the shop ────────
          SliverToBoxAdapter(child: _buildCounter(profile, house, open)),

          // ── Tabs ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(child: SizedBox(key: _tabsMarker, height: 0)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: house,
                unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.45),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  letterSpacing: 0.6,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                  letterSpacing: 0.6,
                ),
                indicatorWeight: 2,
                indicatorColor: house,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(height: 38, text: 'SHELVES'),
                  Tab(height: 38, text: 'REVIEWS'),
                  Tab(height: 38, text: 'ABOUT'),
                ],
              ),
            ),
          ),

          // Tab content — slivers of the SAME scroll view (see [_scroll]).
          ListenableBuilder(
            listenable: _tabController,
            builder: (context, _) => switch (_tabController.index) {
              1 => _buildReviewsTab(profile, house),
              2 => _buildAboutTab(profile, house),
              _ => _buildProductsTab(house, profile?.storeName),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startChat() async {
    try {
      final conv = await ref
          .read(chatControllerProvider)
          .startConversation(vendorId: widget.vendorId);
      if (mounted) context.push('/chat/${conv.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyChatError(e))),
        );
      }
    }
  }

  // =========================================================================
  // THE COUNTER — stats, today's hours, follow/chat, then where to find us
  // =========================================================================

  Widget _buildCounter(VendorProfile? profile, Color house, bool open) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final description = profile?.storeDescription?.trim();

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dark ? Colors.white12 : Colors.black.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A thin band of the shop's colour ties the card to the facade above.
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                house,
                house.withValues(alpha: 0.35),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 0),
            child: Row(
              children: [
                _statTile(
                  value: (profile?.rating ?? 0) > 0
                      ? profile!.rating.toStringAsFixed(1)
                      : '—',
                  label: (profile?.reviewCount ?? 0) > 0
                      ? '${_formatCount(profile!.reviewCount)} reviews'
                      : 'No reviews',
                  icon: Icons.star_rounded,
                  color: const Color(0xFFE9A227),
                  onTap: () => _tabController.animateTo(1),
                ),
                const SizedBox(width: 6),
                _statTile(
                  value: _formatCount(profile?.productCount ?? 0),
                  label: 'products',
                  icon: Icons.inventory_2_rounded,
                  color: house,
                  onTap: () => _tabController.animateTo(0),
                ),
                const SizedBox(width: 6),
                _statTile(
                  value: _formatCount(profile?.followerCount ?? 0),
                  label: 'followers',
                  icon: Icons.favorite_rounded,
                  color: const Color(0xFFE05C6E),
                ),
              ],
            ),
          ),
          _todayLine(profile, house, open),
          if (description != null && description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.62),
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
            child: _actionRow(profile, house),
          ),
          _findTheShop(profile, house),
        ],
      ),
    );
  }

  Widget _statTile({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Open today · 8:00 AM – 5:00 PM" — the one line of hours a shopper
  /// actually needs, without opening the About tab.
  Widget _todayLine(VendorProfile? profile, Color house, bool open) {
    final scheme = Theme.of(context).colorScheme;
    final week = parseWeeklyHours(
      storeHours: profile?.storeHours,
      operatingHours: profile?.operatingHours,
    );
    final todayKey = weekdayKey(TrendaTimezone.now());
    StoreDayHours? today;
    for (final d in week) {
      if (d.day == todayKey) today = d;
    }
    final color = open ? const Color(0xFF157347) : const Color(0xFFDC2626);
    final hours = today == null
        ? null
        : today.isOpen
            ? 'Today ${today.range}'
            : 'Closed today';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            open ? 'Open now' : 'Closed now',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (hours != null) ...[
            Text(
              '  ·  ',
              style: TextStyle(
                fontSize: 10,
                color: scheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
            Flexible(
              child: Text(
                hours,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionRow(VendorProfile? profile, Color house) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 34,
            child: FilledButton.icon(
              onPressed: _isFollowLoading ? null : () => TapGuard.run('vendor_store.toggleFollow', _toggleFollow),
              style: FilledButton.styleFrom(
                backgroundColor: _isFollowing
                    ? scheme.onSurface.withValues(alpha: 0.07)
                    : house,
                foregroundColor: _isFollowing ? scheme.onSurface : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              icon: _isFollowLoading
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isFollowing
                          ? Icons.check_rounded
                          : Icons.favorite_border_rounded,
                      size: 15,
                    ),
              label: Text(
                _isFollowing ? 'Following' : 'Follow shop',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
        ),
        // Messaging is a subscription benefit for free vendors: the server
        // decides. `!= false` so a still-loading profile keeps the button
        // rather than flickering it away and back.
        if (profile?.chatEnabled != false) ...[
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 34,
              child: OutlinedButton.icon(
                onPressed: () => TapGuard.run('vendor_store.startChat', _startChat),
                style: OutlinedButton.styleFrom(
                  foregroundColor: house,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  side: BorderSide(color: house.withValues(alpha: 0.45)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                label: const Text(
                  'Chat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
        if (_promoDialogData != null) ...[
          const SizedBox(width: 6),
          _squareAction(
            icon: Icons.local_offer_rounded,
            tooltip: 'View promos',
            color: const Color(0xFFDB2777),
            onPressed: _openPromotionDialog,
          ),
        ],
      ],
    );
  }

  /// Where the shop is and how to reach it — right under Follow / Chat, so a
  /// shopper deciding to visit never has to dig into the About tab.
  Widget _findTheShop(VendorProfile? profile, Color house) {
    final scheme = Theme.of(context).colorScheme;
    final address = profile?.address?.trim();
    final municipality = profile?.municipality?.trim();
    final pin = profile?.storePin;
    final phone = profile?.phone?.trim();
    final email = profile?.email?.trim();

    final hasAddress = address != null && address.isNotEmpty;
    final hasMuni = municipality != null && municipality.isNotEmpty;
    final hasPhone = phone != null && phone.isNotEmpty;
    final hasEmail = email != null && email.isNotEmpty;
    if (!hasAddress && !hasMuni && pin == null && !hasPhone && !hasEmail) {
      return const SizedBox.shrink();
    }

    // Municipality is appended unless the address already names it.
    final line = [
      if (hasAddress) address,
      if (hasMuni &&
          !(hasAddress &&
              address.toLowerCase().contains(municipality.toLowerCase())))
        municipality,
    ].join(', ');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 10),
      decoration: BoxDecoration(
        color: house.withValues(alpha: 0.05),
        border: Border(
          top: BorderSide(color: house.withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: house.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(Icons.place_rounded, size: 15, color: house),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FIND THE SHOP',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: scheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line.isEmpty ? 'Contact the shop' : line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (pin != null || hasPhone || hasEmail) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (pin != null)
                  _contactChip(
                    icon: Icons.map_outlined,
                    label: 'Open map',
                    color: house,
                    filled: true,
                    onTap: () => _launchExternal(pin.mapsUrl),
                  ),
                if (hasPhone)
                  _contactChip(
                    icon: Icons.phone_outlined,
                    label: phone,
                    color: house,
                    onTap: () => _launchExternal('tel:$phone'),
                  ),
                if (hasEmail)
                  _contactChip(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    color: house,
                    onTap: () => _launchExternal('mailto:$email'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _contactChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return Material(
      color: filled ? color : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: color.withValues(alpha: filled ? 0 : 0.4)),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: filled ? Colors.white : color),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: filled ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _squareAction({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 34,
      width: 34,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // =========================================================================
  // HELPER METHODS
  // =========================================================================

  /// Format large numbers (e.g., 1.2K, 10.5K)
  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Widget _buildProductsTab(Color house, String? storeName) {
    final products = ref.watch(vendorProductsProvider(widget.vendorId));

    return products.when(
      data: (productList) {
        if (productList.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No products yet'),
                ],
              ),
            ),
          );
        }
        return SliverMainAxisGroup(
          slivers: [
            // Category Carousels (shows vendor's custom categories)
            SliverToBoxAdapter(
              child: VendorCategoryCarousels(
                  vendorId: widget.vendorId, house: house),
            ),

            // All Products header — a shelf label in the shop's colour
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: house,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'All products',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: house.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${productList.length}',
                        style: TextStyle(
                          color: house,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Staggered Products Grid — a SLIVER grid, so cards are built as
            // they scroll in (the old shrink-wrapped grid built every card
            // up front).
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childCount: productList.length,
                itemBuilder: (context, index) {
                  return _buildProductCard(
                      productList[index], index, house, storeName);
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],
        );
      },
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('Error: $e')),
      ),
    );
  }

  /// One tile of the store's masonry grid, in the shop's house colour:
  /// staggered photo, name, a description hint, real rating/sales, a stock
  /// meter, and the price at the foot.
  Widget _buildProductCard(
      VendorProduct product, int index, Color house, String? storeName) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    // Staggered heights so the masonry reads as a shelf, not a table.
    const heightVariants = [160.0, 130.0, 145.0, 120.0, 155.0];
    final imageHeight = heightVariants[index % heightVariants.length];
    final hasDiscount =
        product.salePrice != null && product.salePrice! < product.basePrice;
    final discountPercent = hasDiscount
        ? ((product.basePrice - product.salePrice!) / product.basePrice * 100)
            .round()
        : 0;

    // Actual sold count and rating only. An unrated product says "New" — it
    // used to fall back to a hardcoded 4.5, which invented social proof for
    // every product that had never been reviewed.
    final soldCount = product.soldCount;
    final rating = product.rating;
    final soldOut = !product.inStock || product.stock <= 0;
    final stock = product.stock;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final url = product.images.isNotEmpty ? product.images.first.trim() : '';
    final plate = ColoredBox(
      color: Color.lerp(house, scheme.surface, 0.9)!,
      child: Center(
        child: Icon(Icons.image_outlined,
            size: 30, color: house.withValues(alpha: 0.35)),
      ),
    );

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  dark ? Colors.white12 : Colors.black.withValues(alpha: 0.07),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    url.isEmpty
                        ? plate
                        : CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => plate,
                            errorWidget: (_, __, ___) => plate,
                          ),
                    if (hasDiscount)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            borderRadius: BorderRadius.only(
                                bottomRight: Radius.circular(8)),
                          ),
                          child: Text(
                            '-$discountPercent%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    // HOT sits under the discount on the left: the top-right
                    // corner belongs to the store name, as on every card.
                    if (soldCount > 200)
                      Positioned(
                        top: hasDiscount ? 21 : 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF4511E),
                            borderRadius: BorderRadius.only(
                                bottomRight: Radius.circular(8)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_fire_department_rounded,
                                  size: 10, color: Colors.white),
                              SizedBox(width: 2),
                              Text(
                                'HOT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    StoreNameCorner(storeName: storeName, house: house),
                    if (soldOut)
                      ColoredBox(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: const Center(
                          child: Text(
                            'SOLD OUT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      )
                    else if (stock <= 5)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          color: const Color(0xFFB45309),
                          child: Text(
                            'ONLY $stock LEFT',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        letterSpacing: -0.2,
                        color: scheme.onSurface,
                      ),
                    ),
                    if ((product.description ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          product.description!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: muted),
                        ),
                      ),
                    // Stock meter: how much is left, coloured by urgency.
                    if (!soldOut) ...[
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (stock / 100).clamp(0.04, 1.0),
                          minHeight: 3,
                          backgroundColor:
                              scheme.onSurface.withValues(alpha: 0.08),
                          color: stock <= 10
                              ? const Color(0xFFE53935)
                              : stock <= 30
                                  ? const Color(0xFFFB8C00)
                                  : const Color(0xFF43A047),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('$stock in stock',
                          style: TextStyle(fontSize: 9, color: muted)),
                    ],
                    const SizedBox(height: 5),
                    // Price in green, then the star rating and units sold.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            '₱${(product.salePrice ?? product.basePrice).toStringAsFixed(0)}'
                            '${pricingUnitSuffix(product.pricingUnit)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: productPriceColor(context),
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '₱${product.basePrice.toStringAsFixed(0)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.4),
                                decoration: TextDecoration.lineThrough,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    // This product summary carries a rating but no review
                    // count, so any real rating counts as rated.
                    RatingSoldRow(
                      rating: rating,
                      reviews: rating > 0 ? 1 : 0,
                      sold: soldCount,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// There is no public store-level reviews endpoint — reviews are per product
  /// (`GET /api/reviews/product/:id`). So this shows the store's real aggregate
  /// and sends the shopper to the product that interests them, rather than
  /// inventing a feed.
  Widget _buildReviewsTab(VendorProfile? profile, Color house) {
    final scheme = Theme.of(context).colorScheme;
    final rating = profile?.rating ?? 0;
    final count = profile?.reviewCount ?? 0;

    if (count == 0) {
      return _emptyTab(
        icon: Icons.rate_review_outlined,
        title: 'No reviews yet',
        body: 'This shop has not been reviewed. Buy something and you could be '
            'the first to say how it went.',
      );
    }

    return SliverPadding(
        padding: const EdgeInsets.all(12),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                decoration: BoxDecoration(
                  color: house.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: house.withValues(alpha: 0.18)),
                ),
                child: Column(
                  children: [
                    Text(
                      rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: -1.5,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final filled = rating >= i + 1;
                        final half = !filled && rating > i;
                        return Icon(
                          half
                              ? Icons.star_half_rounded
                              : filled
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                          size: 21,
                          color: const Color(0xFFE9A227),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'From ${_formatCount(count)} '
                      '${count == 1 ? 'review' : 'reviews'} across this shop',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: scheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Individual reviews live on each product. Open a product from '
                      'the Shelves tab to read what buyers said about it.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _tabController.animateTo(0),
                style: OutlinedButton.styleFrom(
                  foregroundColor: house,
                  side: BorderSide(color: house.withValues(alpha: 0.45)),
                ),
                icon: const Icon(Icons.grid_view_rounded, size: 16),
                label: const Text('Browse the shelves'),
              ),
            ],
          ),
        ));
  }

  /// Description, the week's hours and the shop's particulars. Where to find
  /// the shop and how to reach it now sit on the counter card, under Follow.
  Widget _buildAboutTab(VendorProfile? profile, Color house) {
    final scheme = Theme.of(context).colorScheme;
    final week = parseWeeklyHours(
      storeHours: profile?.storeHours,
      operatingHours: profile?.operatingHours,
    );
    final today = weekdayKey(TrendaTimezone.now());

    final description = profile?.storeDescription?.trim();
    final category = profile?.category;
    final memberSince = profile?.memberSince;

    final hasAnything = (description != null && description.isNotEmpty) ||
        week.isNotEmpty ||
        category != null ||
        memberSince != null;

    if (!hasAnything) {
      return _emptyTab(
        icon: Icons.info_outline_rounded,
        title: 'Nothing on the noticeboard',
        body: 'This shop has not filled in its details yet.',
      );
    }

    return SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description != null && description.isNotEmpty) ...[
                _aboutHeading('About this shop'),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (week.isNotEmpty) ...[
                _aboutHeading('Opening hours'),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < week.length; i++)
                        _hoursRow(week[i], week[i].day == today, house,
                            last: i == week.length - 1),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (category != null || memberSince != null) ...[
                _aboutHeading('Shop details'),
                const SizedBox(height: 2),
                if (category != null)
                  _aboutRow(Icons.storefront_outlined, 'Type', category),
                if (memberSince != null)
                  _aboutRow(
                    Icons.calendar_today_outlined,
                    'Selling since',
                    '${memberSince.year}',
                  ),
              ],
            ],
          ),
        ));
  }

  Widget _aboutHeading(String text) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      );

  Widget _hoursRow(
    StoreDayHours day,
    bool isToday,
    Color house, {
    required bool last,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isToday ? house.withValues(alpha: 0.07) : null,
        border: last
            ? null
            : Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  day.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    color: scheme.onSurface
                        .withValues(alpha: day.isOpen ? 0.9 : 0.45),
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: house.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: house,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            day.range,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: day.isOpen ? FontWeight.w600 : FontWeight.w500,
              color: day.isOpen
                  ? scheme.onSurface.withValues(alpha: 0.75)
                  : scheme.onSurface.withValues(alpha: 0.38),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
    Color? actionColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 15, color: scheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: onTap != null
                          ? (actionColor ?? scheme.primary)
                          : scheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.north_east_rounded,
                size: 15,
                color: scheme.onSurface.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchExternal(String uri) async {
    final parsed = Uri.tryParse(uri);
    if (parsed == null) return;
    final ok = await launchUrl(parsed, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $uri')),
      );
    }
  }

  Widget _emptyTab({
    required IconData icon,
    required String title,
    required String body,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      size: 30,
                      color: scheme.onSurface.withValues(alpha: 0.35)),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}

// ============================================================================
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Exactly maxExtent tall: a child even a fraction shorter than the
    // declared extent throws "layoutExtent exceeds paintExtent".
    return SizedBox(
      height: maxExtent,
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar;
}
