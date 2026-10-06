// lib/core/taps/tap_guard_binding.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'allow_rapid_taps.dart';
import 'tap_guard.dart';

/// Drops the new pointers [TapGuard.policy] rejects, before any recognizer or
/// widget sees them. Only a NEW pointer is ever dropped, and then EVERY later
/// event of that pointer (move/up/cancel) is skipped too, so no recognizer is
/// ever handed half a gesture. Hover, scroll-wheel, added/removed and pan-zoom
/// events always pass.
mixin TapGuardBinding on GestureBinding {
  final Set<int> _droppedPointers = <int>{};

  @override
  void dispatchEvent(PointerEvent event, HitTestResult? hitTestResult) {
    final policy = TapGuard.policy;
    if (event is PointerDownEvent) {
      final exempt =
          hitTestResult?.path.any((entry) => isTapGuardExempt(entry.target)) ??
          false;
      if (policy.onPointerDown(event.pointer, event.position, exempt: exempt)) {
        _droppedPointers.add(event.pointer);
        return;
      }
    } else if (_droppedPointers.contains(event.pointer) &&
        (event.down ||
            event is PointerUpEvent ||
            event is PointerCancelEvent)) {
      if (event is PointerUpEvent || event is PointerCancelEvent) {
        _droppedPointers.remove(event.pointer);
      }
      return;
    } else if (event is PointerMoveEvent) {
      policy.onPointerMove(event.pointer, event.position);
    } else if (event is PointerUpEvent) {
      policy.onPointerUp(event.pointer, event.position);
    } else if (event is PointerCancelEvent) {
      policy.onPointerCancel(event.pointer);
    }
    super.dispatchEvent(event, hitTestResult);
  }
}

/// The app binding: Flutter's own plus the tap guard. Call
/// `TrendaBinding.ensureInitialized()` FIRST in `main()`, in place of
/// `WidgetsFlutterBinding.ensureInitialized()` — everything after (Firebase,
/// plugins) reuses the singleton.
class TrendaBinding extends WidgetsFlutterBinding with TapGuardBinding {
  static TrendaBinding? _instance;

  static WidgetsBinding ensureInitialized() {
    _instance ??= TrendaBinding();
    return WidgetsBinding.instance;
  }
}
