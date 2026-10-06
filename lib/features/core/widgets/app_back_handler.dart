// lib/features/core/widgets/app_back_handler.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/tab_provider.dart';
import '../router/app_router.dart';

/// What the phone's back button should do.
enum BackAction {
  /// Let the router pop the page (or, with nothing left, leave the app).
  defaultPop,

  /// The page is the only one on the stack — go home instead of leaving.
  goHome,

  /// On the main screen but not on Shop — switch to the Shop tab.
  shopTab,
}

/// Pages that are allowed to close the app on back: the launch flow, which
/// decides where to go on its own.
const _exitablePaths = {Routes.splash, Routes.onboarding};

/// The pure rule. Back leaves the app only from the Shop tab of the main
/// screen; anywhere else it returns to the previous page, or home when a page
/// was opened with `go()` (order confirmation, a notification) and has nothing
/// under it.
BackAction resolveBackAction({
  required bool canPop,
  required String path,
  required int tabIndex,
}) {
  if (canPop) return BackAction.defaultPop;
  if (path == Routes.main) {
    return tabIndex == 0 ? BackAction.defaultPop : BackAction.shopTab;
  }
  if (_exitablePaths.contains(path)) return BackAction.defaultPop;
  return BackAction.goHome;
}

/// Takes the Android back button before the router does. Registered on the
/// router's own back-button dispatcher because `MaterialApp.builder` sits above
/// the Router, where a `BackButtonListener` cannot find one. When it declines,
/// the router's handling runs unchanged (dialogs, sheets and pushed pages still
/// pop normally).
class AppBackHandler extends ConsumerStatefulWidget {
  final GoRouter router;
  final Widget child;

  const AppBackHandler({super.key, required this.router, required this.child});

  @override
  ConsumerState<AppBackHandler> createState() => _AppBackHandlerState();
}

class _AppBackHandlerState extends ConsumerState<AppBackHandler> {
  ChildBackButtonDispatcher? _dispatcher;

  @override
  void initState() {
    super.initState();
    // The Router is BELOW this widget and registers itself with the root
    // dispatcher in its own initState; taking priority before that asserts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _dispatcher == null) _attach();
    });
  }

  @override
  void didUpdateWidget(AppBackHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router && _dispatcher != null) {
      _detach(oldWidget.router);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _dispatcher == null) _attach();
      });
    }
  }

  @override
  void dispose() {
    _detach(widget.router);
    super.dispose();
  }

  void _attach() {
    _dispatcher = widget.router.backButtonDispatcher
        .createChildBackButtonDispatcher()
      ..addCallback(_onBack)
      ..takePriority();
  }

  void _detach(GoRouter router) {
    final d = _dispatcher;
    if (d == null) return;
    d.removeCallback(_onBack);
    router.backButtonDispatcher.forget(d);
    _dispatcher = null;
  }

  Future<bool> _onBack() async {
    final router = widget.router;
    final action = resolveBackAction(
      canPop: router.canPop(),
      path: router.routerDelegate.currentConfiguration.uri.path,
      tabIndex: ref.read(selectedTabProvider),
    );
    switch (action) {
      case BackAction.defaultPop:
        return false;
      case BackAction.shopTab:
        ref.read(selectedTabProvider.notifier).state = 0;
        return true;
      case BackAction.goHome:
        router.go(Routes.main);
        return true;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
