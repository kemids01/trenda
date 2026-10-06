// lib/features/cart/widgets/quantity_input.dart
// A compact − [ typed number ] + control, shared by the product page and the
// basket. Steppers alone made 24 pandesal twenty-three taps.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trenda_shared/core/taps/taps.dart';

/// Reads what the shopper typed as a quantity, clamped to [min]..[max].
/// Blank or non-numeric text is null (the field keeps its last good value).
/// A null [max] means no known ceiling.
int? parseQuantity(String text, {int min = 1, int? max}) {
  final n = int.tryParse(text.trim());
  if (n == null) return null;
  var q = n < min ? min : n;
  if (max != null && max >= min && q > max) q = max;
  return q;
}

class QuantityInput extends StatefulWidget {
  /// The committed quantity.
  final int value;

  /// Highest allowed quantity (usually stock). Null = no known ceiling.
  final int? max;

  /// Called when a quantity is committed: a step button, the keyboard's
  /// Done, or the field losing focus. Never called with the same [value].
  final ValueChanged<int> onChanged;

  /// Called on every keystroke that parses, so a total can follow the digits
  /// before they are committed.
  final ValueChanged<int>? onDraft;

  /// Told when a typed or stepped quantity was cut down to [max].
  final ValueChanged<int>? onLimit;

  final Color? accent;
  final bool enabled;

  const QuantityInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.max,
    this.onDraft,
    this.onLimit,
    this.accent,
    this.enabled = true,
  });

  @override
  State<QuantityInput> createState() => _QuantityInputState();
}

class _QuantityInputState extends State<QuantityInput> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.value}');
  final FocusNode _focus = FocusNode();

  /// The last quantity handed to onChanged that the parent has not echoed
  /// back yet — a step button also blurs the field, and that blur must not
  /// send the same change twice.
  int? _pending;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        _pending = null;
      } else {
        _commit(_controller.text);
      }
    });
  }

  void _emit(int q) {
    if (q == widget.value || q == _pending) return;
    _pending = q;
    widget.onChanged(q);
  }

  @override
  void didUpdateWidget(QuantityInput old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _pending = null;
    // Follow the outside value (a server reply, a variant switch) unless the
    // shopper is mid-typing.
    if (!_focus.hasFocus && _controller.text != '${widget.value}') {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit(String text) {
    final raw = int.tryParse(text.trim());
    final q = parseQuantity(text, max: widget.max) ?? widget.value;
    if (raw != null && widget.max != null && raw > widget.max!) {
      widget.onLimit?.call(widget.max!);
    }
    if (_controller.text != '$q') _controller.text = '$q';
    // A blank or reverted field must pull a previewed total back too.
    widget.onDraft?.call(q);
    _emit(q);
  }

  void _step(int delta) {
    // Step from what is in the field, typed or not.
    final base =
        parseQuantity(_controller.text, max: widget.max) ?? widget.value;
    final next = base + delta;
    if (next < 1) return;
    if (widget.max != null && next > widget.max!) {
      widget.onLimit?.call(widget.max!);
      return;
    }
    _controller.text = '$next';
    widget.onDraft?.call(next);
    _emit(next);
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.accent ?? scheme.primary;
    final canDec = widget.enabled && widget.value > 1;
    final canInc =
        widget.enabled && (widget.max == null || widget.value < widget.max!);

    Widget button(IconData icon, bool on, VoidCallback tap, String tip) =>
        Tooltip(
          message: tip,
          child: InkWell(
            // Still tappable when "off" at the ceiling, so onLimit can explain.
            onTap: widget.enabled ? tap : null,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 30,
              height: 30,
              child: Icon(
                icon,
                size: 16,
                color: on ? accent : scheme.onSurface.withValues(alpha: 0.25),
              ),
            ),
          ),
        );

    return AllowRapidTaps(
        child: Container(
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, canDec, () => _step(-1), 'Fewer'),
          SizedBox(
            width: 40,
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: widget.enabled,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
              onChanged: (t) {
                final q = parseQuantity(t, max: widget.max);
                if (q != null) widget.onDraft?.call(q);
              },
              onSubmitted: _commit,
              onTapOutside: (_) => _focus.unfocus(),
            ),
          ),
          button(Icons.add_rounded, canInc, () => _step(1), 'More'),
        ],
      ),
    ));
  }
}
