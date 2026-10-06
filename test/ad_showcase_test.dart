// The tap on an ad card goes through one helper so the band and the see-all
// grid cannot drift apart. These pin which destination each ad gets.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trenda_shared/models/ad_model.dart';
import 'package:trenda_frontend/features/home/presentation/ad_showcase_page.dart';

AdModel _ad({List<String> pages = const []}) => AdModel(
      id: 'a1',
      title: 'Aircon cleaning',
      businessName: 'CoolAir',
      ownerId: 'uid',
      showcasePages: pages,
    );

/// Drives [openAd] inside a real router and reports where it landed.
Future<String> _tap(WidgetTester tester, AdModel ad) async {
  var landedOn = '/';

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (inner) => TextButton(
              onPressed: () => openAd(inner, ad),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/ad-details',
        builder: (context, state) {
          landedOn = '/ad-details';
          return const Scaffold(body: Text('details'));
        },
      ),
      GoRoute(
        path: '/ad-showcase',
        builder: (context, state) {
          landedOn = '/ad-showcase';
          return const Scaffold(body: Text('showcase'));
        },
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return landedOn;
}

void main() {
  testWidgets('an ad with showcase pages opens the showcase', (tester) async {
    expect(
      await _tap(tester, _ad(pages: const ['p1.jpg', 'p2.jpg'])),
      '/ad-showcase',
    );
  });

  testWidgets('an ad without pages keeps the ordinary details page',
      (tester) async {
    // Every ad that predates the showcase lands here, which is most of them.
    expect(await _tap(tester, _ad()), '/ad-details');
  });
}
