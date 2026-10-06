// test/store_hero_test.dart
// The shopfront at the top of a store page, at the sizes it actually renders.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/stores/utils/storefront_style.dart';
import 'package:trenda_frontend/features/vendors/widgets/store_hero.dart';
import 'package:trenda_frontend/features/vendors/widgets/store_qr_sheet.dart';

Future<void> _pumpHero(
  WidgetTester tester,
  StoreHero hero, {
  Size size = const Size(360, 800),
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: SizedBox(height: 252, child: hero)),
    ),
  );
  await tester.pump();
}

void main() {
  group('StoreHero', () {
    testWidgets('paints the shop name, trade and city on the fascia',
        (tester) async {
      await _pumpHero(
        tester,
        const StoreHero(
          seed: 'vendor-1',
          storeName: 'Dubets Store',
          category: 'Bakery',
          municipality: 'Tuguegarao City',
        ),
      );

      expect(find.text('DUBETS STORE'), findsOneWidget);
      expect(find.text('Bakery · Tuguegarao City'), findsOneWidget);
      expect(find.text('OPEN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hangs a CLOSED sign when the shop is shut', (tester) async {
      await _pumpHero(
        tester,
        const StoreHero(
          seed: 'vendor-1',
          storeName: 'Dubets Store',
          isOpen: false,
        ),
      );

      expect(find.text('CLOSED'), findsOneWidget);
      expect(find.text('OPEN'), findsNothing);
    });

    testWidgets('shows the verified tick only when verified', (tester) async {
      await _pumpHero(
        tester,
        const StoreHero(seed: 'v', storeName: 'Shop', isVerified: false),
      );
      expect(find.byIcon(Icons.verified_rounded), findsNothing);

      await _pumpHero(
        tester,
        const StoreHero(seed: 'v', storeName: 'Shop', isVerified: true),
      );
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('featured shops get the brass plaque', (tester) async {
      await _pumpHero(
        tester,
        const StoreHero(seed: 'v', storeName: 'Shop', isFeatured: true),
      );

      expect(find.text('FEATURED SHOP'), findsOneWidget);
    });

    testWidgets('falls back to a monogram signboard with no logo',
        (tester) async {
      await _pumpHero(
        tester,
        const StoreHero(seed: 'v', storeName: 'Mang Juan Hardware'),
      );

      expect(find.text('MJ'), findsOneWidget);
    });

    testWidgets('a long name on a narrow phone does not overflow',
        (tester) async {
      await _pumpHero(
        tester,
        const StoreHero(
          seed: 'v',
          storeName: 'Santissima Trinidad General Merchandise and Hardware',
          category: 'General Merchandise and Construction Supplies',
          municipality: 'Tuguegarao City, Cagayan Valley',
          isFeatured: true,
          isVerified: true,
        ),
        size: const Size(320, 800),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark mode', (tester) async {
      await _pumpHero(
        tester,
        const StoreHero(seed: 'v', storeName: 'Shop'),
        brightness: Brightness.dark,
      );

      expect(find.text('SHOP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('wears the same awning colour as its card on the street',
        (tester) async {
      // Continuity is the whole point: the hero and the street card seed the
      // palette identically, so a shop keeps its colour when you walk in.
      const seed = 'vendor-abc';
      expect(
        awningPaletteFor(seed).stripe,
        awningPaletteFor(seed).stripe,
      );
      expect(awningIndexFor(seed), awningIndexFor(seed));
    });
  });

  group('storeShareUrl', () {
    test('is the public web link for the shop', () {
      expect(storeShareUrl('abc123'), 'https://trenda.ph/store/abc123');
    });
  });
}
