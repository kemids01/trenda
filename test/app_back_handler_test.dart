import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_frontend/features/core/providers/tab_provider.dart';
import 'package:trenda_frontend/features/core/router/app_router.dart';
import 'package:trenda_frontend/features/core/widgets/app_back_handler.dart';

void main() {
  group('resolveBackAction', () {
    test('a page with something under it pops normally', () {
      expect(
        resolveBackAction(canPop: true, path: '/product/1', tabIndex: 3),
        BackAction.defaultPop,
      );
    });

    test('a lone page goes home instead of closing the app', () {
      expect(
        resolveBackAction(canPop: false, path: '/orders/abc', tabIndex: 0),
        BackAction.goHome,
      );
    });

    test('main screen off the Shop tab returns to Shop', () {
      expect(
        resolveBackAction(canPop: false, path: Routes.main, tabIndex: 2),
        BackAction.shopTab,
      );
    });

    test('only the Shop tab (and the launch flow) may close the app', () {
      expect(
        resolveBackAction(canPop: false, path: Routes.main, tabIndex: 0),
        BackAction.defaultPop,
      );
      expect(
        resolveBackAction(canPop: false, path: Routes.splash, tabIndex: 0),
        BackAction.defaultPop,
      );
    });
  });

  group('AppBackHandler with a real router', () {
    late GoRouter router;
    late ProviderContainer container;

    Future<void> pump(WidgetTester tester, String initial) async {
      router = GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(path: Routes.main, builder: (_, __) => const Text('MAIN')),
          GoRoute(path: '/orders/:id', builder: (_, __) => const Text('ORDER')),
          GoRoute(path: '/product/:id', builder: (_, __) => const Text('PRODUCT')),
        ],
      );
      container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (_, child) => AppBackHandler(router: router, child: child!),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<bool> pressBack(WidgetTester tester) async {
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      return handled;
    }

    testWidgets('a page opened with go() returns home', (tester) async {
      await pump(tester, '/orders/abc');
      expect(await pressBack(tester), isTrue);
      expect(find.text('MAIN'), findsOneWidget);
    });

    testWidgets('a pushed page pops back to where it came from',
        (tester) async {
      await pump(tester, Routes.main);
      router.push('/product/1');
      await tester.pumpAndSettle();
      expect(await pressBack(tester), isTrue);
      expect(find.text('MAIN'), findsOneWidget);
    });

    testWidgets('an open dialog closes first, the page stays', (tester) async {
      await pump(tester, '/orders/abc');
      final ctx = tester.element(find.text('ORDER'));
      showDialog<void>(context: ctx, builder: (_) => const Text('DIALOG'));
      await tester.pumpAndSettle();
      expect(await pressBack(tester), isTrue);
      expect(find.text('DIALOG'), findsNothing);
      expect(find.text('ORDER'), findsOneWidget);
    });

    testWidgets('a non-Shop tab goes back to Shop, then Shop closes the app',
        (tester) async {
      await pump(tester, Routes.main);
      container.read(selectedTabProvider.notifier).state = 3;
      expect(await pressBack(tester), isTrue);
      expect(container.read(selectedTabProvider), 0);
      // Nothing left to go back to: the system is allowed to close the app.
      expect(await pressBack(tester), isFalse);
    });
  });
}
