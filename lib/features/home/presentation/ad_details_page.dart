import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_shared/models/ad_model.dart';
import 'package:trenda_shared/models/ad_placement.dart' show kAdListingImageAspect;
import 'package:trenda_shared/widgets/map_pin_button.dart';
import 'package:trenda_shared/data/ads_repository.dart';
import '../../ads/utils/ad_click_handler.dart';
import '../../../widgets/ad_transparency_modal.dart';
import 'package:trenda_shared/core/timezone.dart';
import 'package:intl/intl.dart';

class AdDetailsPage extends ConsumerStatefulWidget {
  final AdModel ad;
  const AdDetailsPage({super.key, required this.ad});

  @override
  ConsumerState<AdDetailsPage> createState() => _AdDetailsPageState();
}

class _AdDetailsPageState extends ConsumerState<AdDetailsPage> {
  final PageController _pageController = PageController();
  int _currentPhotoIndex = 0;
  bool _viewTracked = false;

  @override
  void initState() {
    super.initState();
    _trackView();
  }

  Future<void> _trackView() async {
    if (_viewTracked) return;
    _viewTracked = true;
    try {
      await AdsRepository().trackAdView(widget.ad.id);
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final theme = Theme.of(context);
    final hasAction = ad.action != null && ad.action!['type'] != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // ─── Collapsing Image Header ───
          SliverAppBar(
            // 6:5 like the list card, so the 1200×1000 ad image shows whole.
            expandedHeight: MediaQuery.sizeOf(context).width / kAdListingImageAspect,
            pinned: true,
            backgroundColor: Colors.black,
            leading: _circleButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
            actions: [
              _circleButton(
                icon: Icons.share_outlined,
                onTap: () => _shareAd(context, ad),
              ),
              _circleButton(
                icon: Icons.flag_outlined,
                onTap: () => AdTransparencyModal.show(context, {
                  'id': ad.id,
                  'vendorName': ad.businessName,
                  'targeting': {
                    'municipality': ad.municipalities.isNotEmpty
                        ? ad.municipalities.first
                        : null,
                    'locationBased': ad.municipalities.isNotEmpty,
                  },
                }),
              ),
              _circleButton(
                icon: Icons.info_outline,
                onTap: () => _showTransparencyInfo(context, ad),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: ad.photos.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: ad.photos.length,
                          onPageChanged: (i) =>
                              setState(() => _currentPhotoIndex = i),
                          itemBuilder: (_, i) => Image.network(
                            ad.photos[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade800,
                              child: const Icon(Icons.broken_image,
                                  color: Colors.white54, size: 48),
                            ),
                          ),
                        ),
                        // Gradient overlay
                        const Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 80,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black87, Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                        // Photo indicators
                        if (ad.photos.length > 1)
                          Positioned(
                            bottom: 12,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                ad.photos.length,
                                (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  width: i == _currentPhotoIndex ? 24 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: i == _currentPhotoIndex
                                        ? Colors.white
                                        : Colors.white38,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Sponsored label
                        Positioned(
                          top: 96,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Sponsored',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ),
                        // Featured badge
                        if (ad.featured)
                          Positioned(
                            top: 96,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star,
                                      size: 12, color: Colors.black87),
                                  SizedBox(width: 4),
                                  Text('FEATURED',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.campaign,
                          size: 80, color: Colors.white24),
                    ),
            ),
          ),

          // ─── Body Content ───
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Business Header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ad.businessName,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (ad.title.isNotEmpty && ad.title != ad.businessName)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(ad.title,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: Colors.grey[600])),
                        ),
                      if (ad.municipalities.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: ad.municipalities
                                .map((m) => Chip(
                                      avatar: const Icon(Icons.location_on,
                                          size: 14),
                                      label: Text(m,
                                          style: const TextStyle(fontSize: 11)),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      backgroundColor: Colors.blue[50],
                                      side: BorderSide.none,
                                    ))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),

                // Verified Business & Trust Badge
                Container(
                  color: Colors.white,
                  margin: const EdgeInsets.only(top: 1),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified,
                                size: 14, color: Colors.blue[700]),
                            const SizedBox(width: 4),
                            Text('Verified Business',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700])),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined,
                                size: 14, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text('Ad Reviewed',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Days Remaining Indicator
                if (ad.daysRemaining != null)
                  Container(
                    color: Colors.white,
                    margin: const EdgeInsets.only(top: 1),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: ad.daysRemaining! <= 3
                              ? Colors.red[600]
                              : ad.daysRemaining! <= 7
                                  ? Colors.orange[600]
                                  : Colors.green[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ad.isExpired
                              ? 'This ad has expired'
                              : ad.daysRemaining! <= 3
                                  ? 'Ending soon — ${ad.daysRemaining} day${ad.daysRemaining == 1 ? '' : 's'} left'
                                  : '${ad.daysRemaining} days remaining',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ad.daysRemaining! <= 3
                                ? Colors.red[600]
                                : ad.daysRemaining! <= 7
                                    ? Colors.orange[600]
                                    : Colors.green[600],
                          ),
                        ),
                        if (ad.endDate != null) ...[
                          const Spacer(),
                          Text(
                            'Ends ${DateFormat('d/M/y').formatPh(ad.endDate!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // Description
                if (ad.description != null && ad.description!.isNotEmpty)
                  Container(
                    color: Colors.white,
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('About'),
                        const SizedBox(height: 8),
                        Text(ad.description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5, color: Colors.grey[700])),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // Contact & Social — the pin joins the gate, or an ad whose only
                // detail is its location renders no card at all.
                if ((ad.contact != null && ad.contact!.isNotEmpty) ||
                    ad.socialLinks.isNotEmpty ||
                    ad.location != null)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Contact'),
                        const SizedBox(height: 8),
                        if (ad.contact != null && ad.contact!.isNotEmpty)
                          _infoTile(Icons.phone_outlined, 'Phone', ad.contact!),
                        if (ad.socialLinks.containsKey('facebook'))
                          _infoTile(Icons.facebook, 'Facebook',
                              ad.socialLinks['facebook']!),
                        if (ad.socialLinks.containsKey('instagram'))
                          _infoTile(Icons.camera_alt_outlined, 'Instagram',
                              ad.socialLinks['instagram']!),
                        if (ad.socialLinks.containsKey('website'))
                          _infoTile(Icons.language, 'Website',
                              ad.socialLinks['website']!),
                        if (ad.location != null) ...[
                          const SizedBox(height: 10),
                          MapPinButton(location: ad.location),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // Products
                if (ad.productNames.isNotEmpty)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Products'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ad.productNames
                              .map((p) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.green.shade200),
                                    ),
                                    child: Text(p,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green[800])),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 80), // Bottom padding for FAB
              ],
            ),
          ),
        ],
      ),

      // ─── Bottom Action Bar ───
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Primary CTA
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    try {
                      await AdsRepository().trackAdClick(ad.id);
                    } catch (_) {}
                    if (!context.mounted) return;

                    if (hasAction) {
                      handleAdClick(context, ad);
                    } else {
                      context.push('/store/${ad.ownerId}');
                    }
                  },
                  icon: Icon(_getActionIcon(ad.action)),
                  label: Text(_getActionLabel(ad.action)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ───

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: onTap,
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.black38,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3));
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getActionIcon(Map<String, dynamic>? action) {
    final type = action?['type'];
    if (type == 'store') return Icons.storefront;
    if (type == 'product') return Icons.shopping_bag;
    if (type == 'url') return Icons.open_in_new;
    return Icons.storefront;
  }

  String _getActionLabel(Map<String, dynamic>? action) {
    final type = action?['type'];
    if (type == 'store') return 'Visit Store';
    if (type == 'product') return 'View Product';
    if (type == 'url') return 'Learn More';
    return 'Visit Store';
  }

  void _shareAd(BuildContext context, AdModel ad) {
    final text = ad.title.isNotEmpty && ad.title != ad.businessName
        ? 'Check out ${ad.businessName} — ${ad.title} on Trenda!'
        : 'Check out ${ad.businessName} on Trenda!';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Ad link copied to clipboard'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showTransparencyInfo(BuildContext context, AdModel ad) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text('Why am I seeing this ad?',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _transparencyRow(Icons.campaign, 'Sponsored content',
                'This is a paid advertisement by ${ad.businessName}.'),
            if (ad.municipalities.isNotEmpty)
              _transparencyRow(Icons.location_on, 'Location targeting',
                  'Targeted to: ${ad.municipalities.join(', ')}.'),
            _transparencyRow(Icons.shield_outlined, 'Ad guidelines',
                'All ads are reviewed and approved by Trenda before display.'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _transparencyRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(desc,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
