import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/utils/farthest_vendor.dart';

void main() {
  group('farthestVendor', () {
    test('returns null for empty vendor list', () {
      expect(farthestVendor(const [], 14.6, 121.0), isNull);
    });
    test('picks the farther of two vendors', () {
      final r = farthestVendor(const [
        [121.0, 14.61], // ~1.1km
        [121.0, 14.70], // ~11km
      ], 14.60, 121.0);
      expect(r, isNotNull);
      expect(r!.distanceKm, greaterThan(10));
      expect(r.lat, 14.70);
      expect(r.lng, 121.0);
    });
    test('skips malformed coordinates', () {
      final r = farthestVendor(const [
        [121.0]
      ], 14.60, 121.0);
      expect(r, isNull);
    });
  });

  // ORD-1790066150633-1A61IV: no product carries coordinates, so checkout quoted the flat base fee
  // while createOrder measured from the vendor STORE pin (or, for Official, the WAREHOUSE). These
  // product IDs let the estimate resolve the same origin.
  group("pinlessLineIdsKey", () {
    test("lists only lines with no coordinates, deduped and sorted", () {
      expect(
        pinlessLineIdsKey([
          (id: "b", coordinates: null),
          (id: "a", coordinates: const <double>[]),
          (id: "b", coordinates: null),
          (id: "c", coordinates: const [121.7, 17.6]),
          (id: "", coordinates: null),
        ]),
        "a,b",
      );
    });
    test("treats the [0,0] placeholder as no pin (shared fromJson default)", () {
      expect(pinlessLineIdsKey([(id: "a", coordinates: const [0.0, 0.0])]), "a");
      expect(farthestVendor(const [[0.0, 0.0]], 17.6, 121.7), isNull);
    });
    test("is empty when every line has coordinates", () {
      expect(pinlessLineIdsKey([(id: "c", coordinates: const [121.7, 17.6])]), "");
    });
  });
}
