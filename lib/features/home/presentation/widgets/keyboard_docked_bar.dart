// lib/features/home/presentation/widgets/keyboard_docked_bar.dart
import 'package:flutter/widgets.dart';

/// Lifts a Scaffold's `bottomNavigationBar` above the on-screen keyboard.
///
/// ⚠️ Scaffold only resizes its BODY for the keyboard — the bottom navigation
/// bar stays pinned to the screen edge, i.e. behind the keyboard. The shop
/// dock's search field lives there, so typing into it hid the field being
/// typed in. Padding by the keyboard height puts the dock on top of it; the
/// Scaffold then ends the body above the lifted bar, so nothing overlaps.
class KeyboardDockedBar extends StatelessWidget {
  final Widget child;

  const KeyboardDockedBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child,
    );
  }
}
