import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/data/checkout_repository.dart';

void main() {
  group('parseCouponValidationResponse', () {
    test('200 success returns ok with discount and type', () {
      final r = parseCouponValidationResponse(
        200,
        '{"success":true,"data":{"code":"SAVE10","discount":50.0,"type":"percentage","finalTotal":450.0}}',
      );
      expect(r.ok, true);
      expect(r.discount, 50.0);
      expect(r.type, 'percentage');
      expect(r.message, isNull);
    });

    test('404 returns not-ok with backend message', () {
      final r = parseCouponValidationResponse(
        404,
        '{"success":false,"message":"Invalid coupon code"}',
      );
      expect(r.ok, false);
      expect(r.discount, 0.0);
      expect(r.message, 'Invalid coupon code');
    });

    test('400 min-purchase returns not-ok with message', () {
      final r = parseCouponValidationResponse(
        400,
        '{"success":false,"message":"Minimum purchase of ₱500 required"}',
      );
      expect(r.ok, false);
      expect(r.message, contains('Minimum purchase'));
    });

    test('unparseable body returns safe not-ok', () {
      final r = parseCouponValidationResponse(200, '<html>oops</html>');
      expect(r.ok, false);
      expect(r.message, isNotNull);
    });

    test('200 success with missing data key returns ok with zero discount', () {
      final r = parseCouponValidationResponse(200, '{"success":true}');
      expect(r.ok, true);
      expect(r.discount, 0.0);
      expect(r.type, isNull);
    });
  });
}
