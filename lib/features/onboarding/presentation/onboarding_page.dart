// lib/features/onboarding/presentation/onboarding_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../design_system/design_system.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      icon: Icons.local_grocery_store_rounded,
      title: 'Discover Local Products',
      description:
          'Fresh, quality products from vendors in your municipality. Support your community by shopping locally for fresh produce, artisanal goods, and everyday essentials.',
      color: const Color(0xFF4CAF50), // Green for products
    ),
    OnboardingSlide(
      icon: Icons.storefront_rounded,
      title: 'Support Local Vendors',
      description:
          'Help small businesses thrive! Every purchase supports local entrepreneurs and keeps money circulating in your municipality. Build lasting relationships with vendors who care.',
      color: const Color(0xFF2196F3), // Blue for vendors
    ),
    OnboardingSlide(
      icon: Icons.delivery_dining_rounded,
      title: 'Fast Local Riders',
      description:
          'Riders from your area delivering to your doorstep. They know your neighborhood streets and landmarks for reliable, quick delivery every time.',
      color: const Color(0xFFFF9800), // Orange for riders
    ),
    OnboardingSlide(
      icon: Icons.location_city_rounded,
      title: 'Strengthen Your Municipality',
      description:
          'Together, we build a stronger local economy. Create jobs, reduce environmental impact, and foster community pride when you shop with Trenda.',
      color: const Color(0xFF9C27B0), // Purple for municipality
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      context.go('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: AppSpacing.paddingMD,
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: Text(
                    'Skip',
                    style: AppTypography.asSecondary(AppTypography.labelLarge),
                  ),
                ),
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return _buildSlide(_slides[index]);
                },
              ),
            ),

            // Indicators and button
            Padding(
              padding: AppSpacing.paddingPage,
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => _buildIndicator(index),
                    ),
                  ),
                  AppSpacing.verticalXL,

                  // Next/Get Started button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        padding: AppSpacing.paddingButton,
                        backgroundColor: _slides[_currentPage].color,
                      ),
                      child: Text(
                        _currentPage == _slides.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: AppTypography.asOnDark(AppTypography.labelLarge),
                      ),
                    ),
                  ),
                  AppSpacing.verticalMD,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(OnboardingSlide slide) {
    return Padding(
      padding: AppSpacing.paddingPage,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: slide.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              slide.icon,
              size: 80,
              color: slide.color,
            ),
          ),
          AppSpacing.verticalXL,

          // Title
          Text(
            slide.title,
            style: AppTypography.headlineLarge,
            textAlign: TextAlign.center,
          ),
          AppSpacing.verticalMD,

          // Description
          Text(
            slide.description,
            style: AppTypography.asSecondary(AppTypography.bodyLarge),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(int index) {
    final isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? _slides[_currentPage].color : AppColors.border,
        borderRadius: AppSpacing.borderRadiusFull,
      ),
    );
  }
}

class OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
