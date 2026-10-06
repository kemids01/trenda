// lib/features/cart/models/cart_model.dart
import 'package:trenda_shared/models/product_model.dart';
import 'package:trenda_shared/models/bundle_model.dart';

class CartModel {
  final List<CartItem> items;
  final double subtotal;
  final int itemCount;

  CartModel({
    required this.items,
    required this.subtotal,
    required this.itemCount,
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? [])
        .map((e) => CartItem.fromJson(e))
        .toList();

    return CartModel(
      items: items,
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      itemCount: json['itemCount'] ?? items.length,
    );
  }

  factory CartModel.empty() => CartModel(
        items: [],
        subtotal: 0,
        itemCount: 0,
      );
}

class CartItem {
  final String id;
  final ProductModel? product;
  final ProductBundle? bundle; // ✅ NEW
  final String onModel; // 'Product' or 'Bundle'
  final int quantity;
  final double price;

  // Variant info (only for Products)
  final String? variantId;
  final String? variantName;
  final String? variantSku;

  CartItem({
    required this.id,
    this.product,
    this.bundle,
    this.onModel = 'Product',
    required this.quantity,
    required this.price,
    this.variantId,
    this.variantName,
    this.variantSku,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final onModel = json['onModel'] ?? 'Product';
    final productJson = json['product'];

    // Check type
    ProductModel? product;
    ProductBundle? bundle;

    // Handle population where product field contains the object
    if (productJson is Map<String, dynamic>) {
      if (onModel == 'Bundle') {
        bundle = ProductBundle.fromJson(productJson);
      } else {
        product = ProductModel.fromJson(productJson);
      }
    }

    final variantJson = json['variant'];

    return CartItem(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      product: product,
      bundle: bundle,
      onModel: onModel,
      quantity: json['quantity'] ?? 1,
      price: (json['price'] ?? 0).toDouble(),
      variantId: variantJson?['id'],
      variantName: variantJson?['name'],
      variantSku: variantJson?['sku'],
    );
  }

  double get subtotal => price * quantity;

  // Helper getters for UI consistency
  String get name => onModel == 'Bundle'
      ? (bundle?.name ?? 'Unknown Bundle')
      : (product?.name ?? 'Unknown Product');
  String get image => onModel == 'Bundle'
      ? (bundle?.imageUrl ??
          '') // Bundle might typically rely on first image or specific field
      : (product?.images.isNotEmpty == true ? product!.images.first : '');

  // For Bundle, we treat it as having "enough stock" if stock > 0
  // Backend sets it dynamically.
  int get stock =>
      onModel == 'Bundle' ? (bundle?.stock ?? 0) : (product?.totalStock ?? 0);

  String get vendorId => onModel == 'Bundle'
      ? (bundle?.vendorId ?? '')
      : (product?.vendorId ?? '');

  // ✅ For weight calculation in checkout
  double? get weight => product?.weight;

  // ✅ For vendor location/distance calculation in checkout
  ProductLocation? get location => product?.location;

  // ✅ For checkout item - the actual product/bundle ID
  String get productId =>
      onModel == 'Bundle' ? (bundle?.id ?? '') : (product?.id ?? '');

  // ✅ For store status check (bundles always considered "open")
  ProductStoreStatus? get storeStatus => product?.storeStatus;

  // ✅ For store name display
  String? get storeName => product?.storeName;
}
