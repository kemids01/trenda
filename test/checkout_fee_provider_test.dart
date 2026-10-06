import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_frontend/features/checkout/providers/checkout_provider.dart';
import 'package:trenda_frontend/features/checkout/data/checkout_repository.dart';

void main() {
  test('checkoutFeeProvider returns the repository CalculatedDeliveryFee', () async {
    final container = ProviderContainer(overrides: [
      checkoutFeeProvider.overrideWith((ref, params) async =>
          CalculatedDeliveryFee.fallback(params.deliveryType)),
    ]);
    addTearDown(container.dispose);
    final fee = await container.read(checkoutFeeProvider((
      deliveryType: 'express',
      municipality: 'X',
      barangay: '',
      weight: 1,
      itemCount: 1,
      orderTotal: 100,
      vendorLat: 14.7,
      vendorLng: 121.0,
      customerLat: 14.6,
      customerLng: 121.0,
      productIds: '',
    )).future);
    expect(fee.deliveryType, 'express');
  });
}
