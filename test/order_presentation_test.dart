// test/order_presentation_test.dart
// How an order reads to the customer. The three order cards each carried their
// own switch over the status string, so the same order could be named
// differently depending on which tab it was in — and a status one card knew
// about fell through another's default and printed the raw backend token.

import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/orders/utils/order_presentation.dart';

void main() {
  group('orderStatusView', () {
    test('names every status in plain words, never a raw token', () {
      const statuses = [
        'pending',
        'confirmed',
        'waiting_for_batch',
        'batch_ready',
        'processing',
        'ready_to_ship',
        'assigned_to_rider',
        'shipped',
        'pickup_started',
        'out_for_delivery',
        'arriving_at_customer',
        'delivered',
        'completed',
        'cancelled',
        'returned',
        'refunded',
        'failed',
      ];

      for (final status in statuses) {
        final label = orderStatusView(status).label;
        expect(label, isNotEmpty, reason: status);
        expect(label, isNot(contains('_')), reason: status);
        expect(label[0], label[0].toUpperCase(), reason: status);
      }
    });

    test('an unknown status is title-cased rather than shown raw', () {
      // A status this build has not seen still reads as English.
      expect(orderStatusView('out_for_return').label, 'Out for return');
      expect(orderStatusView('').label, 'Unknown');
    });

    test('is case and whitespace insensitive', () {
      expect(orderStatusView('  DELIVERED ').label, 'Delivered');
      expect(orderStatusView('Pending').label, 'Awaiting confirmation');
    });

    test('tones match what the status means to the customer', () {
      expect(orderStatusView('pending').tone, OrderTone.waiting);
      expect(orderStatusView('processing').tone, OrderTone.inProgress);
      expect(orderStatusView('out_for_delivery').tone, OrderTone.arriving);
      expect(orderStatusView('arriving_at_customer').tone, OrderTone.arriving);
      expect(orderStatusView('delivered').tone, OrderTone.done);
      expect(orderStatusView('cancelled').tone, OrderTone.stopped);
      expect(orderStatusView('refunded').tone, OrderTone.stopped);
    });

    test('a status the old cards printed raw now has wording', () {
      // The cancelled card's switch only knew cancelled/returned/refunded, so
      // anything else reached its `default: return status`.
      expect(orderStatusView('out_for_delivery').label, 'Out for delivery');
      expect(orderStatusView('shipped').label, 'Handed to rider');
    });
  });

  group('canCancelOrder', () {
    test('only before the shop has started moving it', () {
      expect(canCancelOrder('pending'), isTrue);
      expect(canCancelOrder('confirmed'), isTrue);
    });

    test('not once a rider is involved', () {
      for (final s in [
        'processing',
        'ready_to_ship',
        'shipped',
        'out_for_delivery',
        'delivered',
      ]) {
        expect(canCancelOrder(s), isFalse, reason: s);
      }
    });

    test('tolerates case and padding', () {
      expect(canCancelOrder(' PENDING '), isTrue);
    });
  });

  group('isTerminalOrder', () {
    test('true once an order is over, either way', () {
      for (final s in [
        'delivered',
        'completed',
        'cancelled',
        'returned',
        'refunded',
        'failed',
      ]) {
        expect(isTerminalOrder(s), isTrue, reason: s);
      }
    });

    test('false while it is still moving', () {
      for (final s in ['pending', 'processing', 'out_for_delivery']) {
        expect(isTerminalOrder(s), isFalse, reason: s);
      }
    });
  });

  group('formatOrderDate', () {
    final now = DateTime(2026, 9, 13, 15, 30);

    test('today and yesterday are named, with a padded time', () {
      expect(
        formatOrderDate(DateTime(2026, 9, 13, 9, 5), now: now),
        'Today, 09:05',
      );
      expect(
        formatOrderDate(DateTime(2026, 9, 12, 21, 0), now: now),
        'Yesterday, 21:00',
      );
    });

    test('the last week counts days', () {
      expect(formatOrderDate(DateTime(2026, 9, 10), now: now), '3 days ago');
      expect(formatOrderDate(DateTime(2026, 9, 8), now: now), '5 days ago');
    });

    test('older this year shows the month and day', () {
      expect(
        formatOrderDate(DateTime(2026, 7, 4, 8, 15), now: now),
        'Jul 4, 08:15',
      );
    });

    test('a previous year carries the year', () {
      expect(formatOrderDate(DateTime(2025, 12, 25, 8, 15), now: now),
          'Dec 25, 2025');
    });

    test('pads single-digit times — the old formatter printed 9:5', () {
      final formatted = formatOrderDate(DateTime(2026, 9, 13, 9, 5), now: now);
      expect(formatted, contains('09:05'));
      expect(formatted, isNot(contains('9:5,')));
    });

    test('a null date is empty, not a crash or a fake date', () {
      expect(formatOrderDate(null, now: now), '');
    });

    test('a future-dated order still reads sensibly', () {
      expect(
        formatOrderDate(DateTime(2026, 9, 14, 10, 0), now: now),
        'Sep 14, 10:00',
      );
    });
  });

  _timelineTests();

  group('orderItemCountLabel', () {
    test('pluralises', () {
      expect(orderItemCountLabel(1), '1 item');
      expect(orderItemCountLabel(3), '3 items');
      expect(orderItemCountLabel(0), '0 items');
    });
  });
}

