// trenda_shared/lib/core/navigation_helpers.dart
// ============================================================================
// NAVIGATION HELPERS - Common navigation patterns and utilities
// ============================================================================

import 'package:flutter/material.dart';

/// Extension for easy navigation
extension TrendaNavigation on BuildContext {
  /// Push a new route (use pushPage to avoid go_router conflict)
  Future<T?> pushPage<T>(Widget page) {
    return Navigator.of(this).push<T>(MaterialPageRoute(builder: (_) => page));
  }

  /// Push with custom transition
  Future<T?> pushWithTransition<T>(
    Widget page, {
    RouteTransition transition = RouteTransition.fade,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.of(this).push<T>(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: duration,
        reverseTransitionDuration: duration,
        transitionsBuilder: (_, animation, __, child) {
          return switch (transition) {
            RouteTransition.fade => FadeTransition(
              opacity: animation,
              child: child,
            ),
            RouteTransition.slideRight => SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
            RouteTransition.slideUp => SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
            RouteTransition.scale => ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: child,
            ),
          };
        },
      ),
    );
  }

  /// Push and replace current route
  Future<T?> pushReplacement<T, TO>(Widget page) {
    return Navigator.of(
      this,
    ).pushReplacement<T, TO>(MaterialPageRoute(builder: (_) => page));
  }

  /// Push and remove all routes
  Future<T?> pushAndRemoveAll<T>(Widget page) {
    return Navigator.of(this).pushAndRemoveUntil<T>(
      MaterialPageRoute(builder: (_) => page),
      (_) => false,
    );
  }

  /// Pop the current route (use popPage to avoid go_router conflict)
  void popPage<T>([T? result]) {
    Navigator.of(this).pop<T>(result);
  }

  /// Pop to root
  void popToRoot() {
    Navigator.of(this).popUntil((route) => route.isFirst);
  }

  /// Pop until a specific route
  void popUntilRoute(String routeName) {
    Navigator.of(this).popUntil(ModalRoute.withName(routeName));
  }

  /// Can pop?
  bool get canPopPage => Navigator.of(this).canPop();

  /// Maybe pop (safe pop)
  Future<bool> maybePopPage<T>([T? result]) {
    return Navigator.of(this).maybePop<T>(result);
  }

  /// Show a modal bottom sheet
  Future<T?> showBottomSheet<T>({
    required Widget Function(BuildContext) builder,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = false,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
  }) {
    return showModalBottomSheet<T>(
      context: this,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape:
          shape ??
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
      builder: builder,
    );
  }

  /// Show a full-screen modal
  Future<T?> showFullScreenModal<T>(Widget page) {
    return Navigator.of(
      this,
    ).push<T>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => page));
  }
}

enum RouteTransition { fade, slideRight, slideUp, scale }

/// Helper class for building routes with named routes
class AppRoutes {
  AppRoutes._();

  /// Generate route based on settings
  static Route<dynamic>? onGenerateRoute(
    RouteSettings settings,
    Map<String, Widget Function(dynamic args)> routes,
  ) {
    final builder = routes[settings.name];
    if (builder == null) return null;

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => builder(settings.arguments),
    );
  }

  /// Create a route with hero animation
  static Route<T> heroRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}

/// Route guard for protected routes
abstract class RouteGuard {
  /// Check if navigation is allowed
  Future<bool> canNavigate(BuildContext context);

  /// Redirect route when not allowed
  String? get redirectTo;

  /// Wrap a widget with this guard
  Widget guard(Widget child) {
    return _GuardedRoute(guard: this, child: child);
  }
}

class _GuardedRoute extends StatefulWidget {
  final RouteGuard guard;
  final Widget child;

  const _GuardedRoute({required this.guard, required this.child});

  @override
  State<_GuardedRoute> createState() => _GuardedRouteState();
}

class _GuardedRouteState extends State<_GuardedRoute> {
  bool _isChecking = true;
  bool _isAllowed = false;

  @override
  void initState() {
    super.initState();
    _checkGuard();
  }

  Future<void> _checkGuard() async {
    final allowed = await widget.guard.canNavigate(context);
    if (!mounted) return;

    if (!allowed && widget.guard.redirectTo != null) {
      Navigator.of(context).pushReplacementNamed(widget.guard.redirectTo!);
      return;
    }

    setState(() {
      _isAllowed = allowed;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAllowed) {
      return const Scaffold(body: Center(child: Text('Access Denied')));
    }

    return widget.child;
  }
}

/// Tab navigator for bottom navigation preserving state
class TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final String initialRoute;
  final Map<String, Widget Function(dynamic)> routes;

  const TabNavigator({
    super.key,
    required this.navigatorKey,
    required this.initialRoute,
    required this.routes,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      initialRoute: initialRoute,
      onGenerateRoute: (settings) =>
          AppRoutes.onGenerateRoute(settings, routes),
    );
  }
}
