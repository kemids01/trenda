import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/giftcards/logic/gift_card_support.dart';

void main() {
  Map<String, dynamic> api({
    String code = 'GIFT-ABC123',
    dynamic value = 1000,
    dynamic balance = 700,
    String status = 'active',
    String? validUntil,
    List<dynamic>? transactions,
  }) =>
      {
        '_id': 'oid-1',
        'code': code,
        'value': value,
        'balance': balance,
        'status': status,
        'validUntil': validUntil ??
            DateTime.now().add(const Duration(days: 200)).toIso8601String(),
        'transactions': transactions ?? const [],
      };

  group('GiftCard.fromJson', () {
    test('reads int JSON numbers without throwing', () {
      final c = GiftCard.fromJson(api(value: 1000, balance: 0));
      expect(c.value, 1000.0);
      expect(c.balance, 0.0);
    });

    test('reads doubles too', () {
      final c = GiftCard.fromJson(api(value: 999.5, balance: 250.25));
      expect(c.value, 999.5);
      expect(c.balance, 250.25);
    });

    test('survives a card with fields missing', () {
      final c = GiftCard.fromJson(const {});
      expect(c.balance, 0.0);
      expect(c.code, '—');
      expect(c.isSpendable, isFalse);
    });
  });

  group('isSpendable', () {
    test('an active card with balance is spendable', () {
      expect(GiftCard.fromJson(api()).isSpendable, isTrue);
    });

    test('an empty card is not', () {
      expect(GiftCard.fromJson(api(balance: 0, status: 'redeemed')).isSpendable, isFalse);
    });

    test('an expired card is not, even with balance left', () {
      final past = DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      expect(GiftCard.fromJson(api(validUntil: past)).isSpendable, isFalse);
    });

    test('a cancelled card is not', () {
      expect(GiftCard.fromJson(api(status: 'cancelled')).isSpendable, isFalse);
    });
  });

  group('appliedTo — mirrors the server cap', () {
    // The server computes min(balance, subtotal - discount) and NEVER lets a card touch the
    // delivery fee. The client must show the same number the server will charge.
    test('covers the goods subtotal when the balance exceeds it', () {
      final c = GiftCard.fromJson(api(balance: 1000));
      expect(c.appliedTo(subtotal: 300, discount: 0), 300.0);
    });

    test('covers only what the balance allows', () {
      final c = GiftCard.fromJson(api(balance: 200));
      expect(c.appliedTo(subtotal: 300, discount: 0), 200.0);
    });

    test('never exceeds goods due after a coupon', () {
      final c = GiftCard.fromJson(api(balance: 1000));
      expect(c.appliedTo(subtotal: 300, discount: 100), 200.0);
    });

    test('never covers the delivery fee', () {
      // A 1000 card against 300 of goods applies 300 — the 65 delivery fee is untouched.
      final c = GiftCard.fromJson(api(balance: 1000));
      expect(c.appliedTo(subtotal: 300, discount: 0), 300.0);
    });

    test('is zero for an unspendable card', () {
      final c = GiftCard.fromJson(api(balance: 0, status: 'redeemed'));
      expect(c.appliedTo(subtotal: 300, discount: 0), 0.0);
    });

    test('is zero when nothing is due', () {
      final c = GiftCard.fromJson(api(balance: 1000));
      expect(c.appliedTo(subtotal: 300, discount: 300), 0.0);
      expect(c.appliedTo(subtotal: 0, discount: 0), 0.0);
    });
  });

  group('cashDue', () {
    test('is the order total less what the card applies', () {
      final c = GiftCard.fromJson(api(balance: 1000));
      // goods 300 + delivery 65 = 365; card applies 300; customer hands over 65.
      expect(cashDue(total: 365, applied: c.appliedTo(subtotal: 300, discount: 0)), 65.0);
    });

    test('partial cover leaves the uncovered goods plus delivery', () {
      final c = GiftCard.fromJson(api(balance: 200));
      expect(cashDue(total: 365, applied: c.appliedTo(subtotal: 300, discount: 0)), 165.0);
    });

    test('never goes negative', () {
      expect(cashDue(total: 100, applied: 500), 0.0);
    });
  });

  group('spendableCards', () {
    test('keeps only cards that can pay, highest balance first', () {
      final cards = [
        GiftCard.fromJson(api(code: 'A', balance: 100)),
        GiftCard.fromJson(api(code: 'B', balance: 900)),
        GiftCard.fromJson(api(code: 'C', balance: 0, status: 'redeemed')),
        GiftCard.fromJson(api(code: 'D', balance: 500, status: 'cancelled')),
      ];
      final out = spendableCards(cards);
      expect(out.map((c) => c.code), ['B', 'A']);
    });
  });

  group('usage history', () {
    test('reads debits and reversals', () {
      final c = GiftCard.fromJson(api(transactions: [
        {'amount': 300, 'kind': 'debit', 'date': '2026-09-02T00:00:00.000Z'},
        {'amount': 300, 'kind': 'reversal', 'date': '2026-09-03T00:00:00.000Z'},
      ]));
      expect(c.usage, hasLength(2));
      expect(c.usage[0].amount, -300.0);
      expect(c.usage[0].label, 'Spent');
      expect(c.usage[1].amount, 300.0);
      expect(c.usage[1].label, 'Returned');
    });

    test('a transaction with no kind is treated as a debit', () {
      final c = GiftCard.fromJson(api(transactions: [
        {'amount': 50, 'date': '2026-09-02T00:00:00.000Z'},
      ]));
      expect(c.usage.single.amount, -50.0);
    });
  });

  group('claimFailureMessage', () {
    test('gives each failure its own actionable wording', () {
      final seen = <String>{};
      for (final f in ClaimFailure.values) {
        final msg = claimFailureMessage(f);
        expect(msg, isNotEmpty);
        seen.add(msg);
      }
      expect(seen, hasLength(ClaimFailure.values.length));
    });

    test('already-claimed says the code is spent, not that it is invalid', () {
      expect(
        claimFailureMessage(ClaimFailure.alreadyClaimed).toLowerCase(),
        contains('already'),
      );
    });
  });
}
