// lib/design_system/app_spacing.dart

import 'package:flutter/widgets.dart';

/// Trenda App Spacing System
///
/// Provides consistent spacing throughout the app.
/// Based on an 8pt grid system for harmonious layouts.
class AppSpacing {
  AppSpacing._(); // Private constructor

  // ============================================================================
  // BASE SPACING UNIT (8pt Grid System)
  // ============================================================================

  static const double baseUnit = 8.0;

  // ============================================================================
  // SPACING SCALE
  // ============================================================================

  /// 0px - No spacing
  static const double none = 0;

  /// 2px - Micro spacing
  static const double xxxs = 2;

  /// 4px - Tiny spacing (0.5 × base)
  static const double xxs = 4;

  /// 8px - Extra small (1 × base)
  static const double xs = baseUnit;

  /// 12px - Small (1.5 × base)
  static const double sm = 12;

  /// 16px - Medium (2 × base)
  static const double md = 16;

  /// 20px - Medium-Large (2.5 × base)
  static const double mlg = 20;

  /// 24px - Large (3 × base)
  static const double lg = 24;

  /// 32px - Extra large (4 × base)
  static const double xl = 32;

  /// 40px - 2XL (5 × base)
  static const double xxl = 40;

  /// 48px - 3XL (6 × base)
  static const double xxxl = 48;

  /// 64px - 4XL (8 × base)
  static const double xxxxl = 64;

  // ============================================================================
  // COMMON SPACING COMBINATIONS
  // ============================================================================

  /// Horizontal padding for page content
  static const double pageHorizontal = md;

  /// Vertical padding for page content
  static const double pageVertical = lg;

  /// Spacing between sections
  static const double sectionSpacing = xl;

  /// Spacing between cards/items in a list
  static const double cardSpacing = md;

  /// Inner padding for cards
  static const double cardPadding = md;

  /// Spacing between form fields
  static const double formFieldSpacing = md;

  /// Button internal padding (vertical)
  static const double buttonPaddingVertical = sm;

  /// Button internal padding (horizontal)
  static const double buttonPaddingHorizontal = mlg;

  /// Icon with text spacing
  static const double iconTextSpacing = xs;

  /// Bottom navigation height
  static const double bottomNavHeight = 64;

  /// App bar height
  static const double appBarHeight = 56;

  // ============================================================================
  // EDGE INSETS PRESETS
  // ============================================================================

  /// No padding
  static const EdgeInsets paddingNone = EdgeInsets.zero;

  /// All sides - XXS (4px)
  static const EdgeInsets paddingXXS = EdgeInsets.all(xxs);

