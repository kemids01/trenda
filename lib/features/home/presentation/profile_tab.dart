// lib/features/home/presentation/profile_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trenda_shared/core/images/image_picker_service.dart';
import 'package:trenda_shared/data/app_config_repository.dart';
import 'package:trenda_shared/trenda_shared.dart' show PhoneValidator;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:trenda_frontend/features/auth/data/providers.dart';
import 'package:trenda_frontend/features/auth/application/state.dart';
import 'package:trenda_frontend/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:trenda_frontend/features/auth/presentation/widgets/facebook_sign_in_button.dart';
import 'package:trenda_frontend/features/home/presentation/password_page.dart';
import 'package:trenda_frontend/features/core/providers/theme_provider.dart';
import 'package:trenda_frontend/features/orders/providers/orders_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../application/user_profile_notifier.dart';
import '../models/profile_models.dart';
import '../utils/linked_accounts.dart';
import '../utils/profile_completion.dart';
import '../../chat/providers/chat_provider.dart';
import '../../stores/utils/storefront_style.dart';
import 'widgets/profile_parts.dart';
import 'package:trenda_shared/core/taps/taps.dart';

/// Password & Security is hidden while Google is the only customer sign-in:
/// there is no password to change. Flip this back on if email/password sign-in
/// returns — the page (PasswordPage) is kept intact.
const bool _kShowPasswordSettings = false;

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  String maskedEmail(String? email) {
    if (email == null || !email.contains('@')) return "***";
    final parts = email.split('@');
    return parts[0].length <= 2
        ? "***@${parts[1]}"
        : "${parts[0].substring(0, 2)}***@${parts[1]}";
  }

  String maskedPhone(String? phone) {
    if (phone == null || phone.length <= 4) return "***";
    return "${'*' * (phone.length - 4)}${phone.substring(phone.length - 4)}";
  }

  void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final firebaseUser = authState.user;
    final profileAsync = ref.watch(userProfileProvider);
    final userProfileNotifier = ref.read(userProfileProvider.notifier);

    // Sign-in happens on this tab now, so its failures surface here.
    // Registered before any early return so it is not attached conditionally.
    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      if (next.errorMsg != null && next.errorMsg != prev?.errorMsg) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.errorMsg!),
          backgroundColor: Colors.red,
        ));
      }
    });

    // 🔹 Show loading while auth is initializing
    if (authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 🔹 Guest view - only show if explicitly unauthenticated with no user.
    // A failed Google sign-in leaves status == error with no user; that is
    // still a guest, and without this it falls through to the profile loader.
    final isGuest = firebaseUser == null &&
        (authState.status == AuthStatus.unauthenticated ||
            authState.status == AuthStatus.error);

    if (isGuest) return _buildGuest(context, ref, authState);

    // 🔹 Logged-in view
    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (profile) {
        final sections = <Widget>[
          _buildShortcuts(context, profile, ref),
          ProfileGroup(
              title: 'Account',
              subtitle: 'Your personal details',
              icon: Icons.person_rounded,
              accent: kProfileBlue,
              rows: _buildAccountRows(
                  context, profile, userProfileNotifier, ref)),
          ProfileGroup(
              title: 'Preferences',
              subtitle: 'App settings and sign-in',
              icon: Icons.tune_rounded,
              accent: kLanePlum,
              rows: _buildPreferenceRows(
                  context, profile, userProfileNotifier, ref)),
          _buildFooter(context, ref),
        ];
        return Scaffold(
          backgroundColor: _canvas(context),
          body: RefreshIndicator(
            onRefresh: () async {
              await userProfileNotifier.reloadProfile();
              ref.invalidate(myOrdersProvider); // Refresh order badge count
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _buildHeader(context, profile, userProfileNotifier, ref),
                for (var i = 0; i < sections.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ProfileReveal(index: i + 1, child: sections[i]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// A quiet neutral canvas; the cards carry the content.
  Color _canvas(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0E1116)
          : const Color(0xFFF3F5F9);

  // ================ GUEST ================
  /// Same hero as the signed-in page, so signing in feels like the card being
  /// filled in rather than a different screen appearing.
  Widget _buildGuest(BuildContext context, WidgetRef ref, AuthState authState) {
    final scheme = Theme.of(context).colorScheme;
    Widget perk(IconData icon, Color accent, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        color: scheme.onSurface.withValues(alpha: 0.8))),
              ),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: _canvas(context),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 36),
        children: [
          const ProfileHero(
            overlap: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroOverline(),
                SizedBox(height: 14),
                Text(
                  'Welcome to\nyour town\'s market.',
                  style: TextStyle(
                    fontSize: 23,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),
                // Says what signing in is actually for, rather than just
                // presenting a Login button with no reason attached.
                Text(
                  'Sign in to place orders, track deliveries, save addresses '
                  'and message the shops you buy from.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Color(0xCCFFFFFF),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Transform.translate(
              offset: const Offset(0, -36),
              child: ProfileCard(
                raised: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      perk(Icons.local_shipping_outlined, kLaneBlue,
                          'Follow every delivery, live, to your door'),
                      perk(Icons.location_on_outlined, kLaneTeal,
                          'Save your addresses for one-tap checkout'),
                      perk(Icons.chat_bubble_outline_rounded, kLaneGold,
                          'Message local shops about any item'),
                      const SizedBox(height: 6),
                      GoogleSignInButton(
                        loading: authState.loadingGoogle,
                        onPressed: authState.loadingFacebook
                            ? null
                            : () => ref
                                .read(authNotifierProvider.notifier)
                                .signInWithGoogle(),
                      ),
                      const SizedBox(height: 10),
                      FacebookSignInButton(
                        loading: authState.loadingFacebook,
                        onPressed: authState.loadingGoogle
                            ? null
                            : () => ref
                                .read(authNotifierProvider.notifier)
                                .signInWithFacebook(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================ HEADER ================
  /// The member card: photo inside a ring that fills with profile completion,
  /// name, email and home town. When the profile is incomplete, ONE pill names
  /// the next missing detail and opens it. The orders strip overlaps the
  /// hero's bottom edge.
  Widget _buildHeader(BuildContext context, UserProfileState profile,
      UserProfileNotifier notifier, WidgetRef ref) {
    final completion = profileCompletion(
      fullName: profile.fullName,
      phone: profile.phone,
      photoUrl: profile.photoURL,
      addressCount: profile.addresses.length,
      birthday: profile.birthday,
    );
    final next = completion.next;
    final hasName = profile.fullName.trim().isNotEmpty;
    // The first saved address stands in for "home"; addresses carry no
    // default flag.
    final homeCity =
        profile.addresses.isEmpty ? null : profile.addresses.first.city.trim();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            ProfileHero(
              overlap: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HeroOverline(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ProfileAvatarRing(
                        photoUrl: profile.photoURL,
                        monogram: storeMonogram(profile.fullName),
                        percent: completion.percent,
                        loading: profile.isLoadingPhoto,
                        onTap: () => TapGuard.run('profile.pickAndUploadPhoto', () => _pickAndUploadPhoto(context, notifier)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => _showEditFullNameDialog(
                                  context, profile, notifier),
                              child: Text(
                                hasName ? profile.fullName : 'Add your name',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: hasName
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile.email ?? profile.phone ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                            const SizedBox(height: 7),
                            _heroPills(context, profile, notifier, ref,
                                completion, next, homeCity),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // The orders panel overlaps the hero's reserved 44px; this is the
            // part of it that sits below the hero.
            const SizedBox(height: 76),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 0,
          child:
              ProfileReveal(index: 0, child: _buildOrdersSummary(context, ref)),
        ),
      ],
    );
  }

  /// City + the one next missing detail, under the name.
  Widget _heroPills(
      BuildContext context,
      UserProfileState profile,
      UserProfileNotifier notifier,
      WidgetRef ref,
      ProfileCompletion completion,
      ProfileGap? next,
      String? homeCity) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (homeCity != null && homeCity.isNotEmpty)
          HeroPill(
            icon: Icons.location_on_rounded,
            text: homeCity,
            onTap: () => context.push('/addresses'),
          ),
        if (next != null)
          HeroPill(
            icon: Icons.add_circle_outline_rounded,
            accent: const Color(0xFFF3D77A),
            text: '${completion.percent}% · Add ${next.label.toLowerCase()}',
            onTap: () => _openGap(context, next.action, profile, notifier, ref),
          )
        else
          const HeroPill(
            icon: Icons.verified_rounded,
            accent: Color(0xFFF3D77A),
            text: 'Profile complete',
          ),
      ],
    );
  }

  void _openGap(BuildContext context, ProfileGapAction action,
      UserProfileState profile, UserProfileNotifier notifier, WidgetRef ref) {
    switch (action) {
      case ProfileGapAction.address:
        context.push('/addresses');
      case ProfileGapAction.phone:
        _showEditPhoneDialog(context, profile.phone ?? '', notifier);
      case ProfileGapAction.name:
        _showEditFullNameDialog(context, profile, notifier);
      case ProfileGapAction.photo:
        _pickAndUploadPhoto(context, notifier);
      case ProfileGapAction.birthday:
        _showBirthdayPicker(context, profile, notifier);
    }
  }

  // ================ ORDERS SUMMARY ================
  /// The three order stages as compact metric tiles in one raised panel;
  /// every tile, and the header action, opens Orders.
  Widget _buildOrdersSummary(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(orderCountsProvider).valueOrNull;
    int? count(String key) => counts == null ? null : (counts[key] ?? 0);
    void open() => context.push('/orders');

    return ProfilePanel(
      raised: true,
      icon: Icons.receipt_long_rounded,
      accent: kProfileBlue,
      title: 'My orders',
      subtitle: 'Track deliveries and past purchases',
      actionLabel: 'View all',
      onAction: open,
      child: Row(
        children: [
          OrderStageCell(
              icon: Icons.hourglass_top_rounded,
              accent: kLaneGold,
              label: 'Pending',
              count: count('pending'),
              onTap: open),
          const SizedBox(width: 8),
          OrderStageCell(
              icon: Icons.local_shipping_rounded,
              accent: kProfileBlue,
              label: 'On the way',
              count: count('active'),
              onTap: open),
          const SizedBox(width: 8),
          OrderStageCell(
              icon: Icons.check_circle_rounded,
              accent: kLaneTeal,
              label: 'Completed',
              count: count('completed'),
              onTap: open),
        ],
      ),
    );
  }

  // ================ SHORTCUTS ================
  /// Every place the profile leads, as one four-column grid — the vendor
  /// dashboard's tool layout. Replaces the separate tiles, "Orders & money"
  /// and "Support" lists, so the page is two rows here instead of three cards.
  Widget _buildShortcuts(
      BuildContext context, UserProfileState profile, WidgetRef ref) {
    final unread = ref.watch(unreadMessagesCountProvider).valueOrNull ?? 0;
    final addresses = profile.addresses.length;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ProfilePanel(
        icon: Icons.apps_rounded,
        accent: kLaneTeal,
        title: 'Shortcuts',
        subtitle: addresses == 0
            ? 'No saved addresses yet'
            : '$addresses saved address${addresses == 1 ? '' : 'es'}',
        child: ProfileToolGrid(tools: [
          ProfileTool(
              icon: Icons.chat_bubble_outline_rounded,
              accent: kLaneBlue,
              label: 'Messages',
              badge: unread,
              onTap: () => context.push('/chat/conversations')),
          ProfileTool(
              icon: Icons.favorite_border_rounded,
              accent: kLaneRed,
              label: 'Wishlist',
              onTap: () => context.push('/wishlist')),
          ProfileTool(
              icon: Icons.card_giftcard_rounded,
              accent: kLaneGold,
              label: 'Gift cards',
              onTap: () => context.push('/gift-cards')),
          ProfileTool(
              icon: Icons.location_on_outlined,
              accent: kLaneTeal,
              label: 'Addresses',
              onTap: () => context.push('/addresses')),
          ProfileTool(
              icon: Icons.calendar_month_outlined,
              accent: kLaneBlue,
              label: 'Installments',
              onTap: () => context.push('/installment/my-applications')),
          ProfileTool(
              icon: Icons.assignment_return_outlined,
              accent: kLanePlum,
              label: 'Returns',
              onTap: () => context.push('/my-returns')),
          ProfileTool(
              icon: Icons.help_outline_rounded,
              accent: kProfileSky,
              label: 'Help & FAQ',
              onTap: () => _showHelpDialog(context)),
          ProfileTool(
              icon: Icons.support_agent_rounded,
              accent: kLaneGold,
              label: 'Contact us',
              onTap: () => _showContactDialog(context)),
        ]),
      ),
    );
  }

  // ================ ACCOUNT ================
  List<Widget> _buildAccountRows(BuildContext context, UserProfileState profile,
      UserProfileNotifier notifier, WidgetRef ref) {
    final birthday = profile.birthday;
    return [
      ProfileRow(
          icon: Icons.person_rounded,
          accent: const Color(0xFF2563EB),
          title: 'Name',
          valueIsPrompt: profile.fullName.trim().isEmpty,
          value: profile.fullName.trim().isEmpty ? 'Add' : profile.fullName,
          onTap: () => _showEditFullNameDialog(context, profile, notifier)),
      // Read-only: customers sign in with Google only, so the address is the
      // Google account's and changing it here would break their sign-in.
      ProfileRow(
          icon: Icons.mail_rounded,
          accent: const Color(0xFF0EA5E9),
          title: 'Email',
          subtitle: 'From your Google sign-in',
          value: maskedEmail(profile.email),
          locked: true),
      ProfileRow(
          icon: Icons.phone_rounded,
          accent: const Color(0xFF16A34A),
          title: 'Phone',
          valueIsPrompt: (profile.phone ?? '').isEmpty,
          value: (profile.phone ?? '').isEmpty
              ? 'Add'
              : maskedPhone(profile.phone),
          onTap: () =>
              _showEditPhoneDialog(context, profile.phone ?? '', notifier)),
      ProfileRow(
          icon: Icons.cake_rounded,
          accent: const Color(0xFFEC4899),
          title: 'Birthday',
          valueIsPrompt: birthday == null,
          value: birthday == null
              ? 'Add'
              : DateFormat('MMM d, y').format(birthday),
          onTap: () => TapGuard.run('profile.showBirthdayPicker', () => _showBirthdayPicker(context, profile, notifier))),
      if (_kShowPasswordSettings)
        ProfileRow(
            icon: Icons.lock_rounded,
            accent: const Color(0xFF64748B),
            title: 'Password & security',
            onTap: () => _openPasswordPage(context, ref)),
    ];
  }

  void _openPasswordPage(BuildContext context, WidgetRef ref) {
    final user = ref.read(authNotifierProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to change password')),
      );
      return;
    }
    final hasPasswordProvider =
        user.providerData.any((p) => p.providerId == 'password');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PasswordPage(
          user: user,
          // isLinking = true for users who don't have password yet (Google-only)
          isLinking: !hasPasswordProvider,
        ),
      ),
    );
  }

  // ================ PREFERENCES ================
  List<Widget> _buildPreferenceRows(BuildContext context,
      UserProfileState profile, UserProfileNotifier notifier, WidgetRef ref) {
    final themeNotifier = ref.read(themeProvider.notifier);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    return [
      ProfileRow(
          icon: Icons.dark_mode_rounded,
          accent: const Color(0xFF4F46E5),
          title: 'Dark mode',
          trailing: Switch.adaptive(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            value: isDark,
            onChanged: (v) =>
                themeNotifier.setTheme(v ? ThemeMode.dark : ThemeMode.light),
          )),
      ProfileRow(
          icon: Icons.notifications_rounded,
          accent: const Color(0xFFF59E0B),
          title: 'Notifications',
          subtitle: 'Push notifications',
          trailing: Switch.adaptive(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            value: profile.preferences.pushNotifications,
            onChanged: (v) => notifier.updatePreferences(
              profile.preferences.copyWith(pushNotifications: v),
            ),
          )),
      ProfileRow(
          icon: Icons.key_rounded,
          accent: const Color(0xFF0F766E),
          title: 'Sign-in methods',
          // Says what is actually linked, not the list of everything the app
          // happens to support.
          value: linkedAccountsSummary(_linkedAccountsFor(ref)),
          onTap: () => _showLinkedAccountsSheet(context, profile, ref)),
      ProfileRow(
          icon: Icons.description_rounded,
          accent: const Color(0xFF64748B),
          title: 'Terms & privacy',
          onTap: () => _showTermsDialog(context)),
    ];
  }

  /// The sign-in methods really attached to this account.
  ///
  /// This used to hardcode a Google row and a Phone row and fill them from the
  /// profile's email/phone, so an email-and-password user was told their Google
  /// account was linked when it never had been. Firebase's providerData is the
  /// only thing that actually knows.
  List<LinkedAccount> _linkedAccountsFor(WidgetRef ref) {
    final user = ref.read(authNotifierProvider).user;
    return linkedAccounts(
      (user?.providerData ?? const <UserInfo>[])
          .map((p) => (
                providerId: p.providerId,
                email: p.email,
                phoneNumber: p.phoneNumber,
              ))
          .toList(),
    );
  }

  IconData _providerIcon(String providerId) {
    switch (providerId) {
      case kGoogleProvider:
        return Icons.g_mobiledata_rounded;
      case kFacebookProvider:
        return Icons.facebook_rounded;
      case kPhoneProvider:
        return Icons.phone_rounded;
      case kPasswordProvider:
        return Icons.password_rounded;
      case kAppleProvider:
        return Icons.apple_rounded;
      default:
        return Icons.link_rounded;
    }
  }

  void _showLinkedAccountsSheet(
      BuildContext context, UserProfileState profile, WidgetRef ref) {
    final accounts = _linkedAccountsFor(ref);
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sign-in methods',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'How you can get into this account',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 14),
              for (final account in accounts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withValues(
                            alpha: account.isLinked ? 0.07 : 0.04,
                          ),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          _providerIcon(account.providerId),
                          size: 19,
                          color: scheme.onSurface.withValues(
                            alpha: account.isLinked ? 0.75 : 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.label,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface.withValues(
                                  alpha: account.isLinked ? 1 : 0.55,
                                ),
                              ),
                            ),
                            Text(
                              account.detail ??
                                  (account.isLinked ? 'Linked' : 'Not linked'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        account.isLinked
                            ? Icons.check_circle_rounded
                            : Icons.remove_circle_outline_rounded,
                        size: 18,
                        color: account.isLinked
                            ? const Color(0xFF157347)
                            : scheme.onSurface.withValues(alpha: 0.25),
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

  // ================ SUPPORT ================
  // Help and Contact live in the Shortcuts grid; Terms in Preferences.

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help & FAQ'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Frequently asked questions',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• How do I track my order?\n'
                  '  Go to Orders and tap an order to see live status.'),
              SizedBox(height: 6),
              Text('• How do I add a delivery address?\n'
                  '  Profile > Addresses > Add address.'),
              SizedBox(height: 6),
              Text('• A store shows as closed.\n'
                  '  Closed stores can be browsed but not ordered from until they reopen.'),
              SizedBox(height: 6),
              Text('• How do I request a return?\n'
                  '  Open the delivered order and tap Request Return.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showContactDialog(BuildContext context) async {
    // Support contact is admin-configurable (Settings → platform.supportEmail/Phone).
    final cfg = await AppConfigRepository.fetch();
    final email = (cfg?.platform['supportEmail']?.isNotEmpty ?? false)
        ? cfg!.platform['supportEmail']!
        : 'support@trenda.com';
    final phone = (cfg?.platform['supportPhone']?.isNotEmpty ?? false)
        ? cfg!.platform['supportPhone']!
        : '+63 917 000 0000';
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contact Us'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('We usually reply within 24 hours.'),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.email_outlined, size: 18),
              const SizedBox(width: 8),
              SelectableText(email),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.phone_outlined, size: 18),
              const SizedBox(width: 8),
              SelectableText(phone),
            ]),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms & Privacy'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Terms of Service',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                  'By using Trenda you agree to purchase from independent local '
                  'stores via the platform. Orders, fees, and delivery are subject '
                  'to each store\'s availability and the platform\'s policies.'),
              SizedBox(height: 12),
              Text('Privacy', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              // privacy@trenda.ph is the documented mailbox for this entity;
              // the address here used to be support@trenda.com, which is not a
              // Trenda address at all.
              Text(
                  'We use your account and address details only to process orders '
                  'and deliveries. We do not sell your personal data. Contact '
                  'privacy@trenda.ph for data requests.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ================ FOOTER ================
  Widget _buildFooter(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 42,
          // A white button like the cards above it, no outline; the red
          // label and icon carry the "this ends your session" signal.
          child: TextButton.icon(
            onPressed: () => _showLogoutDialog(context, ref),
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Sign out',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(
              foregroundColor: scheme.error,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF171B22)
                  : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // The real build, read from the bundle — this was hardcoded to
        // "v1.0.0", so every release claimed to be the first one and a
        // support conversation could not trust it.
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            return Text(
              info == null
                  ? 'TRENDA'
                  : 'TRENDA  ·  v${info.version} (${info.buildNumber})',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.35),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            );
          },
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authNotifierProvider.notifier).signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(
      BuildContext context, UserProfileNotifier notifier) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await ImagePickerService()
        .pickImage(source: source, maxWidth: 512, quality: 85);
    if (picked != null) {
      await notifier.updatePhoto(picked);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo updated!')),
        );
      }
    }
  }

  // ---------------- DIALOG HELPERS ----------------

  void _showEditPhoneDialog(
      BuildContext context, String currentPhone, UserProfileNotifier notifier) {
    final controller = TextEditingController(text: currentPhone);
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);
    // The black screen after Save: a save waits on the server (a Render cold
    // start is up to a minute), the button gave no sign of it, and every tap
    // that finished called Navigator.pop again — the dialog, then Profile, then
    // the main screen, leaving go_router with no page at all. So: one save at a
    // time, a spinner while it runs, and at most one pop, with the dialog's own
    // context, only while the dialog is still open.
    final saving = ValueNotifier<bool>(false);
    var open = true;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Phone Number'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '09XX XXX XXXX',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (v) {
              final r = PhoneValidator.validate(v?.trim());
              return r.isValid
                  ? null
                  : (r.errorMessage ?? 'Invalid phone number');
            },
          ),
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: saving,
            builder: (_, busy, __) => TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: saving,
            builder: (_, busy, __) => ElevatedButton(
              onPressed: busy
                  ? null
                  : () => TapGuard.run('profile.update@1042', () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      saving.value = true;
                      final saved =
                          await notifier.updatePhone(controller.text.trim());
                      if (!open || !dialogContext.mounted) return;
                      saving.value = false;
                      if (!saved) {
                        messenger.showSnackBar(const SnackBar(
                          content: Text(
                              'Could not save your phone number. Please try again.'),
                          backgroundColor: Colors.red,
                        ));
                        return;
                      }
                      Navigator.pop(dialogContext);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Phone updated ✅')),
                      );
                    }),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    ).whenComplete(() => open = false); // closed by any means: Save, Cancel, back, barrier
  }

  void _showEditFullNameDialog(BuildContext context, UserProfileState state,
      UserProfileNotifier notifier) {
    final firstNameController =
        TextEditingController(text: state.firstName ?? '');
    final middleNameController =
        TextEditingController(text: state.middleName ?? '');
    final surnameController = TextEditingController(text: state.surname ?? '');

    final messenger = ScaffoldMessenger.of(context);
    // Pop with dialogContext — the page's `context` pops the Profile page
    // from under the dialog, and only once (see _showEditPhoneDialog).
    var open = true;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Full Name'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: middleNameController,
                decoration: const InputDecoration(
                  labelText: 'Middle Name (optional)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: surnameController,
                decoration: const InputDecoration(
                  labelText: 'Surname',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => TapGuard.run('profile.update@1127', () async {
              await notifier.updatePersonalInfo(
                firstName: firstNameController.text.trim(),
                middleName: middleNameController.text.trim(),
                surname: surnameController.text.trim(),
              );
              if (open && dialogContext.mounted) {
                Navigator.pop(dialogContext);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Name updated ✅')),
                );
              }
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(() => open = false);
  }

  Future<void> _showBirthdayPicker(BuildContext context, UserProfileState state,
      UserProfileNotifier notifier) async {
    final now = DateTime.now();
    final initialDate = state.birthday ?? DateTime(now.year - 25, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select your birthday',
    );

    if (picked != null && context.mounted) {
      await notifier.updatePersonalInfo(birthday: picked);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Birthday updated ✅')),
        );
      }
    }
  }
}

/// The small tracked label at the top of the hero, with the gold rule that
/// ties it to the brand mark.
class _HeroOverline extends StatelessWidget {
  const _HeroOverline();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 2,
          decoration: BoxDecoration(
            color: kProfileGold,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'MY TRENDA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}
