// test/vendor_store_screen_test.dart
// The store page lays out cleanly: the pinned tab header once threw
// "layoutExtent exceeds paintExtent" when its height went fractional.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/vendors/providers/vendor_follow_provider.dart';
import 'package:trenda_frontend/features/vendors/screens/vendor_store_screen.dart';
import 'package:trenda_frontend/features/vendors/services/vendor_follow_service.dart';

class _FakeFollow implements VendorFollowService {
  @override
  Future<bool> isFollowing(String vendorId) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(false);
}

void main() {
  testWidgets('store page renders with Find the shop under Follow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final profile = VendorProfile(
      id: 'v1',
      storeName: 'Dubets Store',
      storeDescription: 'Fresh bread every morning.',
      rating: 4.6,
      reviewCount: 12,
      productCount: 8,
      followerCount: 30,
      municipality: 'Tuguegarao City',
      address: 'Rizal St, Centro 10',
      phone: '09171234567',
      email: 'shop@example.com',
      category: 'Bakery',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        vendorProfileProvider('v1').overrideWith((ref) async => profile),
        vendorProductsProvider('v1').overrideWith((ref) async => const []),
        vendorFollowServiceProvider.overrideWithValue(_FakeFollow()),
      ],
      child: const MaterialApp(home: VendorStoreScreen(vendorId: 'v1')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    expect(find.text('Follow shop'), findsOneWidget);
    expect(find.text('FIND THE SHOP'), findsOneWidget);
    expect(find.text('Rizal St, Centro 10, Tuguegarao City'), findsOneWidget);

    // Follow sits above Find the shop.
    final follow = tester.getTopLeft(find.text('Follow shop')).dy;
    final find_ = tester.getTopLeft(find.text('FIND THE SHOP')).dy;
    expect(follow, lessThan(find_));

    // Scroll the tab header to its pinned position — where it used to throw.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
