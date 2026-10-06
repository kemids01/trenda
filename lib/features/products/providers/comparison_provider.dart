// lib/features/products/providers/comparison_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/models/product_model.dart';

/// Maximum products that can be compared at once
const int maxCompareProducts = 4;

/// Comparison state
class ComparisonState {
  final List<ProductModel> products;

  const ComparisonState({this.products = const []});

  bool get isEmpty => products.isEmpty;
  bool get isFull => products.length >= maxCompareProducts;
  int get count => products.length;

  bool contains(String productId) {
    return products.any((p) => p.id == productId);
  }

  ComparisonState copyWith({List<ProductModel>? products}) {
    return ComparisonState(products: products ?? this.products);
  }
}

/// Comparison notifier
class ComparisonNotifier extends StateNotifier<ComparisonState> {
  ComparisonNotifier() : super(const ComparisonState());

  void addProduct(ProductModel product) {
    if (state.isFull) return;
    if (state.contains(product.id)) return;

    state = state.copyWith(
      products: [...state.products, product],
    );
  }

  void removeProduct(String productId) {
    state = state.copyWith(
      products: state.products.where((p) => p.id != productId).toList(),
    );
  }

  void toggleProduct(ProductModel product) {
    if (state.contains(product.id)) {
      removeProduct(product.id);
    } else {
      addProduct(product);
    }
  }

  void clearAll() {
    state = const ComparisonState();
  }

  bool isSelected(String productId) => state.contains(productId);
}

/// Providers
final comparisonProvider =
    StateNotifierProvider<ComparisonNotifier, ComparisonState>(
  (ref) => ComparisonNotifier(),
);

final comparisonCountProvider = Provider<int>((ref) {
  return ref.watch(comparisonProvider).count;
});
