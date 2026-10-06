// trenda_frontend/lib/features/checkout/widgets/pasabay_guide_modal.dart
// Comprehensive onboarding guide explaining how Pasabay delivery works
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PasabayGuideModal extends StatefulWidget {
  final VoidCallback? onDismiss;
  final bool showDontShowAgain;

  const PasabayGuideModal({
    super.key,
    this.onDismiss,
    this.showDontShowAgain = true,
  });

  /// Shows the guide modal if the user hasn't dismissed it permanently
  static Future<void> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('pasabay_guide_dismissed') == true) return;

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PasabayGuideModal(),
    );
  }

  /// Force show the guide (e.g., from "How it works" link)
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PasabayGuideModal(showDontShowAgain: false),
    );
  }

  @override
  State<PasabayGuideModal> createState() => _PasabayGuideModalState();
}

class _PasabayGuideModalState extends State<PasabayGuideModal> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _dontShowAgain = false;

  static const _guidePages = [
    _GuidePageData(
      icon: Icons.groups_rounded,
      iconColor: Color(0xFF4CAF50),
      title: 'What is Pasabay?',
      subtitle: 'Community Batch Delivery',
      description:
          'Pasabay means "ride along" — your order joins a batch with other orders in your barangay. '
          'When the batch is full, a single rider picks up and delivers all orders at once.',
      highlights: [
        'Save up to 70% on delivery fees',
        'Help reduce traffic & carbon emissions',
        'Support your local community',
      ],
    ),
    _GuidePageData(
      icon: Icons.add_shopping_cart_rounded,
      iconColor: Color(0xFF2196F3),
      title: 'How It Works',
      subtitle: 'Step 1: Place Your Order',
      description:
          'Select "Pasabay" as your delivery method at checkout. '
          'You\'ll see available batches in your barangay or a new batch will be created automatically.',
      highlights: [
        'Choose from different batch tiers (Saver, Super Saver)',
        'See real-time batch progress',
        'Know your discounted fee upfront',
      ],
    ),
    _GuidePageData(
      icon: Icons.hourglass_top_rounded,
      iconColor: Color(0xFFFF9800),
      title: 'Wait for Batch',
      subtitle: 'Step 2: Batch Fills Up',
      description:
          'Your order waits in the batch while more neighbors join. '
          'You\'ll get notifications as the batch fills up. '
          'The bigger the batch, the bigger your savings!',
      highlights: [
        'Track batch progress in real-time',
        'Get notified when batch is almost full',
        'Leave anytime before dispatch',
      ],
    ),
    _GuidePageData(
      icon: Icons.delivery_dining_rounded,
      iconColor: Color(0xFF9C27B0),
      title: 'Delivery',
      subtitle: 'Step 3: Rider Delivers',
      description:
          'Once the batch is ready, a rider picks up all orders from vendors '
          'and delivers them door-to-door in your barangay. '
          'Track your delivery in real-time!',
      highlights: [
        'Optimized route for faster delivery',
        'Real-time tracking updates',
        'Rate your rider after delivery',
      ],
    ),
    _GuidePageData(
      icon: Icons.savings_rounded,
      iconColor: Color(0xFF4CAF50),
      title: 'Savings Comparison',
      subtitle: 'Why Choose Pasabay?',
      description: '',
      highlights: [],
      isComparisonPage: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dontShowAgain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pasabay_guide_dismissed', true);
    }
    if (mounted) Navigator.of(context).pop();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Pasabay Guide',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _dismiss,
                  child: const Text('Skip'),
                ),
              ],
            ),
          ),

          // Page indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: List.generate(
                _guidePages.length,
                (i) => Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= _currentPage
                          ? const Color(0xFF4CAF50)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Pages
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _guidePages.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                final page = _guidePages[index];
                if (page.isComparisonPage) {
                  return _buildComparisonPage(theme);
                }
                return _buildGuidePage(page, theme);
              },
            ),
          ),

          // Bottom actions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                if (widget.showDontShowAgain &&
                    _currentPage == _guidePages.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _dontShowAgain,
                            onChanged: (v) =>
                                setState(() => _dontShowAgain = v ?? false),
                            activeColor: const Color(0xFF4CAF50),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Don\'t show this again',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _currentPage < _guidePages.length - 1
                        ? () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            )
                        : _dismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentPage < _guidePages.length - 1
                          ? 'Next'
                          : 'Got it! Let\'s Save',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                SafeArea(top: false, child: const SizedBox(height: 8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidePage(_GuidePageData page, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Icon circle
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.iconColor.withValues(alpha: 0.12),
            ),
            child: Icon(page.icon, size: 40, color: page.iconColor),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            page.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            page.subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: page.iconColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            page.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Highlights
          ...page.highlights.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: page.iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.check_rounded,
                          size: 16, color: page.iconColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        h,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildComparisonPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.savings_rounded,
                size: 40, color: Color(0xFF4CAF50)),
          ),
          const SizedBox(height: 20),
          Text(
            'Save More with Pasabay',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Comparison cards
          _buildComparisonCard(
            theme,
            title: 'Express Delivery',
            fee: '₱50 – ₱80',
            time: '30–60 min',
            icon: Icons.flash_on_rounded,
            color: const Color(0xFFFF5722),
            isPasabay: false,
          ),
          const SizedBox(height: 12),
          _buildComparisonCard(
            theme,
            title: 'Pasabay Saver 5',
            fee: '₱15 – ₱40',
            time: '1–3 hours',
            savings: 'Save up to 50%',
            icon: Icons.groups_rounded,
            color: const Color(0xFF4CAF50),
            isPasabay: true,
          ),
          const SizedBox(height: 12),
          _buildComparisonCard(
            theme,
            title: 'Pasabay Super Saver 10',
            fee: '₱10 – ₱25',
            time: '3–24 hours',
            savings: 'Save up to 70%',
            icon: Icons.star_rounded,
            color: const Color(0xFFFF9800),
            isPasabay: true,
            isBest: true,
          ),
          const SizedBox(height: 16),

          // Reassurance
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded,
                    color: Color(0xFF4CAF50), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You can leave a batch anytime before it\'s dispatched — no commitment!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF2E7D32),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(
    ThemeData theme, {
    required String title,
    required String fee,
    required String time,
    String? savings,
    required IconData icon,
    required Color color,
    required bool isPasabay,
    bool isBest = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPasabay ? color.withValues(alpha: 0.06) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPasabay ? color.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: isBest ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    if (isBest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('BEST',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 9)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(fee,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isPasabay ? color : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(width: 8),
                    Text('• $time',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey[500])),
                  ],
                ),
                if (savings != null) ...[
                  const SizedBox(height: 2),
                  Text(savings,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidePageData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String description;
  final List<String> highlights;
  final bool isComparisonPage;

  const _GuidePageData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.highlights,
    this.isComparisonPage = false,
  });
}
