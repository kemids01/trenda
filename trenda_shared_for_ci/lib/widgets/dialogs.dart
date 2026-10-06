// trenda_shared/lib/widgets/dialogs.dart
// ============================================================================
// DIALOGS - Reusable dialog widgets and helpers
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';

// ============================================================================
// CONFIRMATION DIALOG
// Standard confirmation dialog with customizable actions
// ============================================================================

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? content;
  final String confirmText;
  final String cancelText;
  final Color? confirmColor;
  final bool isDestructive;
  final IconData? icon;

  const ConfirmationDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.confirmColor,
    this.isDestructive = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionColor =
        confirmColor ??
        (isDestructive ? theme.colorScheme.error : theme.colorScheme.primary);

    return AlertDialog(
      icon: icon != null
          ? Icon(
              icon,
              size: 48,
              color: isDestructive ? theme.colorScheme.error : null,
            )
          : null,
      title: Text(title, textAlign: TextAlign.center),
      content:
          content ??
          (message != null
              ? Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : null),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: actionColor),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmText),
        ),
      ],
    );
  }
}

// ============================================================================
// LOADING DIALOG
// Shows a loading indicator with message
// ============================================================================

class LoadingDialog extends StatelessWidget {
  final String message;

  const LoadingDialog({super.key, this.message = 'Please wait...'});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 24),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// INPUT DIALOG
// Dialog with text input
// ============================================================================

class InputDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String? initialValue;
  final String? hint;
  final String confirmText;
  final String cancelText;
  final String? Function(String?)? validator;
  final int? maxLines;
  final TextInputType? keyboardType;

  const InputDialog({
    super.key,
    required this.title,
    this.message,
    this.initialValue,
    this.hint,
    this.confirmText = 'OK',
    this.cancelText = 'Cancel',
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  late TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.validator != null) {
      final error = widget.validator!(_controller.text);
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    }
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                widget.message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: widget.maxLines,
            keyboardType: widget.keyboardType,
            decoration: InputDecoration(
              hintText: widget.hint,
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(widget.cancelText),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmText)),
      ],
    );
  }
}

// ============================================================================
// SELECTION DIALOG
// Dialog for selecting from a list
// ============================================================================

class SelectionDialog<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final T? selectedItem;
  final String Function(T) labelBuilder;
  final Widget Function(T, bool isSelected)? itemBuilder;

  const SelectionDialog({
    super.key,
    required this.title,
    required this.items,
    this.selectedItem,
    required this.labelBuilder,
    this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isSelected = item == selectedItem;

            if (itemBuilder != null) {
              return InkWell(
                onTap: () => Navigator.of(context).pop(item),
                child: itemBuilder!(item, isSelected),
              );
            }

            return ListTile(
              title: Text(labelBuilder(item)),
              trailing: isSelected
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
              selected: isSelected,
              onTap: () => Navigator.of(context).pop(item),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// ============================================================================
// BOTTOM SHEET SELECTOR
// Action sheet style selector
// ============================================================================

class BottomSheetSelector<T> extends StatelessWidget {
  final String? title;
  final List<T> items;
  final String Function(T) labelBuilder;
  final IconData Function(T)? iconBuilder;
  final bool Function(T)? isDestructive;

  const BottomSheetSelector({
    super.key,
    this.title,
    required this.items,
    required this.labelBuilder,
    this.iconBuilder,
    this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title!, style: theme.textTheme.titleMedium),
            ),
          ...items.map((item) {
            final destructive = isDestructive?.call(item) ?? false;

            return ListTile(
              leading: iconBuilder != null
                  ? Icon(
                      iconBuilder!(item),
                      color: destructive ? theme.colorScheme.error : null,
                    )
                  : null,
              title: Text(
                labelBuilder(item),
                style: destructive
                    ? TextStyle(color: theme.colorScheme.error)
                    : null,
              ),
              onTap: () => Navigator.of(context).pop(item),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ============================================================================
// DIALOG HELPERS
// Static methods for showing dialogs
// ============================================================================

class TrendaDialogs {
  /// Show confirmation dialog
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  /// Show delete confirmation
  static Future<bool> confirmDelete(
    BuildContext context, {
    String title = 'Delete',
    String? itemName,
  }) async {
    return confirm(
      context,
      title: title,
      message: itemName != null
          ? 'Are you sure you want to delete "$itemName"? This action cannot be undone.'
          : 'Are you sure you want to delete this? This action cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
      icon: Icons.delete_outline,
    );
  }

  /// Show loading dialog
  static void showLoading(
    BuildContext context, {
    String message = 'Please wait...',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LoadingDialog(message: message),
    );
  }

  /// Hide loading dialog
  static void hideLoading(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// Execute with loading dialog
  static Future<T?> withLoading<T>(
    BuildContext context, {
    required Future<T> Function() action,
    String message = 'Please wait...',
    void Function(Object error)? onError,
  }) async {
    showLoading(context, message: message);
    try {
      final result = await action();
      if (context.mounted) hideLoading(context);
      return result;
    } catch (e) {
      if (context.mounted) hideLoading(context);
      onError?.call(e);
      return null;
    }
  }

  /// Show input dialog
  static Future<String?> input(
    BuildContext context, {
    required String title,
    String? message,
    String? initialValue,
    String? hint,
    String confirmText = 'OK',
    String? Function(String?)? validator,
    int? maxLines,
    TextInputType? keyboardType,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => InputDialog(
        title: title,
        message: message,
        initialValue: initialValue,
        hint: hint,
        confirmText: confirmText,
        validator: validator,
        maxLines: maxLines,
        keyboardType: keyboardType,
      ),
    );
  }

  /// Show selection dialog
  static Future<T?> select<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    T? selectedItem,
    required String Function(T) labelBuilder,
    Widget Function(T, bool)? itemBuilder,
  }) async {
    return showDialog<T>(
      context: context,
      builder: (context) => SelectionDialog<T>(
        title: title,
        items: items,
        selectedItem: selectedItem,
        labelBuilder: labelBuilder,
        itemBuilder: itemBuilder,
      ),
    );
  }

  /// Show bottom sheet selector
  static Future<T?> showBottomSheet<T>(
    BuildContext context, {
    String? title,
    required List<T> items,
    required String Function(T) labelBuilder,
    IconData Function(T)? iconBuilder,
    bool Function(T)? isDestructive,
  }) async {
    return showModalBottomSheet<T>(
      context: context,
      builder: (context) => BottomSheetSelector<T>(
        title: title,
        items: items,
        labelBuilder: labelBuilder,
        iconBuilder: iconBuilder,
        isDestructive: isDestructive,
      ),
    );
  }

  /// Show snackbar
  static void showSnackBar(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    bool isError = false,
  }) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: action,
        backgroundColor: isError ? theme.colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show success snackbar
  static void showSuccess(BuildContext context, String message) {
    showSnackBar(context, message: message);
  }

  /// Show error snackbar
  static void showError(BuildContext context, String message) {
    showSnackBar(context, message: message, isError: true);
  }
}
