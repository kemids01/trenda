import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/stores/widgets/closed_store_dialog.dart';

void main() {
  Future<bool?> open(WidgetTester tester, {String? question, String? confirm}) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = question == null
                ? await showClosedStoreDialog(context, storeName: 'Trenda Test Store')
                : await showClosedStoreDialog(context,
                    storeName: 'Trenda Test Store',
                    reopening: 'Opens Tue · 9:00 AM',
                    question: question,
                    confirmLabel: confirm!);
          },
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('checkout wording: asks to place the order and wait; confirm returns true',
      (tester) async {
    await open(tester,
        question: 'Do you still want to place your order and wait for the store to open?',
        confirm: 'Place order & wait');
    expect(find.text('Trenda Test Store is currently closed.'), findsOneWidget);
    expect(find.textContaining('Opens Tue · 9:00 AM'), findsOneWidget);
    expect(find.text('Do you still want to place your order and wait for the store to open?'),
        findsOneWidget);
    await tester.tap(find.text('Place order & wait'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('default wording is unchanged for other callers', (tester) async {
    await open(tester);
    expect(find.text('Do you still want to proceed with your order?'), findsOneWidget);
    expect(find.text('Order Anyway'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
