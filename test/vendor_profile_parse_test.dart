// test/vendor_profile_parse_test.dart
// VendorProfile.fromJson against the real /api/stores/:vendorId payload.
// The repository used to hand-roll this parse and dropped most of it.

import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/vendors/providers/vendor_follow_provider.dart';
import 'package:trenda_frontend/features/vendors/utils/store_hours.dart';

/// Shaped exactly like publicStoresController.getStoreDetails' `store` object.
Map<String, dynamic> storePayload({
  bool isOpen = true,
  Object? verified,
  Object? nextOpenTime,
}) =>
    {
      'id': 'vendor-firebase-uid',
      'name': 'Dubets Store',
      'description': 'Fresh pandesal every morning',
      'logo': 'https://cdn.test/logo.png',
      'coverImage': 'https://cdn.test/banner.jpg',
      'bannerUrl': 'https://cdn.test/banner.jpg',
      'category': 'Bakery',
      'rating': 4.6,
      'reviewCount': 23,
      'productCount': 14,
      'isFeatured': true,
      'municipality': 'Tuguegarao City',
      'address': '12 Rizal St, Centro',
      'phone': '09171234567',
      'email': 'shop@dubets.ph',
      if (verified != null) 'verified': verified,
      'storeStatus': {
        'isOpen': isOpen,
        'canOrder': isOpen,
        'nextOpenTime': nextOpenTime,
      },
      'storeHours': {
        'monday': {'open': '08:00', 'close': '17:00', 'isOpen': true},
        'sunday': null,
      },
      'operatingHours': null,
    };

void main() {
  group('VendorProfile.fromJson (store details payload)', () {
    test('keeps the shop details the page needs', () {
      final p = VendorProfile.fromJson(storePayload());

      expect(p.id, 'vendor-firebase-uid');
      expect(p.storeName, 'Dubets Store');
      expect(p.storeDescription, 'Fresh pandesal every morning');
      expect(p.category, 'Bakery');
      expect(p.municipality, 'Tuguegarao City');
      expect(p.address, '12 Rizal St, Centro');
      expect(p.phone, '09171234567');
      expect(p.email, 'shop@dubets.ph');
      expect(p.isFeatured, isTrue);
      expect(p.rating, 4.6);
      expect(p.reviewCount, 23);
      expect(p.productCount, 14);
    });

    test('carries the open/closed state — the closed banner depends on it', () {
      final open = VendorProfile.fromJson(storePayload());
      expect(open.isOpen, isTrue);

      final closed = VendorProfile.fromJson(storePayload(
        isOpen: false,
        nextOpenTime: {'day': 'saturday', 'open': '08:00'},
      ));
      expect(closed.isOpen, isFalse);
      expect(closed.nextOpenDay, 'saturday');
      expect(closed.nextOpenAt, '08:00');
    });

    test('does NOT claim a store is verified when the payload omits it', () {
      // The endpoint sends no `verified` field; the old parse defaulted to true
      // and put a verified tick on every store.
      expect(VendorProfile.fromJson(storePayload()).isVerified, isFalse);
      expect(
        VendorProfile.fromJson(storePayload(verified: true)).isVerified,
        isTrue,
      );
    });

    test('hands the trading hours through in a parseable shape', () {
      final p = VendorProfile.fromJson(storePayload());
      final week = parseWeeklyHours(
        storeHours: p.storeHours,
        operatingHours: p.operatingHours,
      );

      expect(week.map((d) => d.day), ['monday', 'sunday']);
      expect(week.first.range, '8:00 AM – 5:00 PM');
      expect(week.last.range, 'Closed');
    });

    test('blank strings become null, so empty rows are not rendered', () {
      final p = VendorProfile.fromJson({
        'id': 'v1',
        'name': 'Store',
        'address': '',
        'municipality': '   ',
        'phone': '',
        'category': '',
      });

      expect(p.address, isNull);
      expect(p.municipality, isNull);
      expect(p.phone, isNull);
      expect(p.category, isNull);
    });

    test('absolutises relative image paths against baseUrl', () {
      final p = VendorProfile.fromJson(
        {'id': 'v1', 'name': 'Store', 'logo': 'uploads/l.png', 'banner': '/b.jpg'},
        baseUrl: 'https://api.test',
      );

      expect(p.logoUrl, 'https://api.test/uploads/l.png');
      expect(p.bannerUrl, 'https://api.test/b.jpg');
    });

    test('leaves absolute urls alone', () {
      final p = VendorProfile.fromJson(
        storePayload(),
        baseUrl: 'https://api.test',
      );

      expect(p.logoUrl, 'https://cdn.test/logo.png');
      expect(p.bannerUrl, 'https://cdn.test/banner.jpg');
    });

    test('falls back to the requested id when the payload carries none', () {
      final p = VendorProfile.fromJson(
        {'name': 'Store'},
        fallbackId: 'requested-vendor-id',
      );

      expect(p.id, 'requested-vendor-id');
    });

    test('a bare payload still parses with safe defaults', () {
      final p = VendorProfile.fromJson(const {});

      expect(p.storeName, 'Store');
      expect(p.isOpen, isTrue);
      expect(p.isVerified, isFalse);
      expect(p.isFeatured, isFalse);
      expect(p.rating, 0);
      expect(p.productCount, 0);
    });
  });
}
