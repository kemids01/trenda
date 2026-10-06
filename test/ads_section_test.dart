// Pins the Ads & Services payload parsing. A paid slot that fails to parse is a
// gap the advertiser paid for, so every shape the backend can send — including
// the malformed ones — has to land somewhere renderable.
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/providers/ads_section_provider.dart';

Map<String, dynamic> _ad(String id, String title) => {
      '_id': id,
      'id': id,
      'title': title,
      'businessName': 'Biz $id',
      'photos': <String>[],
      'status': 'active',
    };

void main() {
  group('AdsSection.fromJson', () {
    test('reads config, featured and the slots in server order', () {
      final section = AdsSection.fromJson({
        'config': {
          'title': 'Ads & Services',
          'vendorLabel': 'Top 10 Vendor Ads',
          'servicesLabel': 'Top 10 Services',
          'backgroundColor': '#EEF2FF',
          'accentColor': '#2563EB',
        },
        'vendor': {
          'featured': _ad('f1', 'Featured vendor'),
          'top10': [
            {'position': 1, 'ad': _ad('a', 'Vendor A')},
            {'position': 3, 'ad': _ad('b', 'Vendor B')},
          ],
        },
        'services': {'featured': null, 'top10': []},
      });

      expect(section.title, 'Ads & Services');
      expect(section.backgroundColor, '#EEF2FF');
      expect(section.accentColor, '#2563EB');
      expect(section.vendor.featured?.title, 'Featured vendor');
      expect(section.vendor.top10.map((a) => a.title), ['Vendor A', 'Vendor B']);
      expect(section.services.isEmpty, isTrue);
      expect(section.isEmpty, isFalse);
    });

    test('falls back to default labels when config is absent', () {
      final section = AdsSection.fromJson({
        'vendor': {'top10': [_slot(1, 'a', 'A')]},
        'services': {'top10': []},
      });
      expect(section.title, 'Ads & Services');
      expect(section.vendorLabel, 'Top 10 Vendor Ads');
      expect(section.servicesLabel, 'Top 10 Services');
    });

    test('blank and absent colours both parse as null', () {
      // A blank string reaching the colour parser would paint the band black.
      final section = AdsSection.fromJson({
        'config': {'backgroundColor': '', 'accentColor': '   '},
        'vendor': {'top10': []},
        'services': {'top10': []},
      });
      expect(section.backgroundColor, isNull);
      expect(section.accentColor, isNull);
    });

    test('a carousel with only a featured ad is not empty', () {
      final section = AdsSection.fromJson({
        'vendor': {'featured': _ad('f', 'Only featured'), 'top10': []},
        'services': {'top10': []},
      });
      expect(section.vendor.isEmpty, isFalse);
      expect(section.isEmpty, isFalse);
    });

    test('a malformed payload still yields a renderable, empty section', () {
      final section = AdsSection.fromJson({'vendor': 'nope', 'services': null});
      expect(section.vendor.isEmpty, isTrue);
      expect(section.services.isEmpty, isTrue);
      expect(section.isEmpty, isTrue);
      expect(section.title, 'Ads & Services');
    });

    test('skips slot entries whose ad is missing rather than throwing', () {
      final section = AdsSection.fromJson({
        'vendor': {
          'top10': [
            {'position': 1, 'ad': null},
            {'position': 2, 'ad': _ad('b', 'Survivor')},
          ],
        },
        'services': {'top10': []},
      });
      expect(section.vendor.top10.map((a) => a.title), ['Survivor']);
    });
  });
}

Map<String, dynamic> _slot(int position, String id, String title) =>
    {'position': position, 'ad': _ad(id, title)};