  /// All sides - XS (8px)
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);

  /// All sides - SM (12px)
  static const EdgeInsets paddingSM = EdgeInsets.all(sm);

  /// All sides - MD (16px)
  static const EdgeInsets paddingMD = EdgeInsets.all(md);

  /// All sides - LG (24px)
  static const EdgeInsets paddingLG = EdgeInsets.all(lg);

  /// All sides - XL (32px)
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);

  /// Horizontal - MD (16px)
  static const EdgeInsets paddingHorizontalMD =
      EdgeInsets.symmetric(horizontal: md);

  /// Horizontal - LG (24px)
  static const EdgeInsets paddingHorizontalLG =
      EdgeInsets.symmetric(horizontal: lg);

  /// Vertical - MD (16px)
  static const EdgeInsets paddingVerticalMD =
      EdgeInsets.symmetric(vertical: md);

  /// Vertical - LG (24px)
  static const EdgeInsets paddingVerticalLG =
      EdgeInsets.symmetric(vertical: lg);

  /// Page padding (horizontal: 16px, vertical: 24px)
  static const EdgeInsets paddingPage = EdgeInsets.symmetric(
    horizontal: pageHorizontal,
    vertical: pageVertical,
  );

  /// Card padding (16px all sides)
  static const EdgeInsets paddingCard = EdgeInsets.all(cardPadding);

  /// Button padding (horizontal: 20px, vertical: 12px)
  static const EdgeInsets paddingButton = EdgeInsets.symmetric(
    horizontal: buttonPaddingHorizontal,
    vertical: buttonPaddingVertical,
  );

  /// Small button padding (horizontal: 16px, vertical: 8px)
  static const EdgeInsets paddingButtonSmall = EdgeInsets.symmetric(
    horizontal: md,
    vertical: xs,
  );

  /// Large button padding (horizontal: 24px, vertical: 16px)
  static const EdgeInsets paddingButtonLarge = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );

  // ============================================================================
  // SIZED BOX PRESETS (for vertical/horizontal spacing)
  // ============================================================================

  /// Vertical spacing - XXS (4px)
  static const SizedBox verticalXXS = SizedBox(height: xxs);

  /// Vertical spacing - XS (8px)
  static const SizedBox verticalXS = SizedBox(height: xs);

  /// Vertical spacing - SM (12px)
  static const SizedBox verticalSM = SizedBox(height: sm);

  /// Vertical spacing - MD (16px)
  static const SizedBox verticalMD = SizedBox(height: md);

  /// Vertical spacing - LG (24px)
  static const SizedBox verticalLG = SizedBox(height: lg);

  /// Vertical spacing - XL (32px)
  static const SizedBox verticalXL = SizedBox(height: xl);

  /// Vertical spacing - XXL (40px)
  static const SizedBox verticalXXL = SizedBox(height: xxl);

  /// Horizontal spacing - XXS (4px)
  static const SizedBox horizontalXXS = SizedBox(width: xxs);

  /// Horizontal spacing - XS (8px)
  static const SizedBox horizontalXS = SizedBox(width: xs);

  /// Horizontal spacing - SM (12px)
  static const SizedBox horizontalSM = SizedBox(width: sm);

  /// Horizontal spacing - MD (16px)
  static const SizedBox horizontalMD = SizedBox(width: md);

  /// Horizontal spacing - LG (24px)
  static const SizedBox horizontalLG = SizedBox(width: lg);

  /// Horizontal spacing - XL (32px)
  static const SizedBox horizontalXL = SizedBox(width: xl);

  // ============================================================================
  // BORDER RADIUS
  // ============================================================================

  /// No radius
  static const double radiusNone = 0;

  /// Small radius - 4px
  static const double radiusSM = 4;

  /// Medium radius - 8px
  static const double radiusMD = 8;

  /// Large radius - 12px
  static const double radiusLG = 12;

  /// Extra large radius - 16px
  static const double radiusXL = 16;

  /// 2XL radius - 24px
  static const double radiusXXL = 24;

  /// Full/Circular radius - 999px
  static const double radiusFull = 999;

  // BorderRadius presets
  static const BorderRadius borderRadiusNone = BorderRadius.zero;
  static final BorderRadius borderRadiusSM = BorderRadius.circular(radiusSM);
  static final BorderRadius borderRadiusMD = BorderRadius.circular(radiusMD);
  static final BorderRadius borderRadiusLG = BorderRadius.circular(radiusLG);
  static final BorderRadius borderRadiusXL = BorderRadius.circular(radiusXL);
  static final BorderRadius borderRadiusXXL = BorderRadius.circular(radiusXXL);
  static final BorderRadius borderRadiusFull =
      BorderRadius.circular(radiusFull);

  // ============================================================================
  // ICON SIZES
  // ============================================================================

  /// Small icon - 16px
  static const double iconSM = 16;

  /// Medium icon - 24px
  static const double iconMD = 24;

  /// Large icon - 32px
  static const double iconLG = 32;

  /// Extra large icon - 48px
  static const double iconXL = 48;

  /// 2XL icon - 64px
  static const double iconXXL = 64;

  // ============================================================================
  // ELEVATION/SHADOWS
  // ============================================================================

  /// No elevation
  static const double elevationNone = 0;

  /// Low elevation - 2dp
  static const double elevationLow = 2;

  /// Medium elevation - 4dp
  static const double elevationMedium = 4;

  /// High elevation - 8dp
  static const double elevationHigh = 8;

  /// Extra high elevation - 16dp
  static const double elevationXHigh = 16;
}
