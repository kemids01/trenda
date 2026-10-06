// lib/core/taps/tap_guard_observer.dart
import 'package:flutter/widgets.dart';

import 'tap_guard.dart';

/// Freezes new input for the policy's window on EVERY route change. Dialogs
/// and bottom sheets are routes, so this one observer covers pages, dialogs
/// and sheets. A NavigatorObserver belongs to ONE navigator — give each
/// navigator its own instance.
class TapGuardObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      TapGuard.onRoutePushed();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      TapGuard.onRoutePopped();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      TapGuard.onNavigation();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      TapGuard.onRoutePopped();
}
