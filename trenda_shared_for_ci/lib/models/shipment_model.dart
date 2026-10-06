// trenda_shared/lib/models/shipment_model.dart
// Shipment model for shipping management

class ShipmentModel {
  final String id;
  final String orderId;
  final String orderNumber;
  final String vendorId;
  final String customerId;
  final String customerName;
  final ShippingAddress shippingAddress;
  final List<ShipmentItem> items;
  final ShipmentStatus status;
  final String? courier;
  final String? trackingNumber;
  final String? trackingUrl;
  final PackageDetails? packageDetails;
  final DateTime? shippingDate;
  final DateTime? estimatedDelivery;
  final DateTime? actualDelivery;
  final List<TrackingEvent> trackingHistory;
  final String? notes;
  final String? labelUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShipmentModel({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.vendorId,
    required this.customerId,
    required this.customerName,
    required this.shippingAddress,
    required this.items,
    this.status = ShipmentStatus.pending,
    this.courier,
    this.trackingNumber,
    this.trackingUrl,
    this.packageDetails,
    this.shippingDate,
    this.estimatedDelivery,
    this.actualDelivery,
    this.trackingHistory = const [],
    this.notes,
    this.labelUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShipmentModel.fromJson(Map<String, dynamic> json) {
    return ShipmentModel(
      id: json['_id'] ?? json['id'] ?? '',
      orderId: json['orderId'] ?? json['order'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      vendorId: json['vendorId'] ?? json['vendor'] ?? '',
      customerId: json['customerId'] ?? json['customer'] ?? '',
      customerName: json['customerName'] ?? '',
      shippingAddress: ShippingAddress.fromJson(json['shippingAddress'] ?? {}),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ShipmentItem.fromJson(e))
              .toList() ??
          [],
      status: ShipmentStatus.fromString(json['status'] ?? 'pending'),
      courier: json['courier'],
      trackingNumber: json['trackingNumber'],
      trackingUrl: json['trackingUrl'],
      packageDetails: json['packageDetails'] != null
          ? PackageDetails.fromJson(json['packageDetails'])
          : null,
      shippingDate: json['shippingDate'] != null
          ? DateTime.tryParse(json['shippingDate'])
          : null,
      estimatedDelivery: json['estimatedDelivery'] != null
          ? DateTime.tryParse(json['estimatedDelivery'])
          : null,
      actualDelivery: json['actualDelivery'] != null
          ? DateTime.tryParse(json['actualDelivery'])
          : null,
      trackingHistory: (json['trackingHistory'] as List<dynamic>?)
              ?.map((e) => TrackingEvent.fromJson(e))
              .toList() ??
          [],
      notes: json['notes'],
      labelUrl: json['labelUrl'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isPending => status == ShipmentStatus.pending;
  bool get isReadyToShip => status == ShipmentStatus.readyToShip;
  bool get isShipped => status == ShipmentStatus.shipped;
  bool get isDelivered => status == ShipmentStatus.delivered;
  bool get isFailed => status == ShipmentStatus.failed;
  bool get hasTracking => trackingNumber != null && trackingNumber!.isNotEmpty;

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);
}

class ShipmentItem {
  final String productId;
  final String productName;
  final String? productImage;
  final String? variant;
  final int quantity;
  final double price;

  ShipmentItem({
    required this.productId,
    required this.productName,
    this.productImage,
    this.variant,
    required this.quantity,
    required this.price,
  });

  factory ShipmentItem.fromJson(Map<String, dynamic> json) {
    return ShipmentItem(
      productId: json['productId'] ?? json['product'] ?? '',
      productName: json['productName'] ?? '',
      productImage: json['productImage'],
      variant: json['variant'],
      quantity: json['quantity'] ?? 1,
      price: (json['price'] ?? 0).toDouble(),
    );
  }
}

class ShippingAddress {
  final String name;
  final String phone;
  final String street;
  final String? barangay;
  final String city;
  final String province;
  final String postalCode;
  final String country;
  final String? notes;

  ShippingAddress({
    required this.name,
    required this.phone,
    required this.street,
    this.barangay,
    required this.city,
    required this.province,
    required this.postalCode,
    this.country = 'Philippines',
    this.notes,
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      name: json['name'] ?? json['recipientName'] ?? '',
      phone: json['phone'] ?? '',
      street: json['street'] ?? json['line1'] ?? '',
      barangay: json['barangay'],
      city: json['city'] ?? '',
      province: json['province'] ?? json['state'] ?? '',
      postalCode: json['postalCode'] ?? json['zipCode'] ?? '',
      country: json['country'] ?? 'Philippines',
      notes: json['notes'] ?? json['instructions'],
    );
  }

  String get fullAddress {
    final parts = <String>[street];
    if (barangay != null && barangay!.isNotEmpty) parts.add(barangay!);
    parts.add('$city, $province $postalCode');
    return parts.join(', ');
  }
}

enum ShipmentStatus {
  pending('pending'),
  readyToShip('ready_to_ship'),
  shipped('shipped'),
  inTransit('in_transit'),
  outForDelivery('out_for_delivery'),
  delivered('delivered'),
  failed('failed'),
  returned('returned');

  final String value;
  const ShipmentStatus(this.value);

  static ShipmentStatus fromString(String value) {
    return ShipmentStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ShipmentStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case ShipmentStatus.pending:
        return 'Pending';
      case ShipmentStatus.readyToShip:
        return 'Ready to Ship';
      case ShipmentStatus.shipped:
        return 'Shipped';
      case ShipmentStatus.inTransit:
        return 'In Transit';
      case ShipmentStatus.outForDelivery:
        return 'Out for Delivery';
      case ShipmentStatus.delivered:
        return 'Delivered';
      case ShipmentStatus.failed:
        return 'Failed';
      case ShipmentStatus.returned:
        return 'Returned';
    }
  }
}

class PackageDetails {
  final double? weight; // in kg
  final PackageDimensions? dimensions;
  final String? packageType;

  PackageDetails({
    this.weight,
    this.dimensions,
    this.packageType,
  });

  factory PackageDetails.fromJson(Map<String, dynamic> json) {
    return PackageDetails(
      weight: json['weight']?.toDouble(),
      dimensions: json['dimensions'] != null
          ? PackageDimensions.fromJson(json['dimensions'])
          : null,
      packageType: json['packageType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (weight != null) 'weight': weight,
      if (dimensions != null) 'dimensions': dimensions!.toJson(),
      if (packageType != null) 'packageType': packageType,
    };
  }
}

class PackageDimensions {
  final double length;
  final double width;
  final double height;

  PackageDimensions({
    required this.length,
    required this.width,
    required this.height,
  });

  factory PackageDimensions.fromJson(Map<String, dynamic> json) {
    return PackageDimensions(
      length: (json['length'] ?? 0).toDouble(),
      width: (json['width'] ?? 0).toDouble(),
      height: (json['height'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'length': length,
      'width': width,
      'height': height,
    };
  }

  double get volume => length * width * height;
}

class TrackingEvent {
  final String status;
  final String description;
  final String? location;
  final DateTime timestamp;

  TrackingEvent({
    required this.status,
    required this.description,
    this.location,
    required this.timestamp,
  });

  factory TrackingEvent.fromJson(Map<String, dynamic> json) {
    return TrackingEvent(
      status: json['status'] ?? '',
      description: json['description'] ?? '',
      location: json['location'],
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

class CourierModel {
  final String id;
  final String name;
  final String code;
  final String? logo;
  final bool isActive;
  final List<String> supportedAreas;
  final ShippingRates? rates;

  CourierModel({
    required this.id,
    required this.name,
    required this.code,
    this.logo,
    this.isActive = true,
    this.supportedAreas = const [],
    this.rates,
  });

  factory CourierModel.fromJson(Map<String, dynamic> json) {
    return CourierModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      logo: json['logo'],
      isActive: json['isActive'] ?? true,
      supportedAreas: (json['supportedAreas'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rates: json['rates'] != null ? ShippingRates.fromJson(json['rates']) : null,
    );
  }
}

class ShippingRates {
  final double baseRate;
  final double perKgRate;
  final double? freeShippingThreshold;

  ShippingRates({
    required this.baseRate,
    required this.perKgRate,
    this.freeShippingThreshold,
  });

  factory ShippingRates.fromJson(Map<String, dynamic> json) {
    return ShippingRates(
      baseRate: (json['baseRate'] ?? 0).toDouble(),
      perKgRate: (json['perKgRate'] ?? 0).toDouble(),
      freeShippingThreshold: json['freeShippingThreshold']?.toDouble(),
    );
  }
}

class ShippingAnalytics {
  final int totalShipments;
  final int pendingShipments;
  final int inTransitShipments;
  final int deliveredShipments;
  final int failedShipments;
  final double averageDeliveryTime; // in days
  final double onTimeDeliveryRate;
  final Map<String, int> byCourier;
  final List<DailyShipmentData> dailyData;

  ShippingAnalytics({
    this.totalShipments = 0,
    this.pendingShipments = 0,
    this.inTransitShipments = 0,
    this.deliveredShipments = 0,
    this.failedShipments = 0,
    this.averageDeliveryTime = 0,
    this.onTimeDeliveryRate = 0,
    this.byCourier = const {},
    this.dailyData = const [],
  });

  factory ShippingAnalytics.fromJson(Map<String, dynamic> json) {
    // Safely parse byCourier - can be Map or List from backend
    Map<String, int> parseByCourier(dynamic data) {
      if (data == null) return {};
      if (data is Map<String, dynamic>) {
        return data.map((k, v) => MapEntry(k, (v as num).toInt()));
      }
      if (data is List) {
        // Convert list format like [{courier: "X", count: 5}] to map
        final result = <String, int>{};
        for (final item in data) {
          if (item is Map) {
            final courier = item['courier']?.toString() ?? item['name']?.toString();
            final count = (item['count'] ?? item['value'] ?? 0) as num;
            if (courier != null) result[courier] = count.toInt();
          }
        }
        return result;
      }
      return {};
    }

    return ShippingAnalytics(
      totalShipments: json['totalShipments'] ?? 0,
      pendingShipments: json['pendingShipments'] ?? 0,
      inTransitShipments: json['inTransitShipments'] ?? 0,
      deliveredShipments: json['deliveredShipments'] ?? 0,
      failedShipments: json['failedShipments'] ?? 0,
      averageDeliveryTime: (json['averageDeliveryTime'] ?? 0).toDouble(),
      onTimeDeliveryRate: (json['onTimeDeliveryRate'] ?? 0).toDouble(),
      byCourier: parseByCourier(json['byCourier']),
      dailyData: (json['dailyData'] as List<dynamic>?)
              ?.map((e) => DailyShipmentData.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class DailyShipmentData {
  final DateTime date;
  final int shipped;
  final int delivered;
  final int failed;

  DailyShipmentData({
    required this.date,
    required this.shipped,
    required this.delivered,
    required this.failed,
  });

  factory DailyShipmentData.fromJson(Map<String, dynamic> json) {
    return DailyShipmentData(
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      shipped: json['shipped'] ?? 0,
      delivered: json['delivered'] ?? 0,
      failed: json['failed'] ?? 0,
    );
  }
}

class ShipmentsFetchResult {
  final List<ShipmentModel> shipments;
  final int total;
  final int page;
  final int totalPages;

  ShipmentsFetchResult({
    required this.shipments,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}
