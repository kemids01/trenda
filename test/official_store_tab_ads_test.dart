// Does the Official Trenda Store tab still work now that Official ads sit at
// the top, in every gap between collections, and at the foot of the shelf?
//
// The slot itself self-fetches over plain http and degrades to
// SizedBox.shrink(), so a test cannot assert an ad is PAINTED — and should not
// try. What it can assert, and what actually changed, is WHERE the slots are:
// one per gap, never after the last carousel, in the right order, capped at the
// ids that exist, and a top/bottom that are there regardless of how many
// collections the admin has created.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_shared/models/ad_placement.dart';
import 'package:trenda_shared/models/product_model.dart';
import 'package:trenda_frontend/features/core/widgets/frontend_official_ad_slot.dart';
import 'package:trenda_frontend/features/home/presentation/trenda_hub_tab.dart';
import 'package:trenda_frontend/features/home/providers/official_collections_provider.dart';
import 'package:trenda_frontend/features/home/providers/official_store_provider.dart';

StoreCollection _collection(String title) => StoreCollection(
      id: title.toLowerCase().replaceAll(' ', '-'),
      title: title,
      type: 'manual',
      // Empty is fine: the carousel is what is under test, not its cards.
      products: const [],
    );

/// A phone-shaped surface — the Hub is a consumer screen.
///
/// Tall on purpose: the tab is a CustomScrollView, so slivers past the viewport
/// are never BUILT and `find` reports them missing when they are merely
/// off-screen. [height] stretches it for the cases that need every carousel at
/// once.
Future<void> _pump(
  WidgetTester tester,
  List<StoreCollection> collections, {
  double height = 2400,
}) async {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        officialStoreCollectionsProvider.overrideWith((ref) async => collections),
        // Nothing else on the tab is under test; keep the catalogue quiet.
        officialStoreProductsProvider
            .overrideWith((ref) async => <ProductModel>[]),
      ],
      child: const MaterialApp(home: TrendaHubTab()),
    ),
  );
  // pump, not pumpAndSettle: the ad slots keep a retry/carousel timer alive, so
  // settling would spin until it times out.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// skipOffstage: false — the top slot is flush (no padding), so an unsold one
/// has zero extent and its sliver counts as offstage, though it is built.
Finder _slot(String id) => find.byWidgetPredicate(
    (w) => w is FrontendOfficialAdSlot && w.slotId == id,
    skipOffstage: false);

/// Only the between-collection slots — the tab also has a top and a bottom.
Finder get _gapSlots => find.byWidgetPredicate((w) =>
    w is FrontendOfficialAdSlot &&
    w.slotId.startsWith('frontend.official_hub.between_collections'));

void main() {
  testWidgets('renders the tab with its collections', (tester) async {
    await _pump(tester, [_collection('Trending Now'), _collection('Flash Sale')]);

    expect(find.text('Trending Now'), findsOneWidget);
    expect(find.text('Flash Sale'), findsOneWidget);
  });

  testWidgets('top and bottom slots are present', (tester) async {
    await _pump(tester, [_collection('Trending Now')]);

    expect(_slot('frontend.official_hub.top'), findsOneWidget);
    expect(_slot('frontend.official_hub.bottom'), findsOneWidget);
  });

  testWidgets('top and bottom are there even with NO collections',
      (tester) async {
    // A brand-new municipality has no collections yet; the shelf is still
    // sellable at its head and foot.
    await _pump(tester, []);

    expect(_slot('frontend.official_hub.top'), findsOneWidget);
    expect(_slot('frontend.official_hub.bottom'), findsOneWidget);
    expect(_gapSlots, findsNothing);
  });

  testWidgets('the top slot really is above the first collection',
      (tester) async {
    await _pump(tester, [_collection('Trending Now')]);

    expect(tester.getRect(_slot('frontend.official_hub.top')).top,
        lessThan(tester.getRect(find.text('Trending Now')).top));
  });

  testWidgets('two collections put ONE ad between them, none after the last',
      (tester) async {
    await _pump(tester, [_collection('Trending Now'), _collection('Flash Sale')]);
    expect(_gapSlots, findsOneWidget);
  });

  testWidgets('the ad really is BETWEEN the two collections', (tester) async {
    await _pump(tester, [_collection('Trending Now'), _collection('Flash Sale')]);

    final first = tester.getRect(find.text('Trending Now')).top;
    final second = tester.getRect(find.text('Flash Sale')).top;
    final slot = tester.getRect(_gapSlots).top;

    expect(slot, greaterThan(first));
    expect(slot, lessThan(second));
  });

  testWidgets('N collections give N-1 gaps', (tester) async {
    await _pump(
        tester, [_collection('One'), _collection('Two'), _collection('Three')]);
    expect(_gapSlots, findsNWidgets(2));
  });

  testWidgets('a single collection gets no gap ad — there is no gap',
      (tester) async {
    await _pump(tester, [_collection('Trending Now')]);
    expect(_gapSlots, findsNothing);
  });

  testWidgets('gaps use the declared ids, in order', (tester) async {
    await _pump(
        tester, [_collection('One'), _collection('Two'), _collection('Three')]);

    final ids = tester
        .widgetList<FrontendOfficialAdSlot>(_gapSlots)
        .map((w) => w.slotId)
        .toList();

    expect(ids, [
      kOfficialHubBetweenCollectionSlotIds[0],
      kOfficialHubBetweenCollectionSlotIds[1],
    ]);
    // Never invented: every id must be a real, sellable slot.
    for (final id in ids) {
      expect(adSlotById(id), isNotNull);
    }
  });

  // Two collections use gap 1. Adding a third must not RENUMBER the first — an
  // admin who sold gap 1 keeps that placement exactly where it was, and the new
  // collection takes the next free gap. Two separate pumps rather than one test
  // that re-pumps: replacing the ProviderScope mid-test does not re-resolve the
  // overridden FutureProvider cleanly.
  testWidgets('two collections fill gap 1', (tester) async {
    await _pump(tester, [_collection('One'), _collection('Two')]);
    expect(_slot(kOfficialHubBetweenCollectionSlotIds[0]), findsOneWidget);
    expect(_slot(kOfficialHubBetweenCollectionSlotIds[1]), findsNothing);
  });

  testWidgets('a newly created third collection takes gap 2, keeping gap 1',
      (tester) async {
    await _pump(
        tester, [_collection('One'), _collection('Two'), _collection('Three')]);
    expect(_slot(kOfficialHubBetweenCollectionSlotIds[0]), findsOneWidget);
    expect(_slot(kOfficialHubBetweenCollectionSlotIds[1]), findsOneWidget);
  });

  testWidgets('more collections than slots is capped, not crashed',
      (tester) async {
    // 9 collections = 8 gaps, but only 6 ids exist. The extra gaps close up.
    await _pump(
      tester,
      [for (var i = 1; i <= 9; i++) _collection('Collection $i')],
      height: 9000, // tall enough that every carousel is built
    );

    expect(_gapSlots,
        findsNWidgets(kOfficialHubBetweenCollectionSlotIds.length));
  });
}
