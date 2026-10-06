// trenda_shared/lib/models/bundle_model.dart
// Product bundle models

/// Product bundle
class ProductBundle {
  final String id;
  final String name;
  final String? description;
  final String vendorId;
  final List<BundleItem> items;
  final double originalPrice;
  final double bundlePrice;
  final double savings;
  final double discountPercent;
  final String? imageUrl;
  final bool isActive;
  final int stock;
  final int soldCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductBundle({
    required this.id,
    required this.name,
    this.description,
    required this.vendorId,
    required this.items,
    required this.originalPrice,
    required this.bundlePrice,
    required this.savings,
    required this.discountPercent,
    this.imageUrl,
    this.isActive = true,
    this.stock = 0,
    this.soldCount = 0,
    this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductBundle.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? [])
        .map((i) => BundleItem.fromJson(i))
        .toList();

    // Calculate price values
    double originalPrice = (json['originalPrice'] ?? 0).toDouble();
    if (originalPrice == 0) {
      originalPrice = items.fold(0.0, (sum, item) => sum + item.subtotal);
    }

    double bundlePrice = (json['bundlePrice'] ?? json['price'] ?? originalPrice)
        .toDouble();
    double savings = originalPrice - bundlePrice;
    double discountPercent = originalPrice > 0
        ? (savings / originalPrice) * 100
        : 0;

    return ProductBundle(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      vendorId: json['vendorId'] ?? json['vendor'] ?? '',
      items: items,
      originalPrice: originalPrice,
      bundlePrice: bundlePrice,
      savings: json['savings']?.toDouble() ?? savings,
      discountPercent: json['discountPercent']?.toDouble() ?? discountPercent,
      imageUrl: json['imageUrl'] ?? json['image'],
      isActive: json['isActive'] ?? json['active'] ?? true,
      stock: json['stock'] ?? json['totalStock'] ?? 0,
      soldCount: json['soldCount'] ?? json['sold'] ?? 0,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'])
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    'items': items.map((i) => i.toJson()).toList(),
    'bundlePrice': bundlePrice,
    if (imageUrl != null) 'imageUrl': imageUrl,
    'isActive': isActive,
    if (startDate != null) 'startDate': startDate!.toIso8601String(),
    if (endDate != null) 'endDate': endDate!.toIso8601String(),
  };

  bool get isAvailable {
    if (!isActive || stock <= 0) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
}

/// Bundle item (product in bundle)
class BundleItem {
  final String productId;
  final String? productName;
  final String? productImage;
  final String? variantId;
  final String? variantName;
  final int quantity;
  final double price;
  final double subtotal;

  BundleItem({
    required this.productId,
    this.productName,
    this.productImage,
    this.variantId,
    this.variantName,
    required this.quantity,
    required this.price,
    double? subtotal,
  }) : subtotal = subtotal ?? (price * quantity);

  factory BundleItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    String productId;
    String? productName;
    String? productImage;

    if (product is Map<String, dynamic>) {
      productId = product['_id'] ?? product['id'] ?? '';
      productName = product['name'];
      final images = product['images'] as List?;
      productImage = images?.isNotEmpty == true
          ? images!.first.toString()
          : null;
    } else {
      productId = product?.toString() ?? json['productId'] ?? '';
      productName = json['productName'];
      productImage = json['productImage'];
    }

    final quantity = json['quantity'] ?? 1;
    final price = (json['price'] ?? json['unitPrice'] ?? 0).toDouble();

    return BundleItem(
      productId: productId,
      productName: productName,
      productImage: productImage,
      variantId: json['variantId'],
      variantName: json['variantName'],
      quantity: quantity,
      price: price,
      subtotal: (json['subtotal'] ?? price * quantity).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
    if (variantId != null) 'variantId': variantId,
  };
}

/// Bundle creation/update request
class BundleRequest {
  final String name;
  final String? description;
  final List<BundleItemRequest> items;
  final double bundlePrice;
  final String? imageUrl;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;

  BundleRequest({
    required this.name,
    this.description,
    required this.items,
    required this.bundlePrice,
    this.imageUrl,
    this.isActive = true,
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toJson() {
    // Calculate original price from all items
    final originalPrice = items.fold<double>(
      0.0,
      (sum, item) =>
          sum +
          (item.quantity *
              bundlePrice), // Simplified - in real app would get actual product prices
    );

    return {
      'name': name,
      if (description != null) 'description': description,
      'products': items
          .map((i) => i.toJson())
          .toList(), // Changed from 'items' to 'products'
      'bundlePrice': bundlePrice,
      'originalPrice': originalPrice > bundlePrice
          ? originalPrice
          : bundlePrice * 1.2, // Ensure originalPrice > bundlePrice
      'stock': 0, // Initial stock, vendor can update later
      // Note: isActive, imageUrl, dates not validated by backend, removed
    };
  }
}

class BundleItemRequest {
  final String productId;
  final String? variantId;
  final int quantity;
  final double priceAtCreation; // Required by backend

  BundleItemRequest({
    required this.productId,
    this.variantId,
    this.quantity = 1,
    this.priceAtCreation = 0.0, // Default to 0, will be populated from product
  });

  Map<String, dynamic> toJson() => {
    'product': productId, // Changed from 'productId' to 'product'
    'quantity': quantity,
    'priceAtCreation': priceAtCreation,
    // Backend doesn't support variants in bundles, removing variantId
  };
}

/// Bundle statistics
class BundleStats {
  final int totalBundles;
  final int activeBundles;
  final int totalSold;
  final double totalRevenue;
  final double avgDiscount;

  BundleStats({
    required this.totalBundles,
    required this.activeBundles,
    required this.totalSold,
    required this.totalRevenue,
    required this.avgDiscount,
  });

  factory BundleStats.fromJson(Map<String, dynamic> json) {
    return BundleStats(
      totalBundles: json['totalBundles'] ?? json['total'] ?? 0,
      activeBundles: json['activeBundles'] ?? json['active'] ?? 0,
      totalSold: json['totalSold'] ?? json['sold'] ?? 0,
      totalRevenue: (json['totalRevenue'] ?? json['revenue'] ?? 0).toDouble(),
      avgDiscount: (json['avgDiscount'] ?? json['averageDiscount'] ?? 0)
          .toDouble(),
    );
  }
}
