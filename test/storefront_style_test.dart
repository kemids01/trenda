// test/storefront_style_test.dart
// Pure helpers behind the storefront cards on the Stores street.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/stores/utils/storefront_style.dart';

void main() {
  group('awning colour', () {
    test('is stable for the same store across calls', () {
      expect(awningIndexFor('vendor-abc'), awningIndexFor('vendor-abc'));
      expect(
        awningPaletteFor('vendor-abc').stripe,
        awningPaletteFor('vendor-abc').stripe,
      );
    });

    test('spreads different stores across the palette', () {
      final seen = <int>{};
      for (var i = 0; i < 40; i++) {
        seen.add(awningIndexFor('vendor-$i'));
      }
      expect(seen.length, greaterThan(4));
    });

    test('always lands inside the palette, empty seed included', () {
      for (final seed in ['', 'a', 'Dubets Store', '68c1f0a9e3', '🛒']) {
        final i = awningIndexFor(seed);
        expect(i, inInclusiveRange(0, kAwningStripes.length - 1));
      }
    });

    test('dark mode darkens the stripe but keeps the same hue family', () {
      final light = awningPaletteFor('vendor-abc');
      final dark = awningPaletteFor('vendor-abc', brightness: Brightness.dark);
      expect(dark.stripe, isNot(light.stripe));
      expect(
        dark.stripe.computeLuminance(),
        lessThan(light.stripe.computeLuminance()),
      );
    });

    test('shuttered shops get greys, never a house colour', () {
      final p = shutteredPalette();
      expect(kAwningStripes, isNot(contains(p.stripe)));
    });
  });

  group('storeMonogram', () {
    test('takes the initials of the first two words', () {
      expect(storeMonogram('Dubets Store'), 'DS');
      expect(storeMonogram('Trenda Test Store'), 'TT');
    });

    test('takes two letters from a single word', () {
      expect(storeMonogram('Bakeshop'), 'BA');
      expect(storeMonogram('K'), 'K');
    });

    test('survives punctuation-only and empty names', () {
      expect(storeMonogram('   '), '?');
      expect(storeMonogram('***'), '?');
    });

    test('treats hyphens and underscores as word breaks', () {
      expect(storeMonogram('Dubets-Store'), 'DS');
      expect(storeMonogram('mini_mart'), 'MM');
      // Both leading words are "sari", so the monogram is SS by design.
      expect(storeMonogram('sari-sari tindahan'), 'SS');
    });
  });

  group('formatClockTime', () {
    test('converts 24h to 12h with a meridiem', () {
      expect(formatClockTime('08:00'), '8:00 AM');
      expect(formatClockTime('13:30'), '1:30 PM');
      expect(formatClockTime('00:15'), '12:15 AM');
      expect(formatClockTime('12:00'), '12:00 PM');
      expect(formatClockTime('23:45'), '11:45 PM');
    });

    test('passes through anything that is not a clock time', () {
      expect(formatClockTime('soon'), 'soon');
      expect(formatClockTime('99:99'), '99:99');
    });
  });

  group('shortDay', () {
    test('shortens weekday names', () {
      expect(shortDay('saturday'), 'Sat');
      expect(shortDay('MONDAY'), 'Mon');
    });

    test('handles unknown values without throwing', () {
      expect(shortDay(''), '');
      expect(shortDay('holiday'), 'Hol');
    });
  });

  group('formatReopening', () {
    test('builds the full line', () {
      expect(
        formatReopening(day: 'saturday', time: '08:00'),
        'Opens Sat · 8:00 AM',
      );
    });

    test('drops the half it does not have', () {
      expect(formatReopening(day: 'monday'), 'Opens Mon');
      expect(formatReopening(time: '17:00'), 'Opens 5:00 PM');
    });

    test('returns null when the store has no reopening slot', () {
      expect(formatReopening(), isNull);
      expect(formatReopening(day: '', time: '  '), isNull);
    });
  });

  group('joinMeta', () {
    test('joins present parts with a middot', () {
      expect(
        joinMeta(['Bakery', 'Tuguegarao City']),
        'Bakery · Tuguegarao City',
      );
    });

    test('never leaves a dangling separator', () {
      expect(joinMeta(['Bakery', null]), 'Bakery');
      expect(joinMeta([null, '  ', 'Cauayan City']), 'Cauayan City');
      expect(joinMeta([null, null]), '');
    });
  });
}
