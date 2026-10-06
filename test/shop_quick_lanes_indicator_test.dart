import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/shop_quick_lanes.dart';

Widget _host() => const MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 360, child: ShopQuickLanes()),
      ),
    );

double _thumbLeft(WidgetTester tester) {
  final indicator = find.byKey(const ValueKey('shop-quick-lanes-indicator'));
  final thumb = find.descendant(
    of: indicator,
    matching: find.byWidgetPredicate(
      (w) => w is Positioned && w.width != null,
    ),
  );
  return tester.widget<Positioned>(thumb).left!;
}

void main() {
  testWidgets('shows a scroll indicator under the lane row on first build',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(find.byKey(const ValueKey('shop-quick-lanes-indicator')),
        findsOneWidget);
    expect(_thumbLeft(tester), 0);
  });

  testWidgets('the thumb moves when the row is swiped', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.drag(
        find.byKey(const ValueKey('shop-quick-lanes')), const Offset(-2000, 0));
    await tester.pumpAndSettle();
    final left = _thumbLeft(tester);
    expect(left, greaterThan(0));
  });

  testWidgets('indicator draws nothing when every button fits',
      (tester) async {
    // The default 800px test window would clamp the 4000px box.
    tester.view.physicalSize = const Size(4000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 4000, child: ShopQuickLanes()),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('shop-quick-lanes-indicator')),
        findsNothing);
  });
}
