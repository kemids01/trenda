// lib/features/core/widgets/swipe_down_to_dismiss.dart
// Pull a full-screen page down to close it — the page follows the finger, the page underneath
// shows through, and letting go far enough (or flicking down) pops the route like Back.
//
// It only starts when the page's own list is scrolled to the very TOP and the drag is mostly
// vertical, so ordinary scrolling and sideways swipes (photo galleries) are untouched. While the
// page is pulled, [physics] holds the list still, so moving the finger back up shrinks the pull
// instead of also scrolling the list.
//
// The route must be see-through for the page underneath to show: build it with
// [swipeDismissiblePage]. With nothing to pop to (opened from a link), the page springs back.
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SwipeDownToDismiss extends StatefulWidget {
  /// The page's vertical list — used to know when it sits at the top.
  final ScrollController controller;

  /// Builds the page; pass [physics] to the page's vertical scroll view.
  final Widget Function(BuildContext context, ScrollPhysics physics) builder;

  /// How far (logical px) a release must have pulled the page to close it.
  final double closeDistance;

  /// A downward flick at least this fast (px/s) closes it from any distance.
  final double closeVelocity;

  const SwipeDownToDismiss({
    super.key,
    required this.controller,
    required this.builder,
    this.closeDistance = 140,
    this.closeVelocity = 900,
  });

  @override
  State<SwipeDownToDismiss> createState() => _SwipeDownToDismissState();
}

class _SwipeDownToDismissState extends State<SwipeDownToDismiss>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _pull = ValueNotifier(0);
  late final AnimationController _settle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220))
        ..addListener(() => _pull.value = _settleFrom * (1 - Curves.easeOutCubic.transform(_settle.value)));
  late final ScrollPhysics _physics = _PullAwarePhysics(isPulled: () => _pull.value > 0);

  double _settleFrom = 0;
  int? _pointer;
  Offset _travel = Offset.zero;
  bool? _vertical; // decided once the finger has moved past the touch slop
  VelocityTracker? _tracker;
  bool _closing = false;

  bool get _listAtTop {
    final c = widget.controller;
    if (!c.hasClients) return true;
    final p = c.position;
    return p.pixels <= p.minScrollExtent + 0.5;
  }

  void _onDown(PointerDownEvent e) {
    if (_pointer != null || _closing) return;
    _pointer = e.pointer;
    _travel = Offset.zero;
    _vertical = null;
    _tracker = VelocityTracker.withKind(e.kind)..addPosition(e.timeStamp, e.position);
    if (_settle.isAnimating) _settle.stop();
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer || _closing) return;
    _tracker?.addPosition(e.timeStamp, e.position);
    _travel += e.delta;
    if (_vertical == null) {
      if (_travel.distance < kTouchSlop) return;
      _vertical = _travel.dy.abs() > _travel.dx.abs();
    }
    if (_vertical != true) return;
    final dy = e.delta.dy;
    if (_pull.value > 0 || (dy > 0 && _listAtTop)) {
      _pull.value = math.max(0, _pull.value + dy);
    }
  }

  void _onUp(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final velocity = _tracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    _tracker = null;
    if (_pull.value <= 0) return;
    if (_pull.value >= widget.closeDistance || velocity >= widget.closeVelocity) {
      _close();
    } else {
      _springBack();
    }
  }

  Future<void> _close() async {
    _closing = true;
    final popped = await Navigator.of(context).maybePop();
    if (!mounted) return;
    _closing = false;
    if (!popped) _springBack(); // nothing underneath (opened from a link)
  }

  void _springBack() {
    _settleFrom = _pull.value;
    _settle.forward(from: 0);
  }

  @override
  void dispose() {
    _settle.dispose();
    _pull.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.builder(context, _physics);
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      child: NotificationListener<OverscrollIndicatorNotification>(
        // No glow / stretch at the top edge — the pull itself is the feedback.
        onNotification: (n) {
          if (n.leading && n.depth == 0) n.disallowIndicator();
          return false;
        },
        child: ValueListenableBuilder<double>(
          valueListenable: _pull,
          child: page,
          builder: (context, pull, child) {
            if (pull <= 0) return child!;
            final t = (pull / 420).clamp(0.0, 1.0);
            return Transform.translate(
              offset: Offset(0, pull),
              child: Transform.scale(
                scale: 1 - 0.06 * t,
                alignment: Alignment.topCenter,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20 * t + 4)),
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Clamping physics that hold the list still (no scroll, no fling) while the page is pulled.
class _PullAwarePhysics extends ClampingScrollPhysics {
  final bool Function() isPulled;
  const _PullAwarePhysics({required this.isPulled, super.parent});

  @override
  _PullAwarePhysics applyTo(ScrollPhysics? ancestor) =>
      _PullAwarePhysics(isPulled: isPulled, parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      isPulled() ? 0 : super.applyPhysicsToUserOffset(position, offset);

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) =>
      isPulled() ? null : super.createBallisticSimulation(position, velocity);
}

/// A go_router page for a [SwipeDownToDismiss] screen: the platform's usual page transition,
/// but NOT opaque, so the page underneath is painted while the user pulls this one down.
Page<void> swipeDismissiblePage({required LocalKey key, required Widget child}) {
  return CustomTransitionPage<void>(
    key: key,
    opaque: false,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final route = ModalRoute.of(context);
      if (route is! PageRoute) return child;
      return Theme.of(context)
          .pageTransitionsTheme
          .buildTransitions(route, context, animation, secondaryAnimation, child);
    },
  );
}
