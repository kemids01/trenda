// lib/core/taps/allow_rapid_taps.dart
import 'package:flutter/gestures.dart' show HitTestTarget;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Marks a subtree whose taps are MEANT to be repeated quickly — quantity
/// steppers, map double-tap zoom. The tap guard's same-spot rule skips any
/// pointer that lands inside it (the post-navigation freeze still applies).
class AllowRapidTaps extends SingleChildRenderObjectWidget {
  const AllowRapidTaps({super.key, required Widget super.child});

  @override
  RenderAllowRapidTaps createRenderObject(BuildContext context) =>
      RenderAllowRapidTaps();
}

/// Pass-through render box; exists only so the guard can find it on the
/// hit-test path.
class RenderAllowRapidTaps extends RenderProxyBox {}

/// Whether a hit-test target exempts its pointer from the same-spot rule:
/// text (double-tap selects a word), platform views (Google Maps' own
/// double-tap zoom) and anything wrapped in [AllowRapidTaps].
bool isTapGuardExempt(HitTestTarget target) =>
    target is RenderEditable ||
    target is PlatformViewRenderBox ||
    target is RenderDarwinPlatformView ||
    target is RenderAllowRapidTaps;
