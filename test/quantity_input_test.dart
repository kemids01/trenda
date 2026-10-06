// test/quantity_input_test.dart
// The typed quantity box shared by the product page and the basket.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/cart/widgets/quantity_input.dart';

void main() {
  group('parseQuantity', () {
    test('reads a typed number', () {
      expect(parseQuantity('24'), 24);
      expect(parseQuantity(' 7 '), 7);
    });

    test('blank or junk is null, so the field keeps its last value', () {
      expect(parseQuantity(''), isNull);
      expect(parseQuantity('abc'), isNull);
    });

    test('never below one', () {
      expect(parseQuantity('0'), 1);
    });

    test('cut down to the shelf', () {
      expect(parseQuantity('50', max: 12), 12);
      expect(parseQuantity('5', max: 12), 5);
    });

    test('no known ceiling leaves it alone', () {
      expect(parseQuantity('500'), 500);
    });
  });

  group('QuantityInput', () {
    Future<List<int>> pump(
      WidgetTester tester, {
      int value = 1,
      int? max,
      List<int>? drafts,
      List<int>? limits,
    }) async {
      final changes = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuantityInput(
              value: value,
              max: max,
              onChanged: changes.add,
              onDraft: drafts?.add,
              onLimit: limits?.add,
            ),
          ),
        ),
      ));
      return changes;
    }

    testWidgets('typing previews, Done commits', (tester) async {
      final drafts = <int>[];
      final changes = await pump(tester, drafts: drafts);

      await tester.enterText(find.byType(TextField), '12');
      expect(drafts.last, 12);
      expect(changes, isEmpty);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(changes, [12]);
    });

    testWidgets('a typed number past stock is cut down and explained',
        (tester) async {
      final limits = <int>[];
      final changes = await pump(tester, max: 5, limits: limits);

      await tester.enterText(find.byType(TextField), '40');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(changes, [5]);
      expect(limits, [5]);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('the plus button steps once, not twice', (tester) async {
      final changes = await pump(tester, value: 3);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      expect(changes, [4]);
    });

    testWidgets('plus at the ceiling reports the limit instead',
        (tester) async {
      final limits = <int>[];
      final changes = await pump(tester, value: 2, max: 2, limits: limits);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      expect(changes, isEmpty);
      expect(limits, [2]);
    });
  });
}
