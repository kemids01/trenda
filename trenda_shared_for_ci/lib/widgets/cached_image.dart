// trenda_shared/lib/widgets/cached_image.dart
// ============================================================================
// CACHED PRODUCT IMAGE
// Reusable widget for loading and caching network images with placeholders
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Cached network image with shimmer loading and error handling
class TrendaCachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const TrendaCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ??
          _ShimmerPlaceholder(
            width: width,
            height: height,
            colorScheme: colorScheme,
          ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          _ErrorPlaceholder(
            width: width,
            height: height,
            colorScheme: colorScheme,
          ),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 200),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}

/// Product image with aspect ratio and rounded corners
class ProductImage extends StatelessWidget {
  final String imageUrl;
  final double size;
  final double borderRadius;

  const ProductImage({
    super.key,
    required this.imageUrl,
    this.size = 80,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return TrendaCachedImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }
}

/// Store logo/banner image
class StoreImage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final bool isLogo;

  const StoreImage({
    super.key,
    required this.imageUrl,
    this.width = 100,
    this.height = 100,
    this.isLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return TrendaCachedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      borderRadius: isLogo ? BorderRadius.circular(12) : BorderRadius.zero,
    );
  }
}

/// User avatar image
class AvatarImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final String fallbackText;

  const AvatarImage({
    super.key,
    this.imageUrl,
    this.size = 40,
    this.fallbackText = '?',
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _AvatarFallback(size: size, text: fallbackText);
    }

    return ClipOval(
      child: TrendaCachedImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        errorWidget: _AvatarFallback(size: size, text: fallbackText),
      ),
    );
  }
}

// ============================================================================
// PRIVATE WIDGETS
// ============================================================================

class _ShimmerPlaceholder extends StatefulWidget {
  final double? width;
  final double? height;
  final ColorScheme colorScheme;

  const _ShimmerPlaceholder({
    this.width,
    this.height,
    required this.colorScheme,
  });

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [
                widget.colorScheme.surfaceContainerHighest,
                widget.colorScheme.surfaceContainerLow,
                widget.colorScheme.surfaceContainerHighest,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final ColorScheme colorScheme;

  const _ErrorPlaceholder({this.width, this.height, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          size: (width ?? height ?? 48) / 3,
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final double size;
  final String text;

  const _AvatarFallback({required this.size, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          text.isNotEmpty ? text[0].toUpperCase() : '?',
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontSize: size / 2.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
