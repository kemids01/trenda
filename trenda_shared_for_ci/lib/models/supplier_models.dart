// trenda_shared/lib/models/supplier_models.dart
class SupplierProduct {
  final String id;
  final String name;
  final String? description;
  final List<String> images;
  final double cost;
  final double basePrice;
  final String category;
  final int totalStock;
  final int minimumOrder;
  final int leadTime;
  final SupplierVendor vendor;
  
  // Pricing suggestions
  final double suggestedRetailPrice;
  final double potentialMargin;
  final int marginPercent;

  SupplierProduct({
    required this.id,
    required this.name,
    this.description,
    required this.images,
    required this.cost,
    required this.basePrice,
    required this.category,
    required this.totalStock,
    required this.minimumOrder,
    required this.leadTime,
    required this.vendor,
    required this.suggestedRetailPrice,
    required this.potentialMargin,
    required this.marginPercent,
  });

  factory SupplierProduct.fromJson(Map<String, dynamic> json) {
    return SupplierProduct(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      images: List<String>.from(json['images'] ?? []),
      cost: (json['cost'] ?? 0).toDouble(),
      basePrice: (json['basePrice'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      totalStock: json['totalStock'] ?? 0,
      minimumOrder: json['minimumOrder'] ?? 1,
      leadTime: json['leadTime'] ?? 7,
      vendor: SupplierVendor.fromJson(json['vendor'] ?? {}),
      suggestedRetailPrice: (json['suggestedRetailPrice'] ?? 0).toDouble(),
      potentialMargin: (json['potentialMargin'] ?? 0).toDouble(),
      marginPercent: json['marginPercent'] ?? 0,
    );
  }

  bool get inStock => totalStock > 0;
  
  String get mainImage => images.isNotEmpty 
      ? images.first 
      : 'https://via.placeholder.com/400x400?text=No+Image';
}

class SupplierVendor {
  final String id;
  final SupplierProfile? supplierProfile;

  SupplierVendor({
    required this.id,
    this.supplierProfile,
  });

  factory SupplierVendor.fromJson(Map<String, dynamic> json) {
    return SupplierVendor(
      id: json['_id'] ?? '',
      supplierProfile: json['supplierProfile'] != null
          ? SupplierProfile.fromJson(json['supplierProfile'])
          : null,
    );
  }

  String get companyName => supplierProfile?.companyName ?? 'Unknown Supplier';
  bool get verified => supplierProfile?.verified ?? false;
  int get minimumOrderQuantity => supplierProfile?.minimumOrderQuantity ?? 1;
}

class SupplierProfile {
  final String companyName;
  final bool verified;
  final int minimumOrderQuantity;

  SupplierProfile({
    required this.companyName,
    required this.verified,
    required this.minimumOrderQuantity,
  });

  factory SupplierProfile.fromJson(Map<String, dynamic> json) {
    return SupplierProfile(
      companyName: json['companyName'] ?? '',
      verified: json['verified'] ?? false,
      minimumOrderQuantity: json['minimumOrderQuantity'] ?? 1,
    );
  }
}

class SupplierInfo {
  final String id;
  final String name;
  final SupplierProfile supplierProfile;
  final int productCount;

  SupplierInfo({
    required this.id,
    required this.name,
    required this.supplierProfile,
    required this.productCount,
  });

  factory SupplierInfo.fromJson(Map<String, dynamic> json) {
    return SupplierInfo(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      supplierProfile: SupplierProfile.fromJson(json['supplierProfile'] ?? {}),
      productCount: json['productCount'] ?? 0,
    );
  }

  String get companyName => supplierProfile.companyName;
  bool get verified => supplierProfile.verified;
}

/// Extract a stable String id/value from a field that may be a bare String, an
/// ObjectId-like value, or a populated/enriched Map ({_id|id|type|...}).
String _refId(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  if (v is Map) {
    return (v['_id'] ?? v['id'] ?? v['type'] ?? '').toString();
  }
  return v.toString();
}

/// Render creditTerms as a short label. The backend stores { days, dueDate };
/// tolerate a plain String too. Returns null when unset.
String? _creditTermsLabel(dynamic v) {
  if (v == null) return null;
  if (v is String) return v.isEmpty ? null : v;
  if (v is Map) {
    final days = v['days'];
    return days == null ? null : '$days days';
  }
  return null;
}

class SupplierOrder {
  final String id;
  final String supplier;
  final String vendor;
  final List<SupplierOrderItemDetail> items;
  final double subtotal;
  final double tax;
  final double shippingFee;
  final double total;
  final Map<String, dynamic> deliveryAddress;
  final String? notes;
  final String paymentMethod;
  final String? creditTerms;
  final String status;
  final DateTime createdAt;
  final List<StatusHistory> statusHistory;

  SupplierOrder({
    required this.id,
    required this.supplier,
    required this.vendor,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.shippingFee,
    required this.total,
    required this.deliveryAddress,
    this.notes,
    required this.paymentMethod,
    this.creditTerms,
    required this.status,
    required this.createdAt,
    required this.statusHistory,
  });

  factory SupplierOrder.fromJson(Map<String, dynamic> json) {
    return SupplierOrder(
      id: _refId(json['_id']),
      // `supplier`/`vendor` may arrive as a bare id String OR a populated/enriched
      // object (the vendor-orders endpoint enriches supplier → {_id,name,...}).
      supplier: _refId(json['supplier']),
      vendor: _refId(json['vendor']),
      items: (json['items'] as List?)
          ?.map((e) => SupplierOrderItemDetail.fromJson(e))
          .toList() ?? [],
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      shippingFee: (json['shippingFee'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      deliveryAddress: Map<String, dynamic>.from(json['deliveryAddress'] ?? {}),
      notes: json['notes'],
      // paymentMethod is a String on SupplierOrder but can be an object on a delivery Order.
      paymentMethod: _refId(json['paymentMethod']),
      // creditTerms is a { days, dueDate } object on the backend, not a String.
      creditTerms: _creditTermsLabel(json['creditTerms']),
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      statusHistory: (json['statusHistory'] as List?)
          ?.map((e) => StatusHistory.fromJson(e))
          .toList() ?? [],
    );
  }

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);
}

class SupplierOrderItemDetail {
  final String product;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  SupplierOrderItemDetail({
    required this.product,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory SupplierOrderItemDetail.fromJson(Map<String, dynamic> json) {
    return SupplierOrderItemDetail(
      product: _refId(json['product']),
      productName: json['productName'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
    );
  }
}

class StatusHistory {
  final String status;
  final DateTime timestamp;
  final String? note;
  final String? updatedBy;

  StatusHistory({
    required this.status,
    required this.timestamp,
    this.note,
    this.updatedBy,
  });

  factory StatusHistory.fromJson(Map<String, dynamic> json) {
    return StatusHistory(
      status: json['status'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      note: json['note'],
      updatedBy: json['updatedBy'],
    );
  }
}