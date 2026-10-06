// lib/core/taps/tap_guard_policy.dart
import 'dart:ui' show Offset;

import 'package:flutter/gestures.dart' show kTouchSlop;

/// The ONE place the tap-guard rules and numbers live. Pure: no Flutter
/// bindings, no timers — the clock is injected so tests drive time.
///
/// Rule 1 — after any route change ([freeze]) every NEW pointer is dropped for
/// [freezeFor]: a page, dialog or sheet cannot be opened twice by a fast second
/// tap, and a tap cannot land on whatever sits under a dialog that just closed.
///
/// Rule 2 — a new pointer within [repeatWindow] and [repeatRadius] of the
/// previous TAP is dropped. Only a completed tap (moved ≤ [tapSlop]) arms it, so
/// fast repeated flicks through a list are never filtered. Exempt pointers
/// (text fields, maps, steppers — see `isTapGuardExempt`) skip this rule and
/// never arm it; they do NOT skip Rule 1.
class TapGuardPolicy {
  TapGuardPolicy({
    Duration Function()? now,
    this.freezeFor = const Duration(milliseconds: 400),
    this.repeatWindow = const Duration(milliseconds: 300),
    this.repeatRadius = 24,
    this.tapSlop = kTouchSlop,
  }) : _now = now ?? _monotonic;

  static final Stopwatch _stopwatch = Stopwatch()..start();
  static Duration _monotonic() => _stopwatch.elapsed;

  final Duration freezeFor;
  final Duration repeatWindow;
  final double repeatRadius;
  final double tapSlop;
  final Duration Function() _now;

  Duration? _frozenUntil;
  Duration? _lastTapUpAt;
  Offset? _lastTapAt;
  final Map<int, _Track> _tracks = <int, _Track>{};

  /// Start (or extend) the post-navigation freeze. Never shortens one.
  void freeze() {
    final until = _now() + freezeFor;
    final current = _frozenUntil;
    if (current == null || until > current) _frozenUntil = until;
  }

  /// True when this NEW pointer must be ignored.
  bool onPointerDown(int pointer, Offset position, {bool exempt = false}) {
    final now = _now();
    final frozenUntil = _frozenUntil;
    if (frozenUntil != null && now < frozenUntil) return true;
    final lastUp = _lastTapUpAt;
    final lastAt = _lastTapAt;
    if (!exempt &&
        lastUp != null &&
        lastAt != null &&
        now - lastUp < repeatWindow &&
        (position - lastAt).distance <= repeatRadius) {
      return true;
    }
    _tracks[pointer] = _Track(position, exempt: exempt);
    return false;
  }

  void onPointerMove(int pointer, Offset position) {
    final track = _tracks[pointer];
    if (track == null) return;
    final distance = (position - track.start).distance;
    if (distance > track.maxDistance) track.maxDistance = distance;
  }

  void onPointerUp(int pointer, Offset position) {
    onPointerMove(pointer, position);
    final track = _tracks.remove(pointer);
    if (track == null) return;
    if (track.maxDistance <= tapSlop && !track.exempt) {
      _lastTapUpAt = _now();
      _lastTapAt = track.start;
    } else if (track.maxDistance > tapSlop) {
      // A swipe/scroll disarms the repeat filter.
      _lastTapUpAt = null;
      _lastTapAt = null;
    }
  }

  void onPointerCancel(int pointer) => _tracks.remove(pointer);
}

class _Track {
  _Track(this.start, {required this.exempt});
  final Offset start;
  final bool exempt;
  double maxDistance = 0;
}
