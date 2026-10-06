import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/giftcards/screens/gift_card_help_screen.dart';

void main() {
  Future<void> pumpHelp(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: GiftCardHelpScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('renders on a phone-sized screen without overflowing', (tester) async {
    await pumpHelp(tester, const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(find.text('How gift cards work'), findsOneWidget);
  });

  testWidgets('renders on a small phone too', (tester) async {
    await pumpHelp(tester, const Size(320, 640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('leads with the rule customers most need: delivery is paid in cash', (tester) async {
    await pumpHelp(tester, const Size(390, 1400));
    expect(find.text('Pay the delivery fee at the door'), findsOneWidget);
  });

  testWidgets('covers the three steps', (tester) async {
    await pumpHelp(tester, const Size(390, 1400));
    expect(find.text('Add your card'), findsOneWidget);
    expect(find.text('Use it at checkout'), findsOneWidget);
    expect(find.text('Pay the delivery fee at the door'), findsOneWidget);
  });

  testWidgets('answers the questions a buyer actually asks', (tester) async {
    await pumpHelp(tester, const Size(390, 2400));
    for (final q in [
      'What if my card is worth more than my order?',
      'What if my order costs more than my card?',
      'Can I use two gift cards on one order?',
      'What happens if my order is cancelled?',
      'My code says it is already claimed',
      'Do gift cards expire?',
      'Can I buy a gift card?',
    ]) {
      expect(find.text(q), findsOneWidget, reason: 'missing question: $q');
    }
  });

  testWidgets('says nothing about internal settlement mechanics', (tester) async {
    // Riders, remittance credits, vendor payment and liability are staff concerns. Surfacing
    // them here would only confuse a buyer — the staff version lives in trenda_admin nav 13.
    await pumpHelp(tester, const Size(390, 2400));
    for (final internal in ['remittance', 'liability', 'vendorNet', 'commission']) {
      expect(
        find.textContaining(internal, findRichText: true),
        findsNothing,
        reason: 'internal term leaked to the customer guide: $internal',
      );
    }
  });
}
