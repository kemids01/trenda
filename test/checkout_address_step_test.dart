import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trenda_frontend/features/auth/data/providers.dart' show currentUidProvider;
import 'package:trenda_frontend/features/cart/data/cart_repository.dart';
import 'package:trenda_frontend/features/cart/models/cart_model.dart';
import 'package:trenda_frontend/features/cart/providers/cart_provider.dart';
import 'package:trenda_frontend/features/checkout/presentation/checkout_page.dart';
import 'package:trenda_frontend/features/home/application/user_profile_notifier.dart';
import 'package:trenda_frontend/features/home/models/profile_models.dart';
import 'package:trenda_frontend/features/home/models/user_address.dart';
import 'package:trenda_frontend/features/home/presentation/addresses_page.dart';

final _home = UserAddress(
  id: 'a1',
  label: 'Home',
  street: 'Bonifacio St',
  city: 'Tuguegarao City',
  postalCode: '3500',
  country: 'Philippines',
  region: 'Region II',
  barangay: 'Centro 1',
  latitude: 17.61,
  longitude: 121.72,
);

class _CartRepo implements CartRepository {
  @override
  Future<CartModel> getCart() async => CartModel.fromJson({
        'items': [
          {
            '_id': 'c1',
            'onModel': 'Product',
            'quantity': 1,
            'price': 100,
            'product': {'_id': 'p1', 'name': 'Mango', 'price': 100},
          }
        ],
        'subtotal': 100,
      });
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Profile extends UserProfileNotifier {
  _Profile(this.initial);
  final UserProfileState initial;
  final phones = <String>[];
  final updatedAddresses = <UserAddress>[];
  @override
  Future<UserProfileState> build() async => initial;
  @override
  Future<bool> updatePhone(String newPhone) async {
    phones.add(newPhone);
    state = AsyncValue.data(state.value!.copyWith(phone: newPhone));
    return true;
  }

  @override
  Future<void> addOrUpdateAddress(UserAddress addr,
      {bool isUpdate = false}) async {
    if (isUpdate) updatedAddresses.add(addr);
  }
}

Future<void> _open(WidgetTester t, _Profile profile) async {
  SharedPreferences.setMockInitialValues({'pasabay_guide_dismissed': true});
  t.view.physicalSize = const Size(1200, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      cartProvider.overrideWith((ref) => CartNotifier(_CartRepo())),
      // checkoutCartProvider (ticked lines) resets per account via currentUidProvider,
      // which reads FirebaseAuth — pin a signed-in uid instead.
      currentUidProvider.overrideWithValue('test-uid'),
      userProfileProvider.overrideWith(() => profile),
    ],
    child: const MaterialApp(home: CheckoutPage()),
  ));
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('tapping the selected address opens its editor', (t) async {
    final profile = _Profile(UserProfileState(
        displayName: 'Maria', phone: '09171234567', addresses: [_home]));
    await _open(t, profile);

    await t.tap(find.byKey(const ValueKey('checkout-selected-address')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));

    final form = t.widget<AddressForm>(find.byType(AddressForm));
    expect(form.existingAddress?.id, 'a1');
  });

  testWidgets('a phone typed at checkout is saved to the profile on Next',
      (t) async {
    final profile =
        _Profile(UserProfileState(displayName: 'Maria', addresses: [_home]));
    await _open(t, profile);

    final phoneField = find.widgetWithText(TextField, 'Phone Number');
    expect(t.widget<TextField>(phoneField).controller!.text, isEmpty);
    await t.enterText(phoneField, '09171234567');
    await t.pump();
    await t.tap(find.text('Next'));
    await t.pump();

    expect(profile.phones, ['09171234567']);
  });

  testWidgets('an unchanged phone is not re-saved', (t) async {
    final profile = _Profile(UserProfileState(
        displayName: 'Maria', phone: '09171234567', addresses: [_home]));
    await _open(t, profile);

    final phoneField = find.widgetWithText(TextField, 'Phone Number');
    expect(t.widget<TextField>(phoneField).controller!.text, '09171234567');
    await t.tap(find.text('Next'));
    await t.pump();
    expect(profile.phones, isEmpty);
  });

  testWidgets('Express is the default delivery option', (t) async {
    final profile = _Profile(UserProfileState(
        displayName: 'Maria', phone: '09171234567', addresses: [_home]));
    await _open(t, profile);
    await t.tap(find.text('Next'));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }

    Color? iconColor(IconData icon) => t.widget<Icon>(find.byIcon(icon)).color;
    expect(find.text('Express Delivery'), findsOneWidget);
    expect(iconColor(Icons.flash_on), Colors.green);
    expect(iconColor(Icons.groups), isNot(Colors.green));
  });
}
