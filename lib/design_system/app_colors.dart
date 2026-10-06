// lib/design_system/app_colors.dart

import 'package:flutter/material.dart';

/// Trenda App Color Palette
///
/// Provides a consistent color system across the entire app.
/// Based on Material Design 3 principles with custom branding.
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ============================================================================
  // PRIMARY COLORS - Brand Identity
  // ============================================================================

  /// Primary brand color - Used for main actions, highlights
  static const Color primary = Color(0xFF2563EB); // Blue-600
  static const Color primaryDark = Color(0xFF1E40AF); // Blue-700
  static const Color primaryLight = Color(0xFF3B82F6); // Blue-500
  static const Color primaryLighter = Color(0xFF60A5FA); // Blue-400

  /// Primary color variants for different states
  static const Color primaryContainer = Color(0xFFEFF6FF); // Blue-50
  static const Color onPrimary = Color(0xFFFFFFFF); // White
  static const Color onPrimaryContainer = Color(0xFF1E3A8A); // Blue-900

  // ============================================================================
  // SECONDARY COLORS - Accents & Supporting Elements
  // ============================================================================

  static const Color secondary = Color(0xFF7C3AED); // Violet-600
  static const Color secondaryDark = Color(0xFF6D28D9); // Violet-700
  static const Color secondaryLight = Color(0xFF8B5CF6); // Violet-500

  static const Color secondaryContainer = Color(0xFFF5F3FF); // Violet-50
  static const Color onSecondary = Color(0xFFFFFFFF); // White
  static const Color onSecondaryContainer = Color(0xFF4C1D95); // Violet-900

  // ============================================================================
  // SEMANTIC COLORS - Status & Feedback
  // ============================================================================

  /// Success - Confirmations, positive states
  static const Color success = Color(0xFF10B981); // Green-500
  static const Color successDark = Color(0xFF059669); // Green-600
  static const Color successLight = Color(0xFF34D399); // Green-400
  static const Color successContainer = Color(0xFFECFDF5); // Green-50
  static const Color onSuccess = Color(0xFFFFFFFF);

  /// Error - Errors, destructive actions
  static const Color error = Color(0xFFEF4444); // Red-500
  static const Color errorDark = Color(0xFFDC2626); // Red-600
  static const Color errorLight = Color(0xFFF87171); // Red-400
  static const Color errorContainer = Color(0xFFFEF2F2); // Red-50
  static const Color onError = Color(0xFFFFFFFF);

  /// Warning - Cautions, important notices
  static const Color warning = Color(0xFFF59E0B); // Amber-500
  static const Color warningDark = Color(0xFFD97706); // Amber-600
  static const Color warningLight = Color(0xFFFBBF24); // Amber-400
  static const Color warningContainer = Color(0xFFFFFBEB); // Amber-50
  static const Color onWarning = Color(0xFFFFFFFF);

  /// Info - Informational messages
  static const Color info = Color(0xFF3B82F6); // Blue-500
  static const Color infoContainer = Color(0xFFEFF6FF); // Blue-50
  static const Color onInfo = Color(0xFFFFFFFF);

  // ============================================================================
  // NEUTRAL COLORS - Text, Backgrounds, Borders
  // ============================================================================

  /// Surface colors for cards, sheets, dialogs
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF9FAFB); // Gray-50
  static const Color surfaceDim = Color(0xFFF3F4F6); // Gray-100

  /// Background colors
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundSecondary = Color(0xFFF9FAFB); // Gray-50

  /// Text colors
  static const Color textPrimary = Color(0xFF111827); // Gray-900
  static const Color textSecondary = Color(0xFF6B7280); // Gray-500
  static const Color textTertiary = Color(0xFF9CA3AF); // Gray-400
  static const Color textDisabled = Color(0xFFD1D5DB); // Gray-300
  static const Color textOnDark = Color(0xFFFFFFFF);

  /// Border & Divider colors
  static const Color border = Color(0xFFE5E7EB); // Gray-200
  static const Color borderDark = Color(0xFFD1D5DB); // Gray-300
  static const Color divider = Color(0xFFF3F4F6); // Gray-100

  /// Overlay colors (for modals, dialogs)
  static const Color overlay = Color(0x52000000); // Black with 32% opacity
  static const Color overlayLight = Color(0x1F000000); // Black with 12% opacity
  static const Color overlayMedium =
      Color(0x3D000000); // Black with 24% opacity

  // ============================================================================
  // ECOMMERCE SPECIFIC COLORS
  // ============================================================================

  /// Price & Currency
  static const Color price = Color(0xFF059669); // Green-600
  static const Color priceOriginal =
      Color(0xFF9CA3AF); // Gray-400 (strikethrough)
  static const Color discount = Color(0xFFDC2626); // Red-600

  /// Rating
  static const Color starFilled = Color(0xFFFBBF24); // Amber-400
  static const Color starEmpty = Color(0xFFE5E7EB); // Gray-200

  /// Stock Status
  static const Color inStock = Color(0xFF10B981); // Green-500
  static const Color lowStock = Color(0xFFF59E0B); // Amber-500
  static const Color outOfStock = Color(0xFFEF4444); // Red-500

  /// Order Status Colors
  static const Color statusPending = Color(0xFFF59E0B); // Amber-500
  static const Color statusConfirmed = Color(0xFF3B82F6); // Blue-500
  static const Color statusProcessing = Color(0xFF8B5CF6); // Violet-500
  static const Color statusShipped = Color(0xFF6366F1); // Indigo-500
  static const Color statusDelivered = Color(0xFF10B981); // Green-500
  static const Color statusCancelled = Color(0xFFEF4444); // Red-500
  static const Color statusRefunded = Color(0xFFF97316); // Orange-500

  // ============================================================================
  // DARK MODE COLORS (Optional - for future implementation)
  // ============================================================================

  static const Color darkBackground = Color(0xFF111827); // Gray-900
  static const Color darkSurface = Color(0xFF1F2937); // Gray-800
  static const Color darkSurfaceVariant = Color(0xFF374151); // Gray-700
  static const Color darkTextPrimary = Color(0xFFF9FAFB); // Gray-50
  static const Color darkTextSecondary = Color(0xFF9CA3AF); // Gray-400
  static const Color darkBorder = Color(0xFF374151); // Gray-700

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get color with opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  /// Get status color based on order status string
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return statusPending;
      case 'confirmed':
        return statusConfirmed;
      case 'processing':
        return statusProcessing;
      case 'shipped':
      case 'ready_to_ship':
        return statusShipped;
      case 'delivered':
        return statusDelivered;
      case 'cancelled':
        return statusCancelled;
      case 'refunded':
        return statusRefunded;
      default:
        return textSecondary;
    }
  }

  /// Get status container color (lighter version for backgrounds)
  static Color getStatusContainerColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return warningContainer;
      case 'confirmed':
      case 'processing':
        return infoContainer;
      case 'shipped':
      case 'ready_to_ship':
        return secondaryContainer;
      case 'delivered':
        return successContainer;
      case 'cancelled':
      case 'refunded':
        return errorContainer;
      default:
        return surfaceVariant;
    }
  }
}
