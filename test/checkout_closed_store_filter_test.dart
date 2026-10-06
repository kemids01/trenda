import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/stores/widgets/closed_store_dialog.dart'
    show isStoreOrderable;

void main() {
  test('null status is treated as orderable (backend authoritative)', () {
    expect(isStoreOrderable(null), true);
  });
  test('isOpen false is not orderable', () {
    expect(isStoreOrderable(false), false);
  });
  test('isOpen true is orderable', () {
    expect(isStoreOrderable(true), true);
  });
}
