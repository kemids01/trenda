// ⚡ Flash Sale band: display rules, feed parsing (incl. clock skew) and the band itself.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/presentation/widgets/flash_sale_band.dart';
import 'package:trenda_frontend/features/home/providers/flash_sale_provider.dart';
import 'package:trenda_frontend/features/home/utils/flash_sale_logic.dart';

Map<String, dynamic> _payload({required DateTime server, required DateTime ends}) => {
      'serverTime': server.toUtc().toIso8601String(),
      'sales': [
        {
          'id': 's1',
          'title': 'Payday Flash Sale',
          'theme': {'from': '#0B3D91', 'to': '#1E88E5', 'accent': '#FFE600'},
          'startsAt': server.subtract(const Duration(hours: 1)).toUtc().toIso8601String(),
          'endsAt': ends.toUtc().toIso8601String(),
          'items': [
            {
              'itemId': 'i1', 'productId': 'p1', 'name': 'Bibingka Box', 'regularPrice': 250, 'flashPrice': 149,
              'discountPercent': 40, 'flashStock': 40, 'soldCount': 34, 'stockLeft': 6, 'soldPercent': 85,
              'seller': "Aling Nena's Kakanin", 'sellerArea': 'Centro 7 (Pob.), Tuguegarao City',
            },
            {
              'itemId': 'i2', 'productId': 'p2', 'name': 'Earbuds', 'regularPrice': 899, 'flashPrice': 599,
              'discountPercent': 33, 'flashStock': 15, 'soldCount': 15, 'stockLeft': 0, 'soldPercent': 100,
              'isOfficial': true,
            },
          ],
        },
      ],
      'upcoming': null,
    };

void main() {
  group('display rules', () {
    test('countdown: days tile past 24h, zero when over', () {
      final now = DateTime(2026, 10, 2, 12);
      final p = countdownParts(now.add(const Duration(days: 6, hours: 23, minutes: 5, seconds: 9)), now);
      expect((p.days, p.hh, p.mm, p.ss, p.done), (6, '23', '05', '09', false));
      expect(countdownParts(now.subtract(const Duration(seconds: 1)), now).done, isTrue);
    });

    test('sold label states only what was counted', () {
      expect(soldLabel(soldPercent: 0, stockLeft: 40, soldCount: 0), 'Just started');
      expect(soldLabel(soldPercent: 10, stockLeft: 36, soldCount: 4), '4 sold');
      expect(soldLabel(soldPercent: 55, stockLeft: 18, soldCount: 22), '🔥 55% sold');
      expect(soldLabel(soldPercent: 85, stockLeft: 6, soldCount: 34), 'Almost gone!');
      expect(soldLabel(soldPercent: 90, stockLeft: 2, soldCount: 18), 'Only 2 left!');
      expect(soldLabel(soldPercent: 100, stockLeft: 0, soldCount: 15), 'Sold out');
    });

    test('peso formatting', () {
      expect(flashPeso(1290), '₱1,290');
      expect(flashPeso(47.5), '₱47.50');
    });
  });

  group('feed', () {
    test('ends are shifted by the device clock skew', () {
      final server = DateTime.utc(2026, 10, 2, 9);
      final ends = server.add(const Duration(hours: 2));
      // Device clock runs 3 minutes FAST.
      final received = server.add(const Duration(minutes: 3));
      final feed = FlashSaleFeed.fromJson(_payload(server: server, ends: ends), receivedAt: received);
      expect(feed.featured!.endsAt.toUtc(), ends.add(const Duration(minutes: 3)));
    });

    test('dealFor finds a product; unknown → null', () {
      final s = DateTime.now().toUtc();
      final feed = FlashSaleFeed.fromJson(_payload(server: s, ends: s.add(const Duration(hours: 1))), receivedAt: s);
      expect(feed.dealFor('p1')!.item.flashPrice, 149);
      expect(feed.dealFor('nope'), isNull);
      expect(feed.allItems, hasLength(2));
    });
  });

  testWidgets('the band shows the wordmark, deals, sold states and See all', (tester) async {
    final s = DateTime.now().toUtc();
    final feed = FlashSaleFeed.fromJson(_payload(server: s, ends: s.add(const Duration(hours: 5))), receivedAt: s);
    await tester.pumpWidget(ProviderScope(
      overrides: [flashSaleFeedProvider.overrideWith((ref) async => feed)],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: FlashSaleBand()))),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('FLASH'), findsWidgets);
    expect(find.text('Bibingka Box'), findsOneWidget);
    expect(find.text('₱149'), findsOneWidget);
    expect(find.text('−40%'), findsOneWidget);
    expect(find.text('Almost gone!'), findsOneWidget);
    expect(find.text('SOLD OUT'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    // Let the repeating animations stop cleanly.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nothing live and nothing coming → the band builds nothing', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [flashSaleFeedProvider.overrideWith((ref) async => const FlashSaleFeed())],
      child: const MaterialApp(home: Scaffold(body: FlashSaleBand())),
    ));
    await tester.pump();
    expect(find.textContaining('FLASH'), findsNothing);
  });

  group('band colours', () {
    test('palette parses the campaign theme; bad or missing keys keep the default', () {
      final p = FlashPalette.fromJson({'from': '#0B3D91', 'to': 'nope'});
      expect(p.from, const Color(0xFF0B3D91));
      expect(p.to, FlashPalette.fallback.to);
      expect(p.accent, FlashPalette.fallback.accent);
      expect(FlashPalette.fromJson(null).from, FlashPalette.fallback.from);
    });
    test('text turns dark on a light band; a pale start colour never becomes the price colour', () {
      const light = FlashPalette(from: Color(0xFFFFF3B0), to: Color(0xFFFFFFFF), accent: Color(0xFF000000));
      expect(light.ink, const Color(0xFF1A0500));
      expect(light.price, const Color(0xFFE5170B));
      expect(FlashPalette.fallback.ink, const Color(0xFFFFFFFF));
    });
  });

  testWidgets('the band paints the campaign colours', (tester) async {
    final s = DateTime.now().toUtc();
    final feed = FlashSaleFeed.fromJson(_payload(server: s, ends: s.add(const Duration(hours: 5))), receivedAt: s);
    await tester.pumpWidget(ProviderScope(
      overrides: [flashSaleFeedProvider.overrideWith((ref) async => feed)],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: FlashSaleBand()))),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final gradients = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.gradient)
        .whereType<LinearGradient>();
    expect(gradients.any((g) => g.colors.first == const Color(0xFF0B3D91)), isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
