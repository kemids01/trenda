// lib/design_system/design_system.dart

/// Trenda Design System
///
/// Export all design system components for easy importing.
///
/// Usage:
/// ```dart
/// import 'package:trenda_frontend/design_system/design_system.dart';
///
/// // Use design system components
/// Container(
///   padding: AppSpacing.paddingMD,
///   decoration: BoxDecoration(
///     color: AppColors.surface,
///     borderRadius: AppSpacing.borderRadiusMD,
///   ),
///   child: Text(
///     'Hello World',
///     style: AppTypography.titleMedium,
///   ),
/// );
/// ```
library;

export 'app_colors.dart';
export 'app_typography.dart';
export 'app_spacing.dart';
export 'app_theme.dart';
export 'app_animations.dart';
