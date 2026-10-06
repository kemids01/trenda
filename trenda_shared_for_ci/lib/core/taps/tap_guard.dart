// lib/core/taps/tap_guard.dart
import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'tap_guard_loader.dart';
import 'tap_guard_policy.dart';

/// Entry point of the tap guard (spec: docs/superpowers/specs/
/// 2026-10-04-tap-guard-design.md).
///
/// [policy] is the ONE rule set the binding consults for every new pointer.
/// [run] is the busy-lock for taps that await a network write: a second call
/// with the same key while the first is in flight does nothing, and a small
/// centred loader shows if the action takes longer than [loaderDelay].
class TapGuard {
  TapGuard._();

  static TapGuardPolicy policy = TapGuardPolicy();

  /// A save faster than this never shows the loader (no flash).
  static const Duration loaderDelay = Duration(milliseconds: 150);

  static final Set<String> _running = <String>{};

  static bool isRunning(String key) => _running.contains(key);

  /// Routes open above the base the app started on (pushes minus pops, as
  /// reported by `TapGuardObserver`). Only RELATIVE changes matter: a loader
  /// shows only while the depth equals what it was when its run started.
  static int _routeDepth = 0;

  /// A route (page, dialog, sheet) was pushed.
  static void onRoutePushed() {
    _routeDepth++;
    onNavigation();
  }

  /// A route was popped or removed.
  static void onRoutePopped() {
    if (_routeDepth > 0) _routeDepth--;
    onNavigation();
  }

  /// Any route change: freezes new input and re-evaluates every loader. A
  /// loader must never sit on top of a dialog or page the action itself opened
  /// (it would absorb that route's buttons), so it hides while the depth is
  /// above its run's start and comes back — after the usual delay — once the
  /// route closes (the confirm-then-save case).
  static void onNavigation() {
    policy.freeze();
    _CentreLoader.routeChangedAll();
  }

  /// Runs [action] unless [key] is already running (then returns null and does
  /// nothing). Returns the action's result; rethrows its error. The key is
  /// freed and the loader removed in every case.
  ///
  /// Keys: `'<area>.<action>'`, plus `':$id'` for per-entity actions
  /// (`'rider.complete:$orderId'`). Pass `showLoader: false` when the screen
  /// already shows its own progress for this action.
  ///
  /// [context] is OPTIONAL and only locates the overlay: without one (or when
  /// it is no longer mounted — e.g. after an `await` in the handler) the app's
  /// root overlay is found from the widget tree. That is what lets a write be
  /// wrapped in place, anywhere, without the use_build_context_synchronously
  /// trap.
  static Future<T?> run<T>(
    String key,
    Future<T> Function() action, {
    bool showLoader = true,
    BuildContext? context,
  }) async {
    if (!_running.add(key)) return null;
    final loader = showLoader ? _CentreLoader.schedule(context) : null;
    try {
      return await action();
    } finally {
      loader?.dismiss();
      _running.remove(key);
    }
  }

  @visibleForTesting
  static void resetForTest({TapGuardPolicy? policy}) {
    TapGuard.policy = policy ?? TapGuardPolicy();
    _running.clear();
    _routeDepth = 0;
    _CentreLoader.dismissAll();
  }
}

class _CentreLoader {
  _CentreLoader._(this._fromContext, this._startDepth);

  static final Set<_CentreLoader> _active = <_CentreLoader>{};
  static OverlayState? _rootOverlayCache;

  /// The overlay the caller's context resolved to, if it was mounted.
  final OverlayState? _fromContext;

  /// The route depth when the run started; the loader only shows at it.
  final int _startDepth;
  Timer? _timer;
  OverlayEntry? _entry;
  bool _done = false;

  static _CentreLoader schedule(BuildContext? context) {
    final fromContext = context != null && context.mounted
        ? Overlay.maybeOf(context, rootOverlay: true)
        : null;
    final loader = _CentreLoader._(fromContext, TapGuard._routeDepth);
    _active.add(loader);
    loader._timer = Timer(TapGuard.loaderDelay, loader._show);
    return loader;
  }

  static void dismissAll() {
    for (final loader in _active.toList()) {
      loader.dismiss();
    }
  }

  static void routeChangedAll() {
    for (final loader in _active.toList()) {
      loader._routeChanged();
    }
  }

  /// Hide now; re-arm the delay only if we are back at the run's own route.
  void _routeChanged() {
    if (_done) return;
    _timer?.cancel();
    _timer = null;
    _removeEntry();
    if (TapGuard._routeDepth == _startDepth) {
      _timer = Timer(TapGuard.loaderDelay, _show);
    }
  }

  /// The outermost Overlay in the app (the root Navigator's), found by a
  /// depth-first walk from the root element and cached while it stays mounted.
  static OverlayState? _rootOverlay() {
    final cached = _rootOverlayCache;
    if (cached != null && cached.mounted) return cached;
    OverlayState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is OverlayState) {
        found = element.state as OverlayState;
        return;
      }
      element.visitChildren(visit);
    }

    final root = WidgetsBinding.instance.rootElement;
    if (root != null) visit(root);
    return _rootOverlayCache = found;
  }

  void _show() {
    if (_done || _entry != null) return;
    if (TapGuard._routeDepth != _startDepth) return;
    final ctxOverlay = _fromContext;
    final overlay = ctxOverlay != null && ctxOverlay.mounted
        ? ctxOverlay
        : _rootOverlay();
    if (overlay == null) return; // lock still applies, no loader
    final entry = OverlayEntry(builder: (_) => const TapGuardLoader());
    _entry = entry;
    overlay.insert(entry);
  }

  void dismiss() {
    if (_done) return;
    _done = true;
    _active.remove(this);
    _timer?.cancel();
    _removeEntry();
  }

  void _removeEntry() {
    final entry = _entry;
    _entry = null;
    if (entry == null) return;
    // A route change is reported from inside the Navigator's build; removing
    // an overlay entry there would setState mid-build, so defer to after it.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => entry.remove());
    } else {
      entry.remove();
    }
  }
}
