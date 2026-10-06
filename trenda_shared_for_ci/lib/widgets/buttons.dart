// trenda_shared/lib/widgets/buttons.dart
// ============================================================================
// BUTTON WIDGETS - Enhanced button variants
// ============================================================================

import 'package:flutter/material.dart';

// ============================================================================
// LOADING BUTTON
// Button with loading state indicator
// ============================================================================

class LoadingButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final ButtonStyle? style;
  final ButtonType type;
  final IconData? icon;

  const LoadingButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.style,
    this.type = ButtonType.filled,
    this.icon,
  });

  /// Filled button with loading
  const LoadingButton.filled({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.style,
    this.icon,
  }) : type = ButtonType.filled;

  /// Outlined button with loading
  const LoadingButton.outlined({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.style,
    this.icon,
  }) : type = ButtonType.outlined;

  /// Text button with loading
  const LoadingButton.text({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.style,
    this.icon,
  }) : type = ButtonType.text;

  @override
  Widget build(BuildContext context) {
    final content = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                type == ButtonType.filled
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              child,
            ],
          );

    switch (type) {
      case ButtonType.filled:
        return FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: style,
          child: content,
        );
      case ButtonType.outlined:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: style,
          child: content,
        );
      case ButtonType.text:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: style,
          child: content,
        );
    }
  }
}

enum ButtonType { filled, outlined, text }

// ============================================================================
// ICON ACTION BUTTON
// Circular icon button with optional badge
// ============================================================================

class IconActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final int? badgeCount;
  final bool showBadge;

  const IconActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.backgroundColor,
    this.size = 40,
    this.badgeCount,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.colorScheme.onSurface;
    final bgColor =
        backgroundColor ?? theme.colorScheme.surfaceContainerHighest;

    Widget button = Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(size / 2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: iconColor, size: size * 0.5),
        ),
      ),
    );

    if (showBadge || (badgeCount != null && badgeCount! > 0)) {
      button = Badge(
        label: badgeCount != null ? Text('$badgeCount') : null,
        isLabelVisible: badgeCount != null && badgeCount! > 0,
        child: button,
      );
    }

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}

// ============================================================================
// FLOATING ACTION BUTTON EXTENDED
// Extended FAB with loading state
// ============================================================================

class TrendaFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? label;
  final bool isLoading;
  final bool extended;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const TrendaFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.isLoading = false,
    this.extended = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (extended && label != null) {
      return FloatingActionButton.extended(
        onPressed: isLoading ? null : onPressed,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                    foregroundColor ?? theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              )
            : Icon(icon),
        label: Text(label!),
      );
    }

    return FloatingActionButton(
      onPressed: isLoading ? null : onPressed,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  foregroundColor ?? theme.colorScheme.onPrimaryContainer,
                ),
              ),
            )
          : Icon(icon),
    );
  }
}

// ============================================================================
// SEGMENTED BUTTON GROUP
// Toggle between options
// ============================================================================

class SegmentedButtonGroup<T> extends StatelessWidget {
  final List<T> items;
  final T selected;
  final void Function(T) onSelected;
  final String Function(T) labelBuilder;
  final IconData Function(T)? iconBuilder;

  const SegmentedButtonGroup({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    required this.labelBuilder,
    this.iconBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: items
          .map(
            (item) => ButtonSegment<T>(
              value: item,
              label: Text(labelBuilder(item)),
              icon: iconBuilder != null ? Icon(iconBuilder!(item)) : null,
            ),
          )
          .toList(),
      selected: {selected},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          onSelected(selection.first);
        }
      },
    );
  }
}

// ============================================================================
// SOCIAL BUTTON
// Pre-styled buttons for social login
// ============================================================================

class SocialButton extends StatelessWidget {
  final String label;
  final String iconAsset;
  final VoidCallback? onPressed;
  final bool isLoading;
  final SocialProvider provider;

  const SocialButton({
    super.key,
    required this.label,
    this.iconAsset = '',
    this.onPressed,
    this.isLoading = false,
    this.provider = SocialProvider.custom,
  });

  const SocialButton.google({
    super.key,
    this.label = 'Continue with Google',
    this.onPressed,
    this.isLoading = false,
  }) : provider = SocialProvider.google,
       iconAsset = '';

  const SocialButton.facebook({
    super.key,
    this.label = 'Continue with Facebook',
    this.onPressed,
    this.isLoading = false,
  }) : provider = SocialProvider.facebook,
       iconAsset = '';

  const SocialButton.apple({
    super.key,
    this.label = 'Continue with Apple',
    this.onPressed,
    this.isLoading = false,
  }) : provider = SocialProvider.apple,
       iconAsset = '';

  IconData _getIcon() {
    switch (provider) {
      case SocialProvider.google:
        return Icons.g_mobiledata;
      case SocialProvider.facebook:
        return Icons.facebook;
      case SocialProvider.apple:
        return Icons.apple;
      case SocialProvider.custom:
        return Icons.login;
    }
  }

  Color _getColor(BuildContext context) {
    switch (provider) {
      case SocialProvider.google:
        return Colors.white;
      case SocialProvider.facebook:
        return const Color(0xFF1877F2);
      case SocialProvider.apple:
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black;
      case SocialProvider.custom:
        return Theme.of(context).colorScheme.surface;
    }
  }

  Color _getTextColor(BuildContext context) {
    switch (provider) {
      case SocialProvider.google:
        return Colors.black87;
      case SocialProvider.facebook:
        return Colors.white;
      case SocialProvider.apple:
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.white;
      case SocialProvider.custom:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getColor(context);
    final textColor = _getTextColor(context);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(textColor),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getIcon(), size: 24),
                  const SizedBox(width: 12),
                  Text(label),
                ],
              ),
      ),
    );
  }
}

enum SocialProvider { google, facebook, apple, custom }
