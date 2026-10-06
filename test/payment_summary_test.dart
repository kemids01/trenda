// test/payment_summary_test.dart
// The checkout receipt. A gift card is a PAYMENT METHOD, not a discount: it
// leaves order.total untouched and only lowers the cash the rider collects.
// The confirm screen used to print `total` alone, so a shopper paying with a
// card saw a figure that was NOT what they would hand over at the door.
//
// Canonical reference: trenda_backend/docs/GIFT_CARDS.md

import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/utils/payment_summary.dart';

List<PaymentLine> _lines({
  double subtotal = 500,
  double discount = 0,
  double shippingFee = 60,
  double total = 560,
  bool isFreeDelivery = false,
  double giftCardApplied = 0,
  String? distanceLabel,
}) =>
    paymentSummaryLines(
      subtotal: subtotal,
      discount: discount,
      shippingFee: shippingFee,
      total: total,
      isFreeDelivery: isFreeDelivery,
      giftCardApplied: giftCardApplied,
      distanceLabel: distanceLabel,
    );

PaymentLine _of(List<PaymentLine> lines, PaymentLineKind kind) =>
    lines.firstWhere((l) => l.kind == kind);

bool _has(List<PaymentLine> lines, PaymentLineKind kind) =>
    lines.any((l) => l.kind == kind);

void main() {
  group('an ordinary order', () {
    test('reads subtotal, delivery, total — and mentions no gift card', () {
      final lines = _lines();

      expect(lines.map((l) => l.kind), [
        PaymentLineKind.subtotal,
        PaymentLineKind.delivery,
        PaymentLineKind.dueOnDelivery,
      ]);
      expect(_of(lines, PaymentLineKind.dueOnDelivery).label, 'Total');
      expect(_of(lines, PaymentLineKind.dueOnDelivery).amount, 560);
      expect(_has(lines, PaymentLineKind.giftCard), isFalse);
      expect(_has(lines, PaymentLineKind.orderTotal), isFalse);
    });

    test('shows a coupon as a credit', () {
      final lines = _lines(discount: 50, total: 510);
      final discount = _of(lines, PaymentLineKind.discount);

      expect(discount.amount, -50);
      expect(discount.isCredit, isTrue);
    });

    test('free delivery prints a word, not a zero', () {
      final lines = _lines(isFreeDelivery: true, total: 500);

      expect(_has(lines, PaymentLineKind.delivery), isFalse);
      expect(_of(lines, PaymentLineKind.freeDelivery).literal, 'FREE');
    });

    test('names the distance when there is one', () {
      expect(
        _of(_lines(distanceLabel: '4.2km'), PaymentLineKind.delivery).label,
        'Delivery (4.2km)',
      );
      expect(_of(_lines(), PaymentLineKind.delivery).label, 'Delivery');
    });
  });

  group('paid partly with a gift card', () {
    test('names BOTH figures: what the order is worth and what is collected',
        () {
      final lines = _lines(total: 560, giftCardApplied: 200);

      expect(_of(lines, PaymentLineKind.orderTotal).amount, 560);
      expect(_of(lines, PaymentLineKind.giftCard).amount, -200);
      expect(_of(lines, PaymentLineKind.dueOnDelivery).amount, 360);
      expect(
        _of(lines, PaymentLineKind.dueOnDelivery).label,
        'To pay on delivery',
      );
    });

    test('the gift card line is a credit', () {
      final card = _of(_lines(giftCardApplied: 200), PaymentLineKind.giftCard);
      expect(card.isCredit, isTrue);
    });

    test('the collected figure is the one emphasised', () {
      final lines = _lines(giftCardApplied: 200);
      expect(_of(lines, PaymentLineKind.dueOnDelivery).isEmphasis, isTrue);
    });

    test('a zero or negative card is ignored entirely', () {
      for (final applied in [0.0, -5.0]) {
        final lines = _lines(giftCardApplied: applied);
        expect(_has(lines, PaymentLineKind.giftCard), isFalse);
        expect(_of(lines, PaymentLineKind.dueOnDelivery).label, 'Total');
      }
    });
  });

  group('paymentDueOnDelivery', () {
    test('subtracts what the card pays', () {
      expect(paymentDueOnDelivery(total: 560, giftCardApplied: 200), 360);
    });

    test('never goes negative — the delivery fee is always collected', () {
      // A card bigger than the whole order still leaves the rider collecting
      // the fee, because a rider who collects ₱0 has nothing to keep or remit.
      expect(paymentDueOnDelivery(total: 60, giftCardApplied: 500), 0);
    });

    test('is the full total when no card is used', () {
      expect(paymentDueOnDelivery(total: 560, giftCardApplied: 0), 560);
      expect(paymentDueOnDelivery(total: 560, giftCardApplied: -1), 560);
    });

    test('rounds to centavos rather than drifting', () {
      expect(paymentDueOnDelivery(total: 100.456, giftCardApplied: 0.1), 100.36);
    });
  });

  group('payButtonAmountLabel', () {
    test('says what the number means', () {
      expect(
        payButtonAmountLabel(total: 560, giftCardApplied: 0),
        'Total',
      );
      expect(
        payButtonAmountLabel(total: 560, giftCardApplied: 200),
        'Due on delivery',
      );
    });
  });

  group('the receipt always reconciles', () {
    test('subtotal − discount + delivery = order total, and total − card = due',
        () {
      const subtotal = 1234.50;
      const discount = 100.0;
      const shipping = 85.0;
      const total = subtotal - discount + shipping;
      const applied = 300.0;

      final lines = _lines(
        subtotal: subtotal,
        discount: discount,
        shippingFee: shipping,
        total: total,
        giftCardApplied: applied,
      );

      final printedSubtotal = _of(lines, PaymentLineKind.subtotal).amount;
      final printedDiscount = _of(lines, PaymentLineKind.discount).amount;
      final printedDelivery = _of(lines, PaymentLineKind.delivery).amount;
      final printedTotal = _of(lines, PaymentLineKind.orderTotal).amount;
      final printedCard = _of(lines, PaymentLineKind.giftCard).amount;
      final printedDue = _of(lines, PaymentLineKind.dueOnDelivery).amount;

      expect(printedSubtotal + printedDiscount + printedDelivery, printedTotal);
      expect(printedTotal + printedCard, printedDue);
    });
  });

  // Step 1 (address) used to show ₱540 = items + a Pasabay fee the shopper had not chosen.
  test("only the address step shows the items subtotal alone", () {
    expect(showsItemsSubtotalOnly(0), isTrue);
    expect(showsItemsSubtotalOnly(1), isFalse);
    expect(showsItemsSubtotalOnly(2), isFalse);
  });
}
