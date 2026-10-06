import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_shared/services/geo_service.dart';
import 'package:trenda_frontend/features/checkout/utils/gps_address.dart';
import 'package:trenda_frontend/features/home/models/user_address.dart';

void main() {
  test('buildGpsAddress composes coords + municipality + barangay', () {
    final a = buildGpsAddress(
      lat: 17.6, lng: 121.7, municipality: 'Tuguegarao', barangay: 'Centro',
    );
    expect(a.city, 'Tuguegarao');
    expect(a.barangay, 'Centro');
    expect(a.latitude, 17.6);
    expect(a.longitude, 121.7);
    expect(a.street, 'Current GPS location');
    expect(a.locationType, LocationType.gps);
  });

  group('deriveGpsLocality', () {
    test('prefers city for municipality and suburb for barangay', () {
      final loc = deriveGpsLocality(const GeoAddressComponents(
        city: 'Tuguegarao City',
        municipality: 'Tuguegarao',
        town: 'Tugue',
        suburb: 'Centro 10',
        village: 'San Gabriel',
      ));
      expect(loc.municipality, 'Tuguegarao City');
      expect(loc.barangay, 'Centro 10');
      expect(loc.hasBarangay, isTrue);
    });

    test('falls back to municipality/town and village', () {
      final loc = deriveGpsLocality(const GeoAddressComponents(
        municipality: 'Solana',
        village: 'Bangag',
      ));
      expect(loc.municipality, 'Solana');
      expect(loc.barangay, 'Bangag');
    });

    test('trims whitespace and reports missing barangay', () {
      final loc = deriveGpsLocality(const GeoAddressComponents(
        town: '  Aparri  ',
        suburb: '   ',
      ));
      expect(loc.municipality, 'Aparri');
      expect(loc.barangay, '');
      expect(loc.hasBarangay, isFalse);
    });

    test('null components yield empty locality', () {
      final loc = deriveGpsLocality(null);
      expect(loc.municipality, '');
      expect(loc.barangay, '');
      expect(loc.hasBarangay, isFalse);
    });
  });
}
