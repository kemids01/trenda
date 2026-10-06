// lib/features/checkout/models/checkout_model.dart
enum PaymentMethod {
  cod,
  card,
  ewallet,
  bank,
}

class CheckoutRequest {
  final Map<String, dynamic> shippingAddress;
  final PaymentMethod paymentMethod;
  final String deliveryType;
  final List<CheckoutItem> items;
  final String? batchTypeId;
  final String? coupon;

  /// Code of the gift card to spend on this order. The server decides how much it applies
  /// (goods only, never the delivery fee) — the client never sends an amount.
  final String? giftCardCode;

  CheckoutRequest({
    required this.shippingAddress,
    required this.paymentMethod,
    required this.items,
    this.deliveryType = 'express', // Default to express
    this.batchTypeId,
    this.coupon,
    this.giftCardCode,
  });

  Map<String, dynamic> toJson() => {
        'shippingAddress': shippingAddress,
        'paymentMethod': {
          'type': paymentMethod.name,
        },
        'deliveryType': deliveryType,
        if (batchTypeId != null) 'batchTypeId': batchTypeId,
        if (coupon != null && coupon!.isNotEmpty) 'coupon': coupon,
        if (giftCardCode != null && giftCardCode!.isNotEmpty) 'giftCardCode': giftCardCode,
        'cartItems': items
            .map((e) => e.toJson())
            .toList(), // ✅ Backend accepts both 'items' and 'cartItems'
      };
}

class CheckoutItem {
  final String productId;
  final int quantity;
  final String? variantId;

  CheckoutItem({
    required this.productId,
    required this.quantity,
    this.variantId,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        if (variantId != null) 'variantId': variantId,
      };
}