void _timelineTests() {
  group('stageForStatus', () {
    test('maps the happy path', () {
      expect(stageForStatus('pending'), OrderStage.placed);
      expect(stageForStatus('confirmed'), OrderStage.confirmed);
      expect(stageForStatus('waiting_for_batch'), OrderStage.confirmed);
      expect(stageForStatus('processing'), OrderStage.processing);
      expect(stageForStatus('ready_to_ship'), OrderStage.readyToShip);
      expect(stageForStatus('shipped'), OrderStage.riderAssigned);
      expect(stageForStatus('pickup_started'), OrderStage.riderAssigned);
      expect(stageForStatus('out_for_delivery'), OrderStage.outForDelivery);
      expect(stageForStatus('arriving_at_customer'), OrderStage.arriving);
      expect(stageForStatus('delivered'), OrderStage.delivered);
    });

    test('a stopped status is not a point on the path', () {
      for (final s in ['cancelled', 'returned', 'refunded', 'failed']) {
        expect(stageForStatus(s), isNull, reason: s);
      }
    });
  });

  group('orderStageStates on the happy path', () {
    test('everything before the current stage is done, nothing after', () {
      final states = orderStageStates(status: 'out_for_delivery');
      final done = states.where((s) => s.completed).map((s) => s.stage);
      final current = states.where((s) => s.current).map((s) => s.stage);

      expect(current, [OrderStage.outForDelivery]);
      expect(done, [
        OrderStage.placed,
        OrderStage.confirmed,
        OrderStage.processing,
        OrderStage.readyToShip,
        OrderStage.riderAssigned,
      ]);
      expect(
        states
            .where((s) => s.stage == OrderStage.arriving)
            .single
            .completed,
        isFalse,
      );
    });

    test('a delivered order completes the last stage too', () {
      final states = orderStageStates(status: 'delivered');
      expect(states.every((s) => s.completed), isTrue);
      expect(states.last.current, isTrue);
    });

    test('a brand new order has only the first stage current', () {
      final states = orderStageStates(status: 'pending');
      expect(states.first.current, isTrue);
      expect(states.where((s) => s.completed), isEmpty);
    });
  });

  group('orderStageStates when the order stopped', () {
    test('a cancelled order does NOT claim stages it never reached', () {
      // The page used to test `!['pending','confirmed','processing']
      // .contains(status)`; 'cancelled' is in none of those, so shipping
      // stages rendered as DONE on an order cancelled while still pending.
      final states = orderStageStates(
        status: 'cancelled',
        history: ['pending', 'cancelled'],
      );

      for (final s in states) {
        if (s.stage == OrderStage.placed) continue;
        expect(s.completed, isFalse, reason: '${s.stage}');
      }
      expect(states.every((s) => !s.current), isTrue);
    });

    test('credits the stages the history can vouch for', () {
      final states = orderStageStates(
        status: 'cancelled',
        history: ['pending', 'confirmed', 'processing', 'cancelled'],
      );

      Map<OrderStage, bool> done = {
        for (final s in states) s.stage: s.completed
      };
      expect(done[OrderStage.placed], isTrue);
      expect(done[OrderStage.confirmed], isTrue);
      expect(done[OrderStage.processing], isTrue);
      expect(done[OrderStage.readyToShip], isFalse);
      expect(done[OrderStage.outForDelivery], isFalse);
    });

    test('with no history, nothing past placed is claimed', () {
      final states = orderStageStates(status: 'cancelled');
      expect(states.first.completed, isTrue);
      expect(states.skip(1).every((s) => !s.completed), isTrue);
    });

    test('a returned order credits the delivery that did happen', () {
      final states = orderStageStates(
        status: 'returned',
        history: ['pending', 'confirmed', 'out_for_delivery', 'delivered'],
      );
      expect(states.every((s) => s.completed), isTrue);
      expect(states.every((s) => !s.current), isTrue);
    });

    test('history entries out of order still credit the furthest reached', () {
      final states = orderStageStates(
        status: 'cancelled',
        history: ['processing', 'pending', 'confirmed'],
      );
      final done = {for (final s in states) s.stage: s.completed};
      expect(done[OrderStage.processing], isTrue);
      expect(done[OrderStage.readyToShip], isFalse);
    });
  });
}
