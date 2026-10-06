// test/product_page_widgets_test.dart
// The gallery and the seller chip on the product page.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/products/presentation/widgets/product_gallery.dart';
import 'package:trenda_frontend/features/products/presentation/widgets/seller_chip.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(360, 800),
  Brightness brightness = Brightness.light,
  double height = 300,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: SizedBox(height: height, child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  group('ProductGallery', () {
    testWidgets('a product with no photos shows a painted plate, not a remote '
        'placeholder', (tester) async {
      await _pump(
        tester,
        const ProductGallery(images: [], accent: Colors.teal, heroTag: 'p1'),
      );

      expect(find.text('No photo yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('blank image urls count as no photos', (tester) async {
      await _pump(
        tester,
        const ProductGallery(
          images: ['', '   '],
          accent: Colors.teal,
          heroTag: 'p1',
        ),
      );

      expect(find.text('No photo yet'), findsOneWidget);
    });

    testWidgets('a single photo offers zoom but no counter', (tester) async {
      await _pump(
        tester,
        const ProductGallery(
          images: ['https://cdn.test/a.jpg'],
          accent: Colors.teal,
          heroTag: 'p1',
        ),
      );

      expect(find.text('Tap to zoom'), findsOneWidget);
      expect(find.textContaining('/'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('several photos show a counter that tracks the page',
        (tester) async {
      await _pump(
        tester,
        const ProductGallery(
          images: [
            'https://cdn.test/a.jpg',
            'https://cdn.test/b.jpg',
            'https://cdn.test/c.jpg',
          ],
          accent: Colors.teal,
          heroTag: 'p1',
        ),
      );

      expect(find.text('1 / 3'), findsOneWidget);

      await tester.drag(find.byType(PageView).first, const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the filmstrip caps at five thumbnails', (tester) async {
      await _pump(
        tester,
        ProductGallery(
          images: List.generate(9, (i) => 'https://cdn.test/$i.jpg'),
          accent: Colors.teal,
          heroTag: 'p1',
        ),
      );

      expect(find.text('1 / 9'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a photo opens the full-screen viewer', (tester) async {
      await _pump(
        tester,
        const ProductGallery(
          images: ['https://cdn.test/a.jpg'],
          accent: Colors.teal,
          heroTag: 'p1',
        ),
      );

      await tester.tap(find.byType(PageView).first);
      // The viewer shows a loading spinner while the photo fetches, so it never
      // goes idle — pump fixed frames rather than pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(InteractiveViewer), findsNothing);
    });

    testWidgets('renders in dark mode', (tester) async {
      await _pump(
        tester,
        const ProductGallery(images: [], accent: Colors.teal, heroTag: 'p1'),
        brightness: Brightness.dark,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('SellerChip', () {
    testWidgets('an ordinary vendor is labelled a local vendor', (tester) async {
      await _pump(
        tester,
        SellerChip(
          seed: 'vendor-1',
          storeName: 'Dubets Store',
          onVisit: () {},
        ),
        height: 140,
      );

      expect(find.text('SOLD BY'), findsOneWidget);
      expect(find.text('Dubets Store'), findsOneWidget);
      expect(find.text('Local vendor'), findsOneWidget);
      expect(find.text('Official Store'), findsNothing);
      expect(find.text('DS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an official product says Official Trenda Store',
        (tester) async {
      await _pump(
        tester,
        SellerChip(
          seed: 'official',
          storeName: 'Official Trenda',
          isOfficial: true,
          onVisit: () {},
        ),
        height: 140,
      );

      expect(find.text('Official Trenda Store'), findsOneWidget);
    });

    testWidgets('a resold listing credits the original shop', (tester) async {
      await _pump(
        tester,
        SellerChip(
          seed: 'vendor-2',
          storeName: 'Reseller Shop',
          isResale: true,
          originalVendorStoreName: 'Aling Nena Bakery',
          onVisit: () {},
        ),
        height: 180,
      );

      expect(find.text('Reseller'), findsOneWidget);
      expect(find.textContaining('Originally from'), findsOneWidget);
      expect(find.textContaining('Aling Nena Bakery'), findsOneWidget);
    });

    testWidgets('no credit row when the maker is unknown', (tester) async {
      await _pump(
        tester,
        SellerChip(
          seed: 'vendor-2',
          storeName: 'Reseller Shop',
          isResale: true,
          originalVendorStoreName: '  ',
          onVisit: () {},
        ),
        height: 140,
      );

      expect(find.textContaining('Originally from'), findsNothing);
    });

    testWidgets('Visit and Chat both fire', (tester) async {
      var visits = 0;
      var chats = 0;
      await _pump(
        tester,
        SellerChip(
          seed: 'vendor-1',
          storeName: 'Dubets Store',
          onVisit: () => visits++,
          onChat: () => chats++,
        ),
        height: 140,
      );

      await tester.tap(find.text('Visit'));
      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pump();

      expect(visits, 1);
      expect(chats, 1);
    });

    testWidgets('chat is hidden when no handler is given', (tester) async {
      await _pump(
        tester,
        SellerChip(seed: 'v', storeName: 'Shop', onVisit: () {}),
        height: 140,
      );

      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
    });

    testWidgets('a long shop name on a narrow phone does not overflow',
        (tester) async {
      await _pump(
        tester,
        SellerChip(
          seed: 'v',
          storeName: 'Santissima Trinidad General Merchandise and Hardware',
          isResale: true,
          originalVendorStoreName:
              'Aling Nena Bakery and General Merchandise Incorporated',
          onVisit: () {},
          onChat: () {},
        ),
        size: const Size(320, 800),
        height: 180,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark mode', (tester) async {
      await _pump(
        tester,
        SellerChip(seed: 'v', storeName: 'Shop', onVisit: () {}),
        brightness: Brightness.dark,
        height: 140,
      );

      expect(find.text('Shop'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
