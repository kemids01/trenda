// test/closed_store_action_test.dart
// Pins the closed-store decision (SP2): open => allowed; closed+canOrder false => blocked;
// closed otherwise => advanceOrder.
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/stores/widgets/closed_store_dialog.dart';

void main() {
  group('closedStoreAction', () {
    test('open store => allowed', () {
      expect(closedStoreAction(isOpen: true, canOrder: true), ClosedStoreAction.allowed);
      expect(closedStoreAction(isOpen: true, canOrder: false), ClosedStoreAction.allowed);
    });

    test('unknown isOpen => allowed (server re-checks)', () {
      expect(closedStoreAction(isOpen: null, canOrder: null), ClosedStoreAction.allowed);
    });

    test('closed + not accepting orders => blocked', () {
      expect(closedStoreAction(isOpen: false, canOrder: false), ClosedStoreAction.blocked);
    });

    test('closed + accepting advance orders => advanceOrder', () {
      expect(closedStoreAction(isOpen: false, canOrder: true), ClosedStoreAction.advanceOrder);
    });

    test('closed + unknown canOrder => advanceOrder (fail-open, server re-checks)', () {
      expect(closedStoreAction(isOpen: false, canOrder: null), ClosedStoreAction.advanceOrder);
    });

    test('isStoreOrderable still reflects isOpen', () {
      expect(isStoreOrderable(false), false);
      expect(isStoreOrderable(true), true);
      expect(isStoreOrderable(null), true);
    });
  });
}
