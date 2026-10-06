import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/utils/carousel_loop.dart';

void main() {
  test('a single card does not loop and stays bounded', () {
    expect(carouselLoops(1), isFalse);
    expect(loopItemCount(1), 1);
    expect(loopInitialPage(1), 0);
  });

  test('several cards loop: unbounded, opening deep in the range', () {
    expect(carouselLoops(5), isTrue);
    expect(loopItemCount(5), isNull);
    expect(loopInitialPage(5), 5 * kLoopCycles);
    expect(loopIndex(loopInitialPage(5, 1), 5), 1);
  });

  test('one past the last card is the first, one before the first is the last',
      () {
    final start = loopInitialPage(4);
    expect(loopIndex(start + 3, 4), 3);
    expect(loopIndex(start + 4, 4), 0);
    expect(loopIndex(start - 1, 4), 3);
  });

  test('an empty list never divides by zero', () {
    expect(loopIndex(7, 0), 0);
  });
}
