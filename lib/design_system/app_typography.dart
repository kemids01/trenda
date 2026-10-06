// lib/design_system/app_typography.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Trenda App Typography System
///
/// Provides consistent text styles across the entire app.
/// Based on a type scale with clear hierarchy.
class AppTypography {
  AppTypography._(); // Private constructor

  // ============================================================================
  // FONT FAMILY
  // ============================================================================

  static const String fontFamily =
      'Inter'; // Can be changed to your preferred font

  // ============================================================================
  // DISPLAY STYLES - Large, impactful text
  // ============================================================================

  /// Display Large - 57px, Bold
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 57,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.25,
    color: AppColors.textPrimary,
  );

  /// Display Medium - 45px, Bold
  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 45,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  /// Display Small - 36px, Bold
  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  // ============================================================================
  // HEADLINE STYLES - Page/Section headers
  // ============================================================================

  /// Headline Large - 32px, Bold
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  /// Headline Medium - 28px, SemiBold
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  /// Headline Small - 24px, SemiBold
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  // ============================================================================
  // TITLE STYLES - Card/Component headers
  // ============================================================================

  /// Title Large - 22px, SemiBold
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  /// Title Medium - 16px, SemiBold
  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0.15,
    color: AppColors.textPrimary,
  );

  /// Title Small - 14px, SemiBold
  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  // ============================================================================
  // BODY STYLES - Main content text
  // ============================================================================

  /// Body Large - 16px, Regular
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  /// Body Medium - 14px, Regular
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.25,
    color: AppColors.textPrimary,
  );

  /// Body Small - 12px, Regular
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.4,
    color: AppColors.textPrimary,
  );

  // ============================================================================
  // LABEL STYLES - Buttons, tabs, form labels
  // ============================================================================

  /// Label Large - 14px, Medium
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  /// Label Medium - 12px, Medium
  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  /// Label Small - 11px, Medium
  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  // ============================================================================
  // ECOMMERCE SPECIFIC STYLES
  // ============================================================================

  /// Product Title - 16px, SemiBold
  static const TextStyle productTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  /// Product Price - 20px, Bold, Green
  static const TextStyle productPrice = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0,
    color: AppColors.price,
  );

  /// Product Price Small - 16px, SemiBold, Green
  static const TextStyle productPriceSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0,
    color: AppColors.price,
  );

  /// Original Price (Strikethrough) - 14px, Regular, Gray
  static const TextStyle productPriceOriginal = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: 0,
    color: AppColors.priceOriginal,
    decoration: TextDecoration.lineThrough,
  );

  /// Discount Percentage - 12px, Bold, Red
  static const TextStyle discountBadge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0,
    color: AppColors.discount,
  );

  /// Rating - 14px, SemiBold
  static const TextStyle rating = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  /// Order Number - 16px, Bold, Monospace
  static const TextStyle orderNumber = TextStyle(
    fontFamily: 'monospace',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  /// Badge Text - 12px, SemiBold
  static const TextStyle badge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.3,
  );

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Apply color to text style
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Apply weight to text style
  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    return style.copyWith(fontWeight: weight);
  }

  /// Apply secondary color
  static TextStyle asSecondary(TextStyle style) {
    return style.copyWith(color: AppColors.textSecondary);
  }

  /// Apply tertiary color
  static TextStyle asTertiary(TextStyle style) {
    return style.copyWith(color: AppColors.textTertiary);
  }

  /// Apply disabled color
  static TextStyle asDisabled(TextStyle style) {
    return style.copyWith(color: AppColors.textDisabled);
  }

  /// Apply white color (for dark backgrounds)
  static TextStyle asOnDark(TextStyle style) {
    return style.copyWith(color: AppColors.textOnDark);
  }
}
