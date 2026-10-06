// trenda_shared/lib/widgets/chips.dart
// ============================================================================
// CHIP WIDGETS - Selection chips, filter chips, and chip groups
// ============================================================================

import 'package:flutter/material.dart';

// ============================================================================
// CHIP GROUP
// Horizontal scrollable chip selection
// ============================================================================

class ChipGroup<T> extends StatelessWidget {
  final List<T> items;
  final T? selectedItem;
  final void Function(T) onSelected;
  final String Function(T) labelBuilder;
  final IconData Function(T)? iconBuilder;
  final bool scrollable;
  final bool showCheckmark;

  const ChipGroup({
    super.key,
    required this.items,
    this.selectedItem,
    required this.onSelected,
    required this.labelBuilder,
    this.iconBuilder,
    this.scrollable = true,
    this.showCheckmark = true,
  });

  @override
  Widget build(BuildContext context) {
    final chips = items.map((item) {
      final isSelected = item == selectedItem;
      return ChoiceChip(
        label: Text(labelBuilder(item)),
        avatar: iconBuilder != null && !isSelected
            ? Icon(iconBuilder!(item), size: 18)
            : null,
        selected: isSelected,
        showCheckmark: showCheckmark,
        onSelected: (_) => onSelected(item),
      );
    }).toList();

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips
              .map(
                (chip) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: chip,
                ),
              )
              .toList(),
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

// ============================================================================
// MULTI CHIP GROUP
// Multiple selection chip group
// ============================================================================

class MultiChipGroup<T> extends StatelessWidget {
  final List<T> items;
  final Set<T> selectedItems;
  final void Function(Set<T>) onChanged;
  final String Function(T) labelBuilder;
  final IconData Function(T)? iconBuilder;
  final bool scrollable;
  final int? maxSelection;

  const MultiChipGroup({
    super.key,
    required this.items,
    required this.selectedItems,
    required this.onChanged,
    required this.labelBuilder,
    this.iconBuilder,
    this.scrollable = true,
    this.maxSelection,
  });

  void _toggle(T item) {
    final newSelection = Set<T>.from(selectedItems);
    if (newSelection.contains(item)) {
      newSelection.remove(item);
    } else {
      if (maxSelection == null || newSelection.length < maxSelection!) {
        newSelection.add(item);
      }
    }
    onChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    final chips = items.map((item) {
      final isSelected = selectedItems.contains(item);
      return FilterChip(
        label: Text(labelBuilder(item)),
        avatar: iconBuilder != null && !isSelected
            ? Icon(iconBuilder!(item), size: 18)
            : null,
        selected: isSelected,
        onSelected: (_) => _toggle(item),
      );
    }).toList();

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips
              .map(
                (chip) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: chip,
                ),
              )
              .toList(),
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

// ============================================================================
// FILTER CHIP BAR
// Common filter chip patterns
// ============================================================================

class FilterChipBar extends StatelessWidget {
  final List<FilterOption> options;
  final Set<String> selectedIds;
  final void Function(Set<String>) onChanged;
  final bool scrollable;

  const FilterChipBar({
    super.key,
    required this.options,
    required this.selectedIds,
    required this.onChanged,
    this.scrollable = true,
  });

  void _toggle(String id) {
    final newSelection = Set<String>.from(selectedIds);
    if (newSelection.contains(id)) {
      newSelection.remove(id);
    } else {
      newSelection.add(id);
    }
    onChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    final chips = options.map((option) {
      final isSelected = selectedIds.contains(option.id);
      return FilterChip(
        label: Text(option.label),
        avatar: option.icon != null && !isSelected
            ? Icon(option.icon, size: 18)
            : null,
        selected: isSelected,
        onSelected: option.enabled ? (_) => _toggle(option.id) : null,
      );
    }).toList();

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: chips
              .map(
                (chip) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: chip,
                ),
              )
              .toList(),
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class FilterOption {
  final String id;
  final String label;
  final IconData? icon;
  final bool enabled;

  const FilterOption({
    required this.id,
    required this.label,
    this.icon,
    this.enabled = true,
  });
}

// ============================================================================
// TAG INPUT
// Input field for adding tags/chips
// ============================================================================

class TagInput extends StatefulWidget {
  final List<String> tags;
  final void Function(List<String>) onChanged;
  final String hint;
  final int? maxTags;
  final bool enabled;

  const TagInput({
    super.key,
    required this.tags,
    required this.onChanged,
    this.hint = 'Add tag...',
    this.maxTags,
    this.enabled = true,
  });

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;
    if (widget.tags.contains(trimmed)) return;
    if (widget.maxTags != null && widget.tags.length >= widget.maxTags!) return;

    final newTags = [...widget.tags, trimmed];
    widget.onChanged(newTags);
    _controller.clear();
  }

  void _removeTag(String tag) {
    final newTags = widget.tags.where((t) => t != tag).toList();
    widget.onChanged(newTags);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAddMore =
        widget.maxTags == null || widget.tags.length < widget.maxTags!;

    return InputDecorator(
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...widget.tags.map(
            (tag) => InputChip(
              label: Text(tag),
              onDeleted: widget.enabled ? () => _removeTag(tag) : null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (widget.enabled && canAddMore)
            SizedBox(
              width: 120,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                style: theme.textTheme.bodyMedium,
                onSubmitted: _addTag,
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// STATUS CHIP
// Colored chip for displaying status
// ============================================================================

class StatusChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final StatusType type;

  const StatusChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.type = StatusType.neutral,
  });

  /// Quick constructors for common statuses
  const StatusChip.success({super.key, required this.label, this.icon})
    : type = StatusType.success,
      color = null;

  const StatusChip.warning({super.key, required this.label, this.icon})
    : type = StatusType.warning,
      color = null;

  const StatusChip.error({super.key, required this.label, this.icon})
    : type = StatusType.error,
      color = null;

  const StatusChip.info({super.key, required this.label, this.icon})
    : type = StatusType.info,
      color = null;

  Color _getColor(BuildContext context) {
    if (color != null) return color!;

    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case StatusType.success:
        return Colors.green;
      case StatusType.warning:
        return Colors.orange;
      case StatusType.error:
        return colorScheme.error;
      case StatusType.info:
        return Colors.blue;
      case StatusType.neutral:
        return colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: statusColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum StatusType { success, warning, error, info, neutral }
