// The Vendor Ads / Services lists draw each ad's main image full-bleed. The
// cards are locked to 6:5 (kAdListingImageAspect) so a 1200×1000 upload shows
// whole on every phone — they used to be a fixed 300px tall (1.09–1.27:1).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/ads/providers/ads_provider.dart';
import 'package:trenda_frontend/features/home/presentation/ads_tab.dart';
import 'package:trenda_shared/models/ad_model.dart';
import 'package:trenda_shared/models/ad_placement.dart';

AdModel _ad(String id, {bool featured = false}) => AdModel.fromJson({
      '_id': id.padLeft(24, '0'),
      'id': id.padLeft(24, '0'),
      'title': 'Ad $id',
      'businessName': 'Biz $id',
      'photos': ['https://img/$id.jpg'],
      'featured': featured,
      'status': 'active',
    });

class _Fake extends PaginatedAdsNotifier {
  @override
  Future<PaginatedAdsState> build(String kind) async => PaginatedAdsState(
        ads: [_ad('1', featured: true), _ad('2'), _ad('3')],
        totalAds: 3,
      );
}

void main() {
  for (final width in const [360.0, 390.0, 412.0]) {
    testWidgets('cards are 6:5 on a ${width.toInt()}dp phone', (tester) async {
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [paginatedAdsProvider.overrideWith(_Fake.new)],
        child: const MaterialApp(home: Scaffold(body: AdsTab())),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final images = find.byType(Image);
      expect(images, findsWidgets);
      for (final e in images.evaluate()) {
        final size = (e.renderObject! as RenderBox).size;
        if (size.width < 100) continue; // logos / icons
        expect(size.width / size.height, closeTo(kAdListingImageAspect, 0.02),
            reason: '${size.width}x${size.height}');
      }
      expect(tester.takeException(), isNull);
    });
  }
}
