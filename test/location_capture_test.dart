import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trenda_frontend/features/checkout/utils/location_capture.dart';

void main() {
  group('gpsFailureMessage', () {
    test('location services disabled → settings guidance', () {
      final msg = gpsFailureMessage(const LocationServiceDisabledException());
      expect(msg, contains('Location services are off'));
      expect(msg.toLowerCase(), contains('settings'));
    });

    test('timeout → try-again guidance (no raw exception text)', () {
      final msg = gpsFailureMessage(TimeoutException('Future not completed'));
      expect(msg.toLowerCase(), contains('too long'));
      expect(msg, isNot(contains('TimeoutException')));
    });

    test('permission denied exception → permission guidance', () {
      final msg = gpsFailureMessage(const PermissionDeniedException('denied'));
      expect(msg.toLowerCase(), contains('permission denied'));
    });

    test('unknown "permission" string is classified as permission', () {
      final msg = gpsFailureMessage(Exception('PlatformException permission foo'));
      expect(msg.toLowerCase(), contains('permission denied'));
    });

    test('unknown "service" string is classified as services-off', () {
      final msg = gpsFailureMessage(Exception('location service unavailable'));
      expect(msg, contains('Location services are off'));
    });

    test('unrecognized error → safe generic fallback', () {
      final msg = gpsFailureMessage(Exception('something weird'));
      expect(msg, contains('Could not get your location'));
    });
  });

  group('GpsCaptureResult', () {
    test('failure carries message and is not ok', () {
      const r = GpsCaptureResult.failure('nope');
      expect(r.ok, isFalse);
      expect(r.error, 'nope');
      expect(r.position, isNull);
    });
  });
}
