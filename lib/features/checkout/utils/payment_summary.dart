// lib/features/checkout/utils/payment_summary.dart
// The lines of the checkout receipt, in order, decided once.
//
// The review step and the bottom bar used to show `total` alone. A gift card is
// a PAYMENT METHOD, not a discount — it leaves order.total untouched and only
// lowers the cash the rider collects — so a shopper paying with one saw a
// figure on the confirm screen that was NOT what they would hand over at the
// door. The gift-card amount was computed in the step-2 selector and went no
// further.
//
// Canonical reference: trenda_backend/docs/GIFT_CARDS.md

import 'package:flutter/foundation.dart';
import '../../giftcards/logic/gift_card_support.dart' show cashDue;

enum PaymentLineKind {
  subtotal,
  discount,
  delivery,
  freeDelivery,

  /// The order's own total, before any gift card is spent against it.
  orderTotal,

  /// Gift card spent — reduces the cash collected, not the order total.
  giftCard,

  /// What the customer actually hands over.
  dueOnDelivery,
}

@immutable
class PaymentLine {
  final PaymentLineKind kind;
  final String label;

  /// Signed amount: negative for money coming off what is collected.
  final double amount;

  /// Free delivery has no number to print.
  final String? literal;

  const PaymentLine({
    required this.kind,
    required this.label,
    required this.amount,
    this.literal,
  });

  bool get isCredit => amount < 0;

  /// The line the eye should land on.
  bool get isEmphasis =>
      kind == PaymentLineKind.dueOnDelivery || kind == PaymentLineKind.orderTotal;
}

double _r2(double v) => (v * 100).round() / 100;

/// Builds the receipt.
///
/// [total] is the order total the server will record (goods − coupon +
/// delivery). [giftCardApplied] is what the selected card pays toward the
/// goods, already capped by `GiftCard.appliedTo`.
///
/// When no gift card is in play the receipt ends at a single total line, so an
/// ordinary order reads exactly as it did before.
List<PaymentLine> paymentSummaryLines({
  required double subtotal,
  required double discount,
  required double shippingFee,
  required double total,
  bool isFreeDelivery = false,
  double giftCardApplied = 0,
  String? distanceLabel,
}) {
  final lines = <PaymentLine>[
    PaymentLine(
      kind: PaymentLineKind.subtotal,
      label: 'Subtotal',
      amount: _r2(subtotal),
    ),
  ];

  if (discount > 0) {
    lines.add(PaymentLine(
      kind: PaymentLineKind.discount,
      label: 'Discount',
      amount: -_r2(discount),
    ));
  }

  if (isFreeDelivery) {
    lines.add(const PaymentLine(
      kind: PaymentLineKind.freeDelivery,
      label: 'Delivery',
      amount: 0,
      literal: 'FREE',
    ));
  } else {
    lines.add(PaymentLine(
      kind: PaymentLineKind.delivery,
      label: distanceLabel == null ? 'Delivery' : 'Delivery ($distanceLabel)',
      amount: _r2(shippingFee),
    ));
  }

  final applied = giftCardApplied <= 0 ? 0.0 : _r2(giftCardApplied);

  if (applied <= 0) {
    lines.add(PaymentLine(
      kind: PaymentLineKind.dueOnDelivery,
      label: 'Total',
      amount: _r2(total),
    ));
    return lines;
  }

  // With a card in play the two figures differ, so both are named: what the
  // order is worth, and what the rider collects.
  lines.add(PaymentLine(
    kind: PaymentLineKind.orderTotal,
    label: 'Order total',
    amount: _r2(total),
  ));
  lines.add(PaymentLine(
    kind: PaymentLineKind.giftCard,
    label: 'Gift card',
    amount: -applied,
  ));
  lines.add(PaymentLine(
    kind: PaymentLineKind.dueOnDelivery,
    label: 'To pay on delivery',
    amount: paymentDueOnDelivery(total: total, giftCardApplied: applied),
  ));
  return lines;
}

/// Cash the customer hands the rider. Never negative: the delivery fee is
/// always collected, because a rider who collects nothing has nothing to keep
/// or remit.
///
/// Delegates to the gift-card module's [cashDue] rather than repeating it — one
/// implementation, so the receipt and the gift-card panel cannot drift.
double paymentDueOnDelivery({
  required double total,
  required double giftCardApplied,
}) =>
    cashDue(total: total, applied: giftCardApplied <= 0 ? 0 : giftCardApplied);

/// What the confirm button should say about the amount, so the shopper is never
/// surprised at the door.
String payButtonAmountLabel({
  required double total,
  required double giftCardApplied,
}) =>
    giftCardApplied > 0 ? 'Due on delivery' : 'Total';

/// Whether the bottom bar should show the items subtotal instead of the order total. Only on the
/// address step (0): the delivery type is picked on step 1, so a total there carries a delivery fee
/// for a type the shopper has not chosen yet (₱540 = ₱500 + a Pasabay fee nobody selected).
bool showsItemsSubtotalOnly(int step) => step == 0;
