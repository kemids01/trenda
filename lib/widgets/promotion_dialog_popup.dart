// lib/widgets/promotion_dialog_popup.dart
// Enhanced Promotion Dialog Popup with animations, loading states, and modern UI
// ============================================================================


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

// ============================================================================
// PROMOTION DIALOG MODEL
// ============================================================================
class PromotionDialogSlide {
  final String id;
  final String photoUrl;
  final String? productId;
  final String? productName;
  final int order;

  PromotionDialogSlide({
    required this.id,
    required this.photoUrl,
    this.productId,
    this.productName,
    required this.order,
  });

  factory PromotionDialogSlide.fromJson(Map<String, dynamic> json) {
    return PromotionDialogSlide(
      id: json['_id'] ?? '',
      photoUrl: json['photoUrl'] ?? '',
      productId: json['productId'],
      productName: json['productName'],
      order: json['order'] ?? 0,
    );
  }
}

class PromotionDialogData {
  final List<PromotionDialogSlide> slides;
  final int autoCloseSeconds;
  final bool showCloseButton;
  final bool showOnEveryVisit;

  PromotionDialogData({
    required this.slides,
    this.autoCloseSeconds = 3,
    this.showCloseButton = true,
    this.showOnEveryVisit = true,
  });

  factory PromotionDialogData.fromJson(Map<String, dynamic> json) {
    final dialog = json['dialog'] ?? json;
    final slides = (dialog['slides'] as List<dynamic>? ?? [])
        .map((s) => PromotionDialogSlide.fromJson(s))
        .toList();
    slides.sort((a, b) => a.order.compareTo(b.order));

    final settings = dialog['settings'] ?? {};
    return PromotionDialogData(
      slides: slides,
      autoCloseSeconds: settings['autoCloseSeconds'] ?? 3,
      showCloseButton: settings['showCloseButton'] ?? true,
      showOnEveryVisit: settings['showOnEveryVisit'] ?? true,
    );
  }

  bool get hasSlides => slides.isNotEmpty;
}

// ============================================================================
// PROMOTION DIALOG POPUP WIDGET
// ============================================================================
class PromotionDialogPopup extends StatefulWidget {
  final PromotionDialogData data;
  final VoidCallback onClose;
  final Function(String slideId)? onImpressionTracked;
  final Function(String slideId, String? productId)? onProductClick;

  const PromotionDialogPopup({
    super.key,
    required this.data,
    required this.onClose,
    this.onImpressionTracked,
    this.onProductClick,
  });

  @override
  State<PromotionDialogPopup> createState() => _PromotionDialogPopupState();
}

class _PromotionDialogPopupState extends State<PromotionDialogPopup>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isClosing = false;
  double _dragOffset = 0.0;
  int _brokenImageCount = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Pulse animation for product CTA
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _trackImpression(0);
  }

  void _closeWithAnimation() {
    if (_isClosing) return;
    _isClosing = true;
    HapticFeedback.lightImpact();
    widget.onClose();
  }

  void _trackImpression(int pageIndex) {
    if (pageIndex < widget.data.slides.length) {
      final slide = widget.data.slides[pageIndex];
      widget.onImpressionTracked?.call(slide.id);
    }
  }

  void _handleProductTap(PromotionDialogSlide slide) {
    if (slide.productId != null) {
      HapticFeedback.mediumImpact();
      widget.onProductClick?.call(slide.id, slide.productId);
      widget.onClose();
    }
  }

  void _onPageChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentPage = index);
    _trackImpression(index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.data.slides;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() => _dragOffset += details.delta.dy);
      },
      onVerticalDragEnd: (details) {
        if (_dragOffset > 100) {
          _closeWithAnimation();
        } else {
          setState(() => _dragOffset = 0.0);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(0, _dragOffset.clamp(0, 200), 0),
        child: AnimatedOpacity(
            duration: const Duration(milliseconds: 100),
            opacity: (1 - (_dragOffset / 300)).clamp(0.3, 1.0),
            child: Material(
              color: Colors.black.withValues(alpha: 0.75),
              child: SafeArea(
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 400),
                    tween: Tween(begin: 0.8, end: 1.0),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) => Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      constraints:
                          const BoxConstraints(maxWidth: 420, maxHeight: 650),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 30,
                            spreadRadius: 8,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header with close button
                            _buildHeader(),

                            // Carousel
                            Flexible(
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: slides.length,
                                onPageChanged: _onPageChanged,
                                itemBuilder: (context, index) {
                                  return _buildSlide(slides[index]);
                                },
                              ),
                            ),

                            // Bottom section with dots and swipe hint
                            _buildBottomSection(slides.length),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Store promo badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.pink.shade400],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_offer, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Store Promo',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          if (widget.data.showCloseButton)
            // Close button
            Material(
              color: Colors.grey.shade100,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _closeWithAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlide(PromotionDialogSlide slide) {
    return GestureDetector(
      onTap: slide.productId != null ? () => _handleProductTap(slide) : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image with shimmer loading
          CachedNetworkImage(
            imageUrl: slide.photoUrl,
            fit: BoxFit.cover,
            placeholder: (ctx, url) => _buildShimmerPlaceholder(),
            errorWidget: (ctx, url, error) {
              // Track broken images and auto-close if all are broken
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _brokenImageCount++;
                if (_brokenImageCount >= widget.data.slides.length) {
                  _closeWithAnimation();
                }
              });
              return Container(
                color: Colors.grey.shade200,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'Image unavailable',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              );
            },
          ),

          // Gradient overlay for better text visibility
          if (slide.productId != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          // Product link indicator with animation
          if (slide.productId != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .primaryColor
                            .withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shopping_bag,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              slide.productName ?? 'View Product',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.touch_app,
                                  size: 12,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Tap to view details',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          // Dots indicator
          if (count > 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(count, (index) {
                final isActive = _currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
          ],
          // Swipe hint
          if (count > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swipe,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  'Swipe to see more (${_currentPage + 1}/$count)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// HELPER: Show Promotion Dialog
// ============================================================================
void showPromotionDialog(
  BuildContext context, {
  required PromotionDialogData data,
  Function(String slideId)? onImpressionTracked,
  Function(String slideId, String? productId)? onProductClick,
}) {
  if (!data.hasSlides) return;

  showGeneralDialog(
    context: context,
    barrierDismissible: data.showCloseButton,
    barrierLabel: 'Promotion Dialog',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 350),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: child,
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return PromotionDialogPopup(
        data: data,
        onClose: () => Navigator.of(context).pop(),
        onImpressionTracked: onImpressionTracked,
        onProductClick: (slideId, productId) {
          onProductClick?.call(slideId, productId);
          if (productId != null && context.mounted) {
            context.push('/product/$productId');
          }
        },
      );
    },
  );
}
