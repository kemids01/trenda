// trenda_frontend/lib/features/giftcards/logic/gift_card_support.dart
//
// Pure gift-card model + the arithmetic the checkout screen shows.
//
// ⚠️ `appliedTo` MIRRORS the server's cap: min(balance, subtotal − discount). The card pays for
// GOODS only and can never touch the delivery fee, because a rider who collects ₱0 has nothing to
// keep or remit. If this drifts from the server the customer sees a figure they are not charged.
//
// Canonical reference: trenda_backend/docs/GIFT_CARDS.md
import '../data/gift_card_repository.dart' show ClaimFailure;

export '../data/gift_card_repository.dart' show ClaimFailure;

double _d(dynamic v) => (v is num) ? v.toDouble() : 0.0;
double _r2(double v) => (v * 100).round() / 100;

/// One line of a card's history.
class GiftCardUsage {
  final DateTime? date;
  final String label;

  /// Negative when spent, positive when returned by a cancelled order.
  final double amount;

  const GiftCardUsage({required this.date, required this.label, required this.amount});
}

class GiftCard {
  final String id;
  final String code;
  final double value;
  final double balance;
  final String status;
  final DateTime? validUntil;
  final DateTime? claimedAt;
  final List<GiftCardUsage> usage;

  const GiftCard({
    required this.id,
    required this.code,
    required this.value,
    required this.balance,
    required this.status,
    required this.validUntil,
    required this.claimedAt,
    required this.usage,
  });

  factory GiftCard.fromJson(Map<String, dynamic> json) {
    final txns = (json['transactions'] as List<dynamic>?) ?? const [];
    return GiftCard(
      id: (json['_id'] ?? '').toString(),
      code: (json['code'] ?? '—').toString(),
      value: _d(json['value']),
      balance: _d(json['balance']),
      status: (json['status'] ?? 'active').toString(),
      validUntil: DateTime.tryParse((json['validUntil'] ?? '').toString()),
      claimedAt: DateTime.tryParse((json['claimedAt'] ?? '').toString()),
      usage: txns.whereType<Map>().map((t) {
        final isReversal = t['kind'] == 'reversal';
        final amount = _d(t['amount']);
        return GiftCardUsage(
          date: DateTime.tryParse((t['date'] ?? '').toString()),
          label: isReversal ? 'Returned' : 'Spent',
          amount: isReversal ? amount : -amount,
        );
      }).toList(),
    );
  }

  bool get isExpired {
    final until = validUntil;
    return until != null && DateTime.now().isAfter(until);
  }

  /// Can this card pay for anything right now?
  bool get isSpendable =>
      balance > 0 && status != 'cancelled' && status != 'redeemed' && !isExpired;

  /// How much this card takes off an order — the same figure the server will apply.
  double appliedTo({required double subtotal, double discount = 0}) {
    if (!isSpendable) return 0.0;
    final goodsDue = _r2(subtotal - discount);
    if (goodsDue <= 0) return 0.0;
    return _r2(balance < goodsDue ? balance : goodsDue);
  }

  /// Portion already used, 0..1 — for the progress bar.
  double get spentShare {
    if (value <= 0) return 0.0;
    final v = (value - balance) / value;
    return v.clamp(0.0, 1.0);
  }
}

/// Cash the customer still hands the rider at the door. Never negative — the delivery fee is
/// always collected, so this is at minimum the shipping cost.
double cashDue({required double total, required double applied}) {
  final due = _r2(total - applied);
  return due < 0 ? 0.0 : due;
}

/// Cards worth offering at checkout, biggest balance first.
List<GiftCard> spendableCards(List<GiftCard> cards) {
  final out = cards.where((c) => c.isSpendable).toList();
  out.sort((a, b) => b.balance.compareTo(a.balance));
  return out;
}

/// Wording per failure. Each case needs a different action from the customer, so none of these
/// collapse into a generic "invalid code".
String claimFailureMessage(ClaimFailure failure) {
  switch (failure) {
    case ClaimFailure.notFound:
      return 'That code is not valid. Check the characters and try again.';
    case ClaimFailure.alreadyClaimed:
      return 'This gift card has already been claimed by someone else.';
    case ClaimFailure.expired:
      return 'This gift card has expired and can no longer be used.';
    case ClaimFailure.cancelled:
      return 'This gift card is no longer valid. Contact support if you think that is wrong.';
    case ClaimFailure.unauthenticated:
      return 'Sign in to add a gift card to your account.';
    case ClaimFailure.network:
      return 'Could not reach Trenda. Check your connection and try again.';
  }
}
