import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/presentation/ads_section_page.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/ads_section_band.dart';
import 'package:trenda_frontend/features/home/providers/ads_section_provider.dart';

Map<String, dynamic> ad(String id, String business, {String kind = 'vendor'}) => {
      '_id': id,
      'title': '$business deal',
      'businessName': business,
      'kind': kind,
      'photos': <String>[],
    };

AdsSection section({bool withServices = true}) => AdsSection.fromJson({
      'config': {'title': 'Ads & Services'},
      'vendor': {
        'featured': ad('f', 'Dubets Store'),
        'top10': [
          {'slot': 1, 'ad': ad('a', 'Ana Bakery')},
          {'slot': 2, 'ad': ad('b', 'Ben Hardware')},
        ],
      },
      'services': withServices
          ? {
              'top10': [
                {'slot': 1, 'ad': ad('s', 'Quick Laundry', kind: 'service')},
              ],
            }
          : <String, dynamic>{},
    });

void main() {
  group('See-all card shape and image', () {
    AdsSection one(Map<String, dynamic> a) => AdsSection.fromJson({
          'config': {'title': 'Ads & Services'},
          'vendor': {
            'top10': [
              {'slot': 1, 'ad': a},
            ],
          },
          'services': <String, dynamic>{},
        });

    Finder card() => find.ancestor(
          of: find.text('#1'),
          matching: find.byType(AspectRatio),
        );

    // Small 16:9 phone, common iPhone, large Android.
    for (final size in const [
      Size(360, 640),
      Size(390, 844),
      Size(430, 932),
    ]) {
      testWidgets('the card is 9:16 on a ${size.width}x${size.height} phone',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          home: AdsSectionPage(
              section: one(ad('a', 'Ana Bakery')), kind: AdsKind.vendor),
        ));
        final s = tester.getSize(card().first);
        expect(s.width / s.height, closeTo(kAdsSeeAllCardAspect, 0.01));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a See-all image is shown as-is: only the slot badge on it',
        (tester) async {
      final a = ad('a', 'Ana Bakery')
        ..['seeAllImage'] = 'https://img/tall.jpg'
        ..['photos'] = <String>['https://img/card.jpg'];
      await tester.pumpWidget(MaterialApp(
        home: AdsSectionPage(section: one(a), kind: AdsKind.vendor),
      ));
      expect(find.text('#1'), findsOneWidget);
      // The artwork carries its own text — nothing is drawn over it.
      expect(find.text('Ana Bakery'), findsNothing);
      expect(find.text('View'), findsNothing);
      final img = tester.widget(find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'CachedNetworkImage')) as dynamic;
      expect(img.imageUrl, 'https://img/tall.jpg');
    });

    testWidgets('without one, the card photo and the text overlay stay',
        (tester) async {
      final a = ad('a', 'Ana Bakery')
        ..['photos'] = <String>['https://img/card.jpg'];
      await tester.pumpWidget(MaterialApp(
        home: AdsSectionPage(section: one(a), kind: AdsKind.vendor),
      ));
      expect(find.text('Ana Bakery'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      final img = tester.widget(find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'CachedNetworkImage')) as dynamic;
      expect(img.imageUrl, 'https://img/card.jpg');
    });
  });

  testWidgets('See all page shows ONE kind as a big carousel with a pager',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AdsSectionPage(section: section(), kind: AdsKind.vendor),
    ));

    expect(find.text('Top 10 Vendor Ads'), findsOneWidget);
    expect(find.text('FEATURED'), findsOneWidget);
    expect(find.text('Dubets Store'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    // Services never leak onto the vendor page.
    expect(find.text('Quick Laundry'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
  });

  testWidgets('services page ranks from #1 when there is no featured ad',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AdsSectionPage(section: section(), kind: AdsKind.services),
    ));
    expect(find.text('Top 10 Services'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
  });

  testWidgets('band has a See all per column, only where there are ads',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdsSectionBand(section: section(withServices: false)),
        ),
      ),
    ));
    expect(find.text('See all'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
  });
}
