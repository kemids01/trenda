// trenda_shared/lib/widgets/shimmer_loading.dart
// ============================================================================
// SHIMMER LOADING - Skeleton loading placeholders
// ============================================================================

import 'package:flutter/material.dart';

// ============================================================================
// SHIMMER WIDGET
// Creates an animated shimmer effect for loading placeholders
// ============================================================================

class Shimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color baseColor;
  final Color highlightColor;
  final bool enabled;

  const Shimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
    this.enabled = true,
  });

  /// Create shimmer with theme-aware colors
  factory Shimmer.fromTheme({
    Key? key,
    required Widget child,
    required BuildContext context,
    Duration duration = const Duration(milliseconds: 1500),
    bool enabled = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer(
      key: key,
      duration: duration,
      baseColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
      highlightColor: isDark
          ? const Color(0xFF3A3A3A)
          : const Color(0xFFF5F5F5),
      enabled: enabled,
      child: child,
    );
  }

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              transform: _SlidingGradientTransform(
                slidePercent: _controller.value,
              ),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent * 2, 0.0, 0.0);
  }
}

// ============================================================================
// SHIMMER BOX
// Simple rectangular shimmer placeholder
// ============================================================================

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsets? margin;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 4,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE8E8E8);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

// ============================================================================
// SHIMMER CIRCLE
// Circular shimmer placeholder for avatars
// ============================================================================

class ShimmerCircle extends StatelessWidget {
  final double size;
  final EdgeInsets? margin;

  const ShimmerCircle({super.key, this.size = 40, this.margin});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE8E8E8);

    return Container(
      width: size,
      height: size,
      margin: margin,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ============================================================================
// SHIMMER LINE
// Text line placeholder
// ============================================================================

class ShimmerLine extends StatelessWidget {
  final double? width;
  final double height;
  final EdgeInsets? margin;

  const ShimmerLine({super.key, this.width, this.height = 14, this.margin});

  /// Short line (for titles, labels)
  const ShimmerLine.short({super.key, this.height = 14, this.margin})
    : width = 100;

  /// Medium line (for subtitles)
  const ShimmerLine.medium({super.key, this.height = 12, this.margin})
    : width = 150;

  /// Full width line (for paragraphs)
  const ShimmerLine.full({super.key, this.height = 12, this.margin})
    : width = double.infinity;

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      width: width,
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 4),
    );
  }
}

// ============================================================================
// SHIMMER CARD
// Card-shaped shimmer placeholder
// ============================================================================

class ShimmerCard extends StatelessWidget {
  final double? height;
  final double? width;
  final EdgeInsets? margin;
  final Widget? child;

  const ShimmerCard({
    super.key,
    this.height = 120,
    this.width,
    this.margin,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFE8E8E8);

    return Shimmer.fromTheme(
      context: context,
      child: Container(
        width: width,
        height: height,
        margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}

// ============================================================================
// COMMON SHIMMER LAYOUTS
// Pre-built shimmer layouts for common use cases
// ============================================================================

/// List item shimmer (avatar + text lines)
class ShimmerListItem extends StatelessWidget {
  final EdgeInsets padding;
  final double avatarSize;
  final bool showSubtitle;

  const ShimmerListItem({
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.avatarSize = 48,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromTheme(
      context: context,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            ShimmerCircle(size: avatarSize),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerLine.short(),
                  if (showSubtitle) const ShimmerLine.medium(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Product card shimmer
class ShimmerProductCard extends StatelessWidget {
  final double? width;
  final double imageHeight;

  const ShimmerProductCard({super.key, this.width, this.imageHeight = 120});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromTheme(
      context: context,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(
              width: double.infinity,
              height: imageHeight,
              borderRadius: 12,
            ),
            const SizedBox(height: 12),
            const ShimmerLine(width: 100, height: 16),
            const SizedBox(height: 4),
            const ShimmerLine(width: 80, height: 14),
            const SizedBox(height: 8),
            const ShimmerLine(width: 60, height: 16),
          ],
        ),
      ),
    );
  }
}

/// Order card shimmer
class ShimmerOrderCard extends StatelessWidget {
  const ShimmerOrderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromTheme(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const ShimmerLine(width: 80, height: 14),
                ShimmerBox(width: 60, height: 24, borderRadius: 12),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ShimmerBox(width: 60, height: 60, borderRadius: 8),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerLine.medium(),
                      SizedBox(height: 4),
                      ShimmerLine.short(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const ShimmerLine(width: 100, height: 14),
                const ShimmerLine(width: 60, height: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid shimmer (for product grids)
class ShimmerGrid extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;
  final double spacing;
  final double imageHeight;
  final EdgeInsets padding;

  const ShimmerGrid({
    super.key,
    this.crossAxisCount = 2,
    this.itemCount = 6,
    this.spacing = 16,
    this.imageHeight = 120,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: 0.7,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) =>
            ShimmerProductCard(imageHeight: imageHeight),
      ),
    );
  }
}

/// List shimmer
class ShimmerList extends StatelessWidget {
  final int itemCount;
  final EdgeInsets padding;
  final double separatorHeight;

  const ShimmerList({
    super.key,
    this.itemCount = 5,
    this.padding = EdgeInsets.zero,
    this.separatorHeight = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(height: separatorHeight),
      itemBuilder: (context, index) => const ShimmerListItem(),
    );
  }
}
