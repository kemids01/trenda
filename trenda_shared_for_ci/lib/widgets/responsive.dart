// trenda_shared/lib/widgets/responsive.dart
// ============================================================================
// RESPONSIVE LAYOUT - Responsive design helpers and breakpoints
// ============================================================================

import 'package:flutter/material.dart';

// ============================================================================
// BREAKPOINTS
// ============================================================================

/// Standard breakpoints for responsive design
abstract class Breakpoints {
  static const double xs = 0;
  static const double sm = 576;
  static const double md = 768;
  static const double lg = 992;
  static const double xl = 1200;
  static const double xxl = 1400;
}

/// Screen size category
enum ScreenSize { xs, sm, md, lg, xl, xxl }

/// Get the current screen size category
ScreenSize getScreenSize(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;

  if (width >= Breakpoints.xxl) return ScreenSize.xxl;
  if (width >= Breakpoints.xl) return ScreenSize.xl;
  if (width >= Breakpoints.lg) return ScreenSize.lg;
  if (width >= Breakpoints.md) return ScreenSize.md;
  if (width >= Breakpoints.sm) return ScreenSize.sm;
  return ScreenSize.xs;
}

// ============================================================================
// RESPONSIVE BUILDER
// ============================================================================

/// Build different widgets based on screen size
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize screenSize) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return builder(context, getScreenSize(context));
  }
}

/// Build different layouts for mobile, tablet, and desktop
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final size = getScreenSize(context);

    switch (size) {
      case ScreenSize.xl:
      case ScreenSize.xxl:
        return desktop ?? tablet ?? mobile;
      case ScreenSize.md:
      case ScreenSize.lg:
        return tablet ?? mobile;
      case ScreenSize.xs:
      case ScreenSize.sm:
        return mobile;
    }
  }
}

// ============================================================================
// RESPONSIVE VALUE
// ============================================================================

/// Get a value based on screen size
class ResponsiveValue<T> {
  final T xs;
  final T? sm;
  final T? md;
  final T? lg;
  final T? xl;
  final T? xxl;

  const ResponsiveValue({
    required this.xs,
    this.sm,
    this.md,
    this.lg,
    this.xl,
    this.xxl,
  });

  /// Create with just mobile and desktop values
  const ResponsiveValue.simple({required T mobile, required T desktop})
    : xs = mobile,
      sm = null,
      md = null,
      lg = desktop,
      xl = null,
      xxl = null;

  /// Get the value for the current screen size
  T get(BuildContext context) {
    final size = getScreenSize(context);

    return switch (size) {
      ScreenSize.xxl => xxl ?? xl ?? lg ?? md ?? sm ?? xs,
      ScreenSize.xl => xl ?? lg ?? md ?? sm ?? xs,
      ScreenSize.lg => lg ?? md ?? sm ?? xs,
      ScreenSize.md => md ?? sm ?? xs,
      ScreenSize.sm => sm ?? xs,
      ScreenSize.xs => xs,
    };
  }
}

/// Extension for using ResponsiveValue easily
extension ResponsiveValueExtension on BuildContext {
  T responsive<T>(ResponsiveValue<T> value) => value.get(this);
}

// ============================================================================
// RESPONSIVE PADDING
// ============================================================================

class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets mobile;
  final EdgeInsets? tablet;
  final EdgeInsets? desktop;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.mobile = const EdgeInsets.all(16),
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final size = getScreenSize(context);
    final padding = switch (size) {
      ScreenSize.xl || ScreenSize.xxl => desktop ?? tablet ?? mobile,
      ScreenSize.md || ScreenSize.lg => tablet ?? mobile,
      _ => mobile,
    };

    return Padding(padding: padding, child: child);
  }
}

// ============================================================================
// RESPONSIVE GRID
// ============================================================================

/// Grid that adjusts columns based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final double spacing;
  final double runSpacing;
  final double? childAspectRatio;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns,
    this.desktopColumns,
    this.spacing = 16,
    this.runSpacing = 16,
    this.childAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    final size = getScreenSize(context);
    final columns = switch (size) {
      ScreenSize.xl ||
      ScreenSize.xxl => desktopColumns ?? tabletColumns ?? mobileColumns,
      ScreenSize.md || ScreenSize.lg => tabletColumns ?? mobileColumns,
      _ => mobileColumns,
    };

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: runSpacing,
        childAspectRatio: childAspectRatio ?? 1,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

// ============================================================================
// RESPONSIVE VISIBILITY
// ============================================================================

/// Show/hide widgets based on screen size
class ResponsiveVisibility extends StatelessWidget {
  final Widget child;
  final bool visibleOnMobile;
  final bool visibleOnTablet;
  final bool visibleOnDesktop;
  final Widget replacement;

  const ResponsiveVisibility({
    super.key,
    required this.child,
    this.visibleOnMobile = true,
    this.visibleOnTablet = true,
    this.visibleOnDesktop = true,
    this.replacement = const SizedBox.shrink(),
  });

  /// Only visible on mobile
  const ResponsiveVisibility.mobileOnly({
    super.key,
    required this.child,
    this.replacement = const SizedBox.shrink(),
  }) : visibleOnMobile = true,
       visibleOnTablet = false,
       visibleOnDesktop = false;

  /// Only visible on tablet and up
  const ResponsiveVisibility.tabletUp({
    super.key,
    required this.child,
    this.replacement = const SizedBox.shrink(),
  }) : visibleOnMobile = false,
       visibleOnTablet = true,
       visibleOnDesktop = true;

  /// Only visible on desktop
  const ResponsiveVisibility.desktopOnly({
    super.key,
    required this.child,
    this.replacement = const SizedBox.shrink(),
  }) : visibleOnMobile = false,
       visibleOnTablet = false,
       visibleOnDesktop = true;

  @override
  Widget build(BuildContext context) {
    final size = getScreenSize(context);

    final isVisible = switch (size) {
      ScreenSize.xl || ScreenSize.xxl => visibleOnDesktop,
      ScreenSize.md || ScreenSize.lg => visibleOnTablet,
      _ => visibleOnMobile,
    };

    return isVisible ? child : replacement;
  }
}

// ============================================================================
// MAX WIDTH CONSTRAINT
// ============================================================================

/// Constrain content to a maximum width, centered
class MaxWidthContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;

  const MaxWidthContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}

// ============================================================================
// RESPONSIVE EXTENSIONS
// ============================================================================

extension ResponsiveExtension on BuildContext {
  /// Get current screen size
  ScreenSize get screenSize => getScreenSize(this);

  /// Check if mobile
  bool get isMobile =>
      screenSize == ScreenSize.xs || screenSize == ScreenSize.sm;

  /// Check if tablet
  bool get isTablet =>
      screenSize == ScreenSize.md || screenSize == ScreenSize.lg;

  /// Check if desktop
  bool get isDesktop =>
      screenSize == ScreenSize.xl || screenSize == ScreenSize.xxl;

  /// Get value based on screen size
  T responsiveValue<T>({required T mobile, T? tablet, T? desktop}) {
    if (isDesktop) return desktop ?? tablet ?? mobile;
    if (isTablet) return tablet ?? mobile;
    return mobile;
  }
}
