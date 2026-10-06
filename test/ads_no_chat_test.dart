// Ads carry no chat button — removed 2026-10-04 from the Vendor Ads / Services
// cards (an icon nothing ever wired up) and the ad details page's action bar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/ads/providers/ads_provider.dart';
import 'package:trenda_frontend/features/home/presentation/ad_details_page.dart';
import 'package:trenda_frontend/features/home/presentation/ads_tab.dart';
import 'package:trenda_shared/models/ad_model.dart';

final _ad = AdModel.fromJson({
  '_id': '1'.padLeft(24, '0'),
  'id': '1'.padLeft(24, '0'),
  'owner': 'vendor-uid',
  'title': 'Big sale',
  'businessName': 'Biz',
  'contact': '0917 000 0000',
  'photos': ['https://img/1.jpg'],
  'status': 'active',
});

class _Fake extends PaginatedAdsNotifier {
  @override
  Future<PaginatedAdsState> build(String kind) async =>
      PaginatedAdsState(ads: [_ad], totalAds: 1);
}

bool _isChatIcon(Widget w) =>
    w is Icon && (w.icon == Icons.chat || w.icon == Icons.chat_outlined);

void main() {
  testWidgets('ad list card shows the contact but no chat button',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [paginatedAdsProvider.overrideWith(_Fake.new)],
      child: const MaterialApp(home: Scaffold(body: AdsTab())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('0917 000 0000'), findsOneWidget);
    expect(find.byWidgetPredicate(_isChatIcon), findsNothing);
  });

  testWidgets('ad details page has no Chat button', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: AdDetailsPage(ad: _ad)),
    ));
    await tester.pump();
    expect(find.text('Chat'), findsNothing);
    expect(find.byWidgetPredicate(_isChatIcon), findsNothing);
    expect(find.text('Visit Store'), findsOneWidget);
  });
}
