// test/profile_completion_test.dart
// What the profile page nudges about, and in what order.

import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/utils/profile_completion.dart';

void main() {
  group('profileCompletion', () {
    test('a fully filled profile has no gaps', () {
      final c = profileCompletion(
        fullName: 'Juan Dela Cruz',
        phone: '09171234567',
        photoUrl: 'https://cdn.test/me.jpg',
        addressCount: 1,
        birthday: DateTime(1990, 5, 2),
      );

      expect(c.isComplete, isTrue);
      expect(c.percent, 100);
      expect(c.next, isNull);
      expect(c.gaps, isEmpty);
    });

    test('an empty profile is 0% and lists everything', () {
      final c = profileCompletion();

      expect(c.percent, 0);
      expect(c.completed, 0);
      expect(c.gaps.length, c.total);
      expect(c.isComplete, isFalse);
    });

    test(
        'nudges about the delivery address first — nothing can be delivered '
        'without one', () {
      final c = profileCompletion(
        fullName: 'Juan',
        phone: '09171234567',
        photoUrl: 'https://cdn.test/me.jpg',
        birthday: DateTime(1990, 5, 2),
      );

      expect(c.next!.action, ProfileGapAction.address);
      expect(c.next!.label, 'Delivery address');
    });

    test('phone outranks the cosmetic fields', () {
      final c = profileCompletion(addressCount: 1);

      expect(c.next!.action, ProfileGapAction.phone);
    });

    test('a birthday is the last thing asked for', () {
      final c = profileCompletion(
        fullName: 'Juan',
        phone: '09171234567',
        photoUrl: 'https://cdn.test/me.jpg',
        addressCount: 2,
      );

      expect(c.gaps.length, 1);
      expect(c.next!.action, ProfileGapAction.birthday);
    });

    test('blank and whitespace-only values do not count as filled', () {
      final c = profileCompletion(
        fullName: '   ',
        phone: '  ',
        photoUrl: '',
        addressCount: 0,
      );

      expect(c.completed, 0);
    });

    test('percent tracks how much is filled', () {
      // 3 of 5 → 60%.
      final c = profileCompletion(
        fullName: 'Juan',
        phone: '09171234567',
        addressCount: 1,
      );

      expect(c.completed, 3);
      expect(c.total, 5);
      expect(c.percent, 60);
    });

    test('never asks for an email — Google sign-in always supplies it', () {
      final labels = profileCompletion().gaps.map((g) => g.label.toLowerCase());
      expect(labels.any((l) => l.contains('email')), isFalse);
    });

    test('a saved Google photo means the photo is done', () {
      final c = profileCompletion(
        addressCount: 1,
        phone: '09171234567',
        fullName: 'Juan',
        photoUrl: 'https://lh3.googleusercontent.com/a/abc',
      );
      expect(c.gaps.map((g) => g.action), [ProfileGapAction.birthday]);
    });

    test('every gap carries an action the page can route', () {
      for (final gap in profileCompletion().gaps) {
        expect(ProfileGapAction.values, contains(gap.action));
        expect(gap.label.trim(), isNotEmpty);
      }
    });
  });
}
