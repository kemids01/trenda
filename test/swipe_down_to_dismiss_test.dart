import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_frontend/features/core/widgets/swipe_down_to_dismiss.dart';

class _Detail extends StatefulWidget {
  const _Detail();
  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SwipeDownToDismiss(
      controller: _scroll,
      builder: (context, physics) => Scaffold(
        body: CustomScrollView(
          key: const ValueKey('detail-scroll'),
          controller: _scroll,
          physics: physics,
          slivers: [
            SliverList.builder(
              itemCount: 60,
              itemBuilder: (_, i) => SizedBox(height: 60, child: Text('row $i')),
            ),
          ],
        ),
      ),
    );
  }
}

GoRouter _router({String initial = '/'}) => GoRouter(initialLocation: initial, routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Center(child: Text('LIST PAGE'))),
      ),
      GoRoute(
        path: '/detail',
        pageBuilder: (context, state) => swipeDismissiblePage(key: state.pageKey, child: const _Detail()),
      ),
    ]);

Future<GoRouter> _open(WidgetTester t) async {
  final router = _router();
  await t.pumpWidget(MaterialApp.router(routerConfig: router));
  router.push('/detail');
  await t.pumpAndSettle();
  expect(find.text('row 0'), findsOneWidget);
  return router;
}

void main() {
  testWidgets('dragging down from the top past the threshold closes the page', (t) async {
    await _open(t);
    await t.drag(find.byKey(const ValueKey('detail-scroll')), const Offset(0, 300));
    await t.pumpAndSettle();
    expect(find.byType(_Detail), findsNothing);
    expect(find.text('LIST PAGE'), findsOneWidget);
  });

  testWidgets('the page follows the finger while dragging', (t) async {
    await _open(t);
    final g = await t.startGesture(t.getCenter(find.byKey(const ValueKey('detail-scroll'))));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, 12));
      await t.pump();
    }
    // The page has moved down with the finger (the see-through route shows what is under it).
    expect(t.getTopLeft(find.byKey(const ValueKey('detail-scroll'))).dy, greaterThan(80));
    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('moving back up shrinks the pull without scrolling the list', (t) async {
    await _open(t);
    final g = await t.startGesture(t.getCenter(find.byKey(const ValueKey('detail-scroll'))));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, 12));
      await t.pump();
    }
    for (var i = 0; i < 9; i++) {
      await g.moveBy(const Offset(0, -12));
      await t.pump();
    }
    expect(t.getTopLeft(find.byKey(const ValueKey('detail-scroll'))).dy, lessThan(40));
    expect(find.text('row 0'), findsOneWidget); // the list itself never scrolled
    await g.up();
    await t.pumpAndSettle();
    expect(find.byType(_Detail), findsOneWidget);
  });

  testWidgets('a short drag springs back', (t) async {
    await _open(t);
    await t.drag(find.byKey(const ValueKey('detail-scroll')), const Offset(0, 60));
    await t.pumpAndSettle();
    expect(find.text('row 0'), findsOneWidget);
    expect(t.getTopLeft(find.byType(SwipeDownToDismiss)).dy, 0);
  });

  testWidgets('scrolled down, a downward drag scrolls instead of closing', (t) async {
    await _open(t);
    await t.drag(find.byKey(const ValueKey('detail-scroll')), const Offset(0, -900));
    await t.pumpAndSettle();
    expect(find.text('row 0'), findsNothing);
    await t.drag(find.byKey(const ValueKey('detail-scroll')), const Offset(0, 300));
    await t.pumpAndSettle();
    expect(find.byType(_Detail), findsOneWidget); // still on the detail page
    expect(t.getTopLeft(find.byType(SwipeDownToDismiss)).dy, 0);
    expect(find.text('row 0'), findsNothing); // it scrolled, it did not pull
  });

  testWidgets('with nothing underneath it springs back', (t) async {
    await t.pumpWidget(MaterialApp.router(routerConfig: _router(initial: '/detail')));
    await t.pumpAndSettle();
    await t.drag(find.byKey(const ValueKey('detail-scroll')), const Offset(0, 300));
    await t.pumpAndSettle();
    expect(find.text('row 0'), findsOneWidget);
    expect(t.getTopLeft(find.byType(SwipeDownToDismiss)).dy, 0);
  });
}
