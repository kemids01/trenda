// Does the Shop tab still work now that an Official ad sits between the bands?
//
// The slot itself self-fetches over plain http and degrades to
// SizedBox.shrink(), so a test cannot assert an ad is PAINTED — and should not
// try. What it can assert, and what actually changed, is WHERE the slots are:
// one per gap, never after the last band, in the right order, and capped at the
// ids that exist.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_shared/models/ad_model.dart';
import 'package:trenda_shared/models/ad_placement.dart';
import 'package:trenda_shared/models/product_model.dart';
import 'package:trenda_frontend/features/ads/providers/ads_provider.dart';
import 'package:trenda_frontend/features/core/widgets/frontend_official_ad_slot.dart';
import 'package:trenda_frontend/features/home/presentation/shop_tab.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/shop_feature_band.dart';
import 'package:trenda_frontend/features/home/providers/ads_section_provider.dart';
import 'package:trenda_frontend/features/home/providers/shop_sections_provider.dart';
import 'package:trenda_frontend/features/products/providers/products_provider.dart';

ShopSection _band(String title) => ShopSection(
      id: title.toLowerCase().replaceAll(' ', '-'),
      title: title,
      products: const [],
      // Non-empty so the band is renderable; the tab does not filter here.
      stores: const [],
      contentType: 'products',
    );

/// A phone-shaped surface — the Shop tab is a consumer screen.
///
/// Tall on purpose: the tab is a CustomScrollView, so slivers past the viewport
/// are never BUILT and `find` reports them missing when they are merely
/// off-screen. [height] stretches it for the cases that need every band at once.
const Size _kPhone = Size(390, 1600);

Future<void> _pump(
  WidgetTester tester,
  List<ShopSection> sections, {
  double height = 1600,
}) async {
  tester.view.physicalSize = Size(_kPhone.width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shopSectionsProvider.overrideWith((ref) async => sections),
        // Nothing else on the tab is under test; keep them quiet and empty.
        adsSectionProvider.overrideWith((ref) async => null),
        publicProductsProvider.overrideWith((ref) async => <ProductModel>[]),
        adsListProvider.overrideWith((ref) async => <AdModel>[]),
      ],
      child: const MaterialApp(home: ShopTab()),
    ),
  );
  // pump, not pumpAndSettle: the ad slots keep a retry/carousel timer alive, so
  // settling would spin until it times out.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Only the between-band slots — the tab also has a hero slot at the top.
Finder get _gapSlots => find.byWidgetPredicate((w) =>
    w is FrontendOfficialAdSlot &&
    w.slotId.startsWith('frontend.shop.between_sections'));

void main() {
  testWidgets('renders the tab with its bands', (tester) async {
    await _pump(tester, [_band('Daily Basics'), _band('Stores of the Week')]);

    expect(find.text('Daily Basics'), findsOneWidget);
    expect(find.text('Stores of the Week'), findsOneWidget);
    expect(find.byType(ShopFeatureBand), findsNWidgets(2));
  });

  testWidgets('two bands put ONE ad between them, none after the last',
      (tester) async {
    // The example asked for: Daily Basics ▸ ad ▸ Stores of the Week.
    await _pump(tester, [_band('Daily Basics'), _band('Stores of the Week')]);
    expect(_gapSlots, findsOneWidget);
  });

  testWidgets('the ad really is BETWEEN the two bands', (tester) async {
    await _pump(tester, [_band('Daily Basics'), _band('Stores of the Week')]);

    final first = tester.getRect(find.text('Daily Basics')).top;
    final second = tester.getRect(find.text('Stores of the Week')).top;
    final slot = tester.getRect(_gapSlots).top;

    expect(slot, greaterThan(first));
    expect(slot, lessThan(second));
  });

  testWidgets('N bands give N-1 gaps', (tester) async {
    await _pump(tester, [_band('One'), _band('Two'), _band('Three')]);
    expect(_gapSlots, findsNWidgets(2));
  });

  testWidgets('a single band gets no ad — there is no gap', (tester) async {
    await _pump(tester, [_band('Daily Basics')]);
    expect(find.byType(ShopFeatureBand), findsOneWidget);
    expect(_gapSlots, findsNothing);
  });

  testWidgets('no bands at all still renders the tab', (tester) async {
    await _pump(tester, []);
    expect(_gapSlots, findsNothing);
    // The rest of the tab is unaffected — the quick lanes are still there.
    expect(find.text('All items'), findsOneWidget);
  });

  testWidgets('the fourth lane is Palengke, not Ads', (tester) async {
    await _pump(tester, []);
    expect(find.text('Palengke'), findsOneWidget);
    expect(find.text('Ads'), findsNothing);
  });

  testWidgets('gaps use the declared ids, in order', (tester) async {
    await _pump(tester, [_band('One'), _band('Two'), _band('Three')]);

    final ids = tester
        .widgetList<FrontendOfficialAdSlot>(_gapSlots)
        .map((w) => w.slotId)
        .toList();

    expect(ids, [
      kShopBetweenSectionSlotIds[0],
      kShopBetweenSectionSlotIds[1],
    ]);
    // Never invented: every id must be a real, sellable slot.
    for (final id in ids) {
      expect(adSlotById(id), isNotNull);
    }
  });

  testWidgets('more bands than slots is capped, not crashed', (tester) async {
    // 8 bands = 7 gaps, but only 5 ids exist. The extra gaps simply close up.
    await _pump(
      tester,
      [for (var i = 1; i <= 8; i++) _band('Band $i')],
      height: 7000, // tall enough that every band is built, not just the first few
    );

    expect(find.byType(ShopFeatureBand), findsNWidgets(8));
    expect(_gapSlots, findsNWidgets(kShopBetweenSectionSlotIds.length));
  });
}
