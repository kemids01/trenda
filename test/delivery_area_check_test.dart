// test/delivery_area_check_test.dart
// The checkout pre-check (POST /api/checkout/delivery-area-check) — the same server
// rule createOrder enforces. It must fail SOFT: an unreachable server never blocks.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_frontend/features/checkout/providers/checkout_provider.dart';

void main() {
  test('DeliveryAreaCheck parses a blocked answer', () {
    final c = DeliveryAreaCheck.fromJson({
      'ok': false,
      'addressMunicipality': 'Solana',
      'message': "Jelo Store (Tuguegarao City) doesn't deliver to Solana.",
      'blocked': [
        {'storeName': 'Jelo Store', 'storeMunicipality': 'Tuguegarao City', 'reason': 'outside_area'},
      ],
    });
    expect(c.ok, isFalse);
    expect(c.blocked.single.storeName, 'Jelo Store');
    expect(c.blocked.single.reason, 'outside_area');
    expect(c.message, contains('Solana'));
  });

  test('an unknown/unreachable answer never blocks', () {
    expect(DeliveryAreaCheck.unknown().ok, isTrue);
    expect(DeliveryAreaCheck.fromJson(const {}).ok, isTrue);
  });

  test('provider exposes the repository answer', () async {
    final container = ProviderContainer(overrides: [
      deliveryAreaCheckProvider.overrideWith((ref, q) async => DeliveryAreaCheck.fromJson(
          const {'ok': true, 'addressMunicipality': 'Tuguegarao City', 'blocked': [], 'message': ''})),
    ]);
    addTearDown(container.dispose);
    final r = await container.read(deliveryAreaCheckProvider((
      municipality: 'Tuguegarao City',
      barangay: 'Centro 01',
      lat: null,
      lng: null,
      productIds: 'a,b',
    )).future);
    expect(r.ok, isTrue);
  });
}
