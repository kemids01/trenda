import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/keyboard_docked_bar.dart';

Widget _app({required double keyboard}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: const Scaffold(
          body: SizedBox.expand(),
          bottomNavigationBar: KeyboardDockedBar(
            child: SizedBox(key: Key('dock'), height: 60),
          ),
        ),
      ),
    );

void main() {
  testWidgets('the dock rides on top of the keyboard', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(keyboard: 300));
    // Scaffold never lifts bottomNavigationBar itself — without the lift the
    // dock's bottom would be 800, hidden behind a 300px keyboard.
    expect(tester.getRect(find.byKey(const Key('dock'))).bottom, 500);
  });

  testWidgets('with no keyboard the dock stays at the bottom', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(keyboard: 0));
    expect(tester.getRect(find.byKey(const Key('dock'))).bottom, 800);
  });
}
