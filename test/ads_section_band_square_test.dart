// The Ads & Services band (Shop tab, before "See all") draws every card's
// picture exactly SQUARE, from Ad.carouselImage when the ad has one — an
// Official ad's photos[0] is a 3:1 slot banner and used to be cropped to its
// middle third here.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/ads_section_band.dart';
import 'package:trenda_frontend/features/home/providers/ads_section_provider.dart';

Map<String, dynamic> _ad(String id, {String? square}) => {
      '_id': id,
      'id': id,
      'title': 'Title $id',
      'businessName': 'Biz $id',
      'photos': ['https://img/$id-banner.jpg'],
      if (square != null) 'carouselImage': square,
      'status': 'active',
    };

Future<void> _pump(WidgetTester tester, Map<String, dynamic> json) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: AdsSectionBand(section: AdsSection.fromJson(json)))),
  ));
  await tester.pump();
}

void main() {
  testWidgets('the card uses the square image when set, else the first photo',
      (tester) async {
    await _pump(tester, {
      'vendor': {'featured': _ad('f', square: 'https://img/f-square.jpg'), 'top10': []},
      'services': {'top10': [{'position': 1, 'ad': _ad('s')}]},
    });
    final urls = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .map((i) => i.imageUrl)
        .toSet();
    expect(urls, containsAll(['https://img/f-square.jpg', 'https://img/s-banner.jpg']));
    expect(urls, isNot(contains('https://img/f-banner.jpg')));
  });

  testWidgets('every card picture is exactly square — Featured included',
      (tester) async {
    await _pump(tester, {
      'vendor': {'featured': _ad('f', square: 'https://img/f-square.jpg'), 'top10': []},
      'services': {'top10': [{'position': 1, 'ad': _ad('s', square: 'https://img/s-square.jpg')}]},
    });
    final images = find.byType(CachedNetworkImage);
    expect(images, findsNWidgets(2));
    for (final e in images.evaluate()) {
      final size = (e.renderObject! as RenderBox).size;
      expect(size.width, closeTo(size.height, 0.5));
    }
    // The Featured card's extra height carries its title line instead.
    expect(find.text('Title f'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
