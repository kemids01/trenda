import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/cart/data/cart_repository.dart';
import 'package:trenda_frontend/features/cart/models/cart_model.dart';
import 'package:trenda_frontend/features/cart/providers/cart_provider.dart';
import 'package:trenda_shared/models/order_model.dart';

class _FakeRepo extends CartRepository {
  _FakeRepo() : super(baseUrl: 'http://test');
  List<Map<String, dynamic>>? received;

  @override
  Future<CartModel> getCart() async => CartModel.empty();

  @override
  Future<void> addItemsFromOrder(List<Map<String, dynamic>> items) async {
    received = items;
  }
}

void main() {
  test('reorderFromOrder sends each order item with its variant', () async {
    final repo = _FakeRepo();
    final cart = CartNotifier(repo);
    final ok = await cart.reorderFromOrder([
      OrderItem(
          productId: 'p1',
          productName: 'Shirt',
          quantity: 2,
          price: 100,
          subtotal: 200,
          variantId: 'v-red-m'),
      OrderItem(
          productId: 'p2',
          productName: 'Rice',
          quantity: 1,
          price: 50,
          subtotal: 50),
    ]);
    expect(ok, isTrue);
    expect(repo.received, [
      {'productId': 'p1', 'quantity': 2, 'variantId': 'v-red-m'},
      {'productId': 'p2', 'quantity': 1, 'variantId': null},
    ]);
  });
}
