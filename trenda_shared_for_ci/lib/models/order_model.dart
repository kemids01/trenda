// trenda_shared/lib/models/order_model.dart
import 'dart:convert';
import 'delivery_info.dart';

class OrderModel {
  final String id;
  final String orderNumber;
  final String customerId;
  final String? customerName;
  final String? customerEmail;

  final List<OrderItem> items;

  final double subtotal;
  final double shippingFee;
  final double tax;
  final double total;
  final double discount;

  final String paymentMethod;
  final String paymentStatus;
  final String? transactionId;

  final ShippingAddress? shippingAddress;

  final String status;
  final String deliveryStatus;
  final List<StatusHistory> statusHistory;

  // ✅ NEW: Delivery metadata from backend
  final DeliveryInfo? delivery;

  final String? trackingNumber;
  final List<OrderNote>? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deliveredAt;

  // ✅ NEW: Vendor info for pickup location
  final VendorInfo? vendor;

  // ✅ NEW: Cancellation info
  final String? cancelReason;
  final DateTime? cancelledAt;

  // ✅ NEW: Commission breakdown from backend
  final OrderCommission? commission;

  // ✅ NEW: Official Trenda Store (first-party) flags. Nullable — absent/false for
  // ordinary orders. officialChannel: 'store' (consumer) | 'supplier' (vendor B2B).
  final bool? isOfficial;
  final String? officialChannel;

  /// What the rider hands the vendor at pickup, resolved SERVER-SIDE by the settlement engine
  /// (`utils/vendorPaymentDue.js`). Supplied by GET /api/delivery/deliveries/:id and by the
  /// confirm-pickup response.
  ///
  /// ⚠️ Never re-derive this in an app. The vendor platform fee is dynamic — global, then a
  /// per-municipality override, then a per-product override — so a client-side percentage drifts
  /// the moment an admin edits a rate. That is exactly how one order showed the rider ₱111.72 at
  /// pickup and ₱108.30 at completion while the backend had recorded ₱111.72 throughout.
  /// Null on endpoints that do not supply it; callers fall back to [commission].
  final VendorPaymentDue? vendorPaymentDue;

  /// Set when the order was placed while a store in it was CLOSED but taking
  /// orders (backend utils/advanceOrder.js): the store accepts it when it opens.
  /// Null on every ordinary order.
  final AdvanceOrderInfo? advanceOrder;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    this.customerName,
    this.customerEmail,
    required this.items,
    required this.subtotal,
    required this.shippingFee,
    required this.tax,
    required this.total,
    this.discount = 0.0,
    required this.paymentMethod,
    required this.paymentStatus,
    this.transactionId,
    this.shippingAddress,
    required this.status,
    String? deliveryStatus,
    List<StatusHistory>? statusHistory,
    this.delivery,
    this.trackingNumber,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deliveredAt,
    this.vendor,
    this.cancelReason,
    this.cancelledAt,
    this.commission, // ✅ NEW
    this.isOfficial, // ✅ NEW
    this.officialChannel, // ✅ NEW
    this.vendorPaymentDue,
    this.advanceOrder,
  }) : deliveryStatus = deliveryStatus ?? status,
       statusHistory = statusHistory ?? [];

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['_id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerId: _extractId(json['customer']),
      customerName: _extractName(json['customer']),
      customerEmail: _extractEmail(json['customer']),
      items: _extractList(json['items'], (e) => OrderItem.fromJson(e)),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      shippingFee: (json['shippingFee'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      paymentMethod: json['paymentMethod']?['type']?.toString() ?? 'unknown',
      paymentStatus: json['paymentStatus']?.toString() ?? 'pending',
      transactionId: json['transactionId']?.toString(),
      shippingAddress: json['shippingAddress'] != null
          ? ShippingAddress.fromJson(json['shippingAddress'])
          : null,
      status: json['status']?.toString() ?? 'pending',
      deliveryStatus:
          json['deliveryStatus']?.toString() ??
          json['status']?.toString() ??
          'pending',
      statusHistory: _extractList(
        json['statusHistory'],
        (e) => StatusHistory.fromJson(e),
      ),
      trackingNumber: json['trackingNumber']?.toString(),
      notes: _extractList(json['notes'], (e) => OrderNote.fromJson(e)),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.parse(json['deliveredAt'])
          : null,
      delivery: json['delivery'] != null
          ? DeliveryInfo.fromJson({
              ...json['delivery'] as Map<String, dynamic>,
              // ✅ INJECT: Full commission data for municipality-based earnings + override detection
              if (json['commission'] != null) 'commission': json['commission'],
              // Also inject direct earnings for backwards compatibility
              if (json['commission'] != null &&
                  json['commission']['riderNetEarnings'] != null)
                'earnings': json['commission']['riderNetEarnings'],
            })
          : null,
      vendor: json['vendor'] != null
          ? VendorInfo.fromJson(json['vendor'])
          : null,
      cancelReason: json['cancelReason']?.toString(),
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'])
          : null,
      // ✅ NEW: Parse commission breakdown
      commission: json['commission'] != null
          ? OrderCommission.fromJson(json['commission'])
          : null,
      // ✅ NEW: Official Trenda Store flags
      isOfficial: json['isOfficial'] == true,
      officialChannel: json['officialChannel']?.toString(),
      // Server-resolved vendor payment (see the field doc). Absent on endpoints that don't send it.
      vendorPaymentDue: json['vendorPaymentDue'] is Map
          ? VendorPaymentDue.fromJson(
              Map<String, dynamic>.from(json['vendorPaymentDue'] as Map),
            )
          : null,
      advanceOrder: AdvanceOrderInfo.tryParse(json['advanceOrder']),
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'orderNumber': orderNumber,
    'customer': {
      '_id': customerId,
      'name': customerName,
      'email': customerEmail,
    },
    'items': items.map((e) => e.toJson()).toList(),
    'subtotal': subtotal,
    'shippingFee': shippingFee,
    'tax': tax,
    'total': total,
    'discount': discount,
    'paymentMethod': paymentMethod,
    'paymentStatus': paymentStatus,
    'transactionId': transactionId,
    'shippingAddress': shippingAddress?.toJson(),
    'status': status,
    'deliveryStatus': deliveryStatus,
    'statusHistory': statusHistory.map((e) => e.toJson()).toList(),
    'trackingNumber': trackingNumber,
    'notes': notes?.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deliveredAt': deliveredAt?.toIso8601String(),
    'delivery': delivery?.toJson(), // ✅ NEW
    'vendor': vendor?.toJson(), // ✅ NEW
    'cancelReason': cancelReason, // ✅ NEW
    'cancelledAt': cancelledAt?.toIso8601String(), // ✅ NEW
    'isOfficial': isOfficial, // ✅ NEW
    'officialChannel': officialChannel, // ✅ NEW
    'commission': commission?.toJson(),
    'vendorPaymentDue': vendorPaymentDue?.toJson(),
  };

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _extractId(dynamic obj) {
    if (obj is Map) {
      return obj['_id']?.toString() ?? obj['id']?.toString() ?? '';
    }
    return obj?.toString() ?? '';
  }

  static String? _extractName(dynamic obj) {
    if (obj is Map) return obj['name']?.toString();
    return null;
  }

  static String? _extractEmail(dynamic obj) {
    if (obj is Map) return obj['email']?.toString();
    return null;
  }

  static List<T> _extractList<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (data == null) return [];

    List<dynamic> list = [];
    if (data is List) {
      list = data;
    } else if (data is String) {
      try {
        if (data.trim().startsWith('[')) {
          final decoded = jsonDecode(data);
          if (decoded is List) {
            list = decoded;
          }
        }
      } catch (_) {
        // Fallback or log if needed
      }
    }

    return list
        .map((e) {
          if (e is Map<String, dynamic>) {
            return fromJson(e);
          } else if (e is Map) {
            // Handle Map<dynamic, dynamic>
            try {
              return fromJson(Map<String, dynamic>.from(e));
            } catch (_) {
              return null;
            }
          }
          return null;
        })
        .where((e) => e != null)
        .cast<T>()
        .toList();
  }

  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? customerId,
    String? customerName,
    String? customerEmail,
    List<OrderItem>? items,
    double? subtotal,
    double? shippingFee,
    double? tax,
    double? total,
    double? discount,
    String? paymentMethod,
    String? paymentStatus,
    String? transactionId,
    ShippingAddress? shippingAddress,
    String? status,
    String? deliveryStatus,
    List<StatusHistory>? statusHistory,
    String? trackingNumber,
    List<OrderNote>? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deliveredAt,
    bool? isOfficial,
    String? officialChannel,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      shippingFee: shippingFee ?? this.shippingFee,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      discount: discount ?? this.discount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      transactionId: transactionId ?? this.transactionId,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      status: status ?? this.status,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      statusHistory: statusHistory ?? this.statusHistory,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      delivery: delivery, // ✅ NEW - uses existing delivery field
      isOfficial: isOfficial ?? this.isOfficial,
      officialChannel: officialChannel ?? this.officialChannel,
      // Carried through: copyWith takes no parameter for either, and DROPPING them would silently
      // strip the settlement figures the rider's pickup and completion screens render — the very
      // numbers this model is the authority for.
      commission: commission,
      vendorPaymentDue: vendorPaymentDue,
      advanceOrder: advanceOrder,
    );
  }
}

/// An order placed while a store was closed (see [OrderModel.advanceOrder]).
class AdvanceOrderInfo {
  /// Weekday the store next opens ('monday'), when the backend knew it.
  final String? nextOpenDay;

  /// Opening clock time ('08:00'), when the backend knew it.
  final String? nextOpenAt;

  const AdvanceOrderInfo({this.nextOpenDay, this.nextOpenAt});

  /// Null unless the payload says the order was placed while closed. The
  /// reopening slot is an OBJECT ({date, day, open, …} from StoreHours, or
  /// {date, time} from the store schedule), never a display string.
  static AdvanceOrderInfo? tryParse(Object? raw) {
    if (raw is! Map || raw['placedWhileClosed'] != true) return null;
    final next = raw['nextOpenTime'];
    final slot = next is Map ? next : const {};
    String? str(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return AdvanceOrderInfo(
      nextOpenDay: str(slot['day']),
      nextOpenAt: str(slot['open'] ?? slot['time']),
    );
  }
}

// -----------------------------------------------------------------------------
// OrderItem
// -----------------------------------------------------------------------------
// OrderItem - FIXED with copyWith and resellerInfo
class OrderItem {
  final String productId;
  final String productName;
  final String? productImage;
  final int quantity;
  final double price;
  final double subtotal;
  final String? vendorId;
  final Map<String, dynamic>? resellerInfo; // ✅ NEW: Reseller commission info
  /// The variant the order was placed for (`variant.id`), so a reorder adds
  /// the same variant rather than the base product.
  final String? variantId;

  OrderItem({
    required this.productId,
    required this.productName,
    this.productImage,
    required this.quantity,
    required this.price,
    required this.subtotal,
    this.vendorId,
    this.resellerInfo, // ✅ NEW
    this.variantId,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Handle product being either a string ID or a populated object
    String extractProductId(dynamic product) {
      if (product == null) return '';
      if (product is String) return product;
      if (product is Map) {
        // Populated object - get _id or id
        return product['_id']?.toString() ?? product['id']?.toString() ?? '';
      }
      return product.toString();
    }

    return OrderItem(
      productId: extractProductId(json['product']),
      productName: json['productName']?.toString() ?? '',
      productImage: json['productImage']?.toString(),
      quantity: json['quantity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      vendorId: json['vendor']?.toString(),
      resellerInfo: json['resellerInfo'] as Map<String, dynamic>?, // ✅ NEW
      variantId: json['variant'] is Map
          ? (json['variant'] as Map)['id']?.toString()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'product': productId,
    'productName': productName,
    'productImage': productImage,
    'quantity': quantity,
    'price': price,
    'subtotal': subtotal,
    'vendor': vendorId,
    'resellerInfo': resellerInfo, // ✅ NEW
    if (variantId != null) 'variant': {'id': variantId},
  };

  // ✅ NEW: copyWith method
  OrderItem copyWith({
    String? productId,
    String? productName,
    String? productImage,
    int? quantity,
    double? price,
    double? subtotal,
    String? vendorId,
    Map<String, dynamic>? resellerInfo, // ✅ NEW
    String? variantId,
  }) {
    return OrderItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      subtotal: subtotal ?? this.subtotal,
      vendorId: vendorId ?? this.vendorId,
      resellerInfo: resellerInfo ?? this.resellerInfo, // ✅ NEW
      variantId: variantId ?? this.variantId,
    );
  }
}

// StatusHistory - FIXED with copyWith
class StatusHistory {
  final String status;
  final DateTime timestamp;
  final String? note;

  StatusHistory({required this.status, required this.timestamp, this.note});

  factory StatusHistory.fromJson(Map<String, dynamic> json) {
    return StatusHistory(
      status: json['status']?.toString() ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      note: json['note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'timestamp': timestamp.toIso8601String(),
    'note': note,
  };

  // ✅ NEW: copyWith method
  StatusHistory copyWith({String? status, DateTime? timestamp, String? note}) {
    return StatusHistory(
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      note: note ?? this.note,
    );
  }
}

// -----------------------------------------------------------------------------
// ShippingAddress
// -----------------------------------------------------------------------------
class ShippingAddress {
  final String? name;
  final String? phone;
  final String? street;
  final String? barangay;
  final String? city;
  final String? municipality; // ✅ PH: Coexists with city
  final String? region;
  final String? postalCode;
  final String? country;
  final String? province;
  final String? landmark;
  final String? deliveryInstructions;
  final double? latitude;
  final double? longitude;

  ShippingAddress({
    this.name,
    this.phone,
    this.street,
    this.barangay,
    this.city,
    this.municipality, // ✅ PH
    this.region,
    this.postalCode,
    this.country,
    this.province, // ✅ NEW
    this.landmark, // ✅ NEW
    this.deliveryInstructions, // ✅ NEW
    this.latitude, // ✅ NEW
    this.longitude, // ✅ NEW
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
      street: json['street']?.toString(),
      barangay: json['barangay']?.toString(),
      city: json['city']?.toString(),
      municipality: json['municipality']?.toString() ?? json['city']?.toString(), // ✅ Fallback to city
      region: json['region']?.toString(),
      postalCode: json['postalCode']?.toString(),
      country: json['country']?.toString() ?? 'Philippines',
      province: json['province']?.toString(), // ✅ NEW
      landmark: json['landmark']?.toString(), // ✅ NEW
      deliveryInstructions: json['deliveryInstructions']?.toString(), // ✅ NEW
      latitude: json['latitude']?.toDouble(), // ✅ NEW
      longitude: json['longitude']?.toDouble(), // ✅ NEW
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'street': street,
    'barangay': barangay,
    'city': city,
    'municipality': municipality,
    'region': region,
    'postalCode': postalCode,
    'country': country,
    'province': province, // ✅ NEW
    'landmark': landmark, // ✅ NEW
    'deliveryInstructions': deliveryInstructions, // ✅ NEW
    'latitude': latitude, // ✅ NEW
    'longitude': longitude, // ✅ NEW
  };

  // ✅ NEW: Helper to get full address string
  String get fullAddress {
    final parts = [
      street,
      barangay,
      municipality ?? city,
      region,
      postalCode,
    ].where((p) => p != null && p.isNotEmpty).toList();
    return parts.join(', ');
  }

  // ✅ NEW: Check if coordinates are available
  bool get hasCoordinates => latitude != null && longitude != null;

  // ✅ NEW: copyWith method
  ShippingAddress copyWith({
    String? name,
    String? phone,
    String? street,
    String? barangay,
    String? city,
    String? region,
    String? postalCode,
    String? country,
    double? latitude,
    double? longitude,
  }) {
    return ShippingAddress(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      street: street ?? this.street,
      barangay: barangay ?? this.barangay,
      city: city ?? this.city,
      region: region ?? this.region,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      province: province ?? this.province,
      landmark: landmark ?? this.landmark,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

// -----------------------------------------------------------------------------
// OrderNote
// -----------------------------------------------------------------------------
class OrderNote {
  final String content;
  final String author;
  final DateTime createdAt;

  OrderNote({
    required this.content,
    required this.author,
    required this.createdAt,
  });

  factory OrderNote.fromJson(Map<String, dynamic> json) {
    return OrderNote(
      content: json['content']?.toString() ?? '',
      author: json['author']?.toString() ?? 'System',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'content': content,
    'author': author,
    'createdAt': createdAt.toIso8601String(),
  };
}

// -----------------------------------------------------------------------------
// VendorInfo - Vendor/Store info for pickup location
// -----------------------------------------------------------------------------
class VendorInfo {
  final String? id;
  final String? storeName;
  final String? phone;
  final String? address;
  final double? latitude;
  final double? longitude;

  VendorInfo({
    this.id,
    this.storeName,
    this.phone,
    this.address,
    this.latitude,
    this.longitude,
  });

  factory VendorInfo.fromJson(Map<String, dynamic> json) {
    // Handle both direct vendor object and nested vendorProfile
    final profile = json['vendorProfile'] as Map<String, dynamic>?;
    final location =
        profile?['location'] as Map<String, dynamic>? ??
        profile?['storeLocation'] as Map<String, dynamic>? ??
        json['location'] as Map<String, dynamic>?;

    // ✅ Parse latitude/longitude - check direct fields first, then nested location
    double? lat = (json['latitude'] as num?)?.toDouble();
    double? lng = (json['longitude'] as num?)?.toDouble();

    // Fallback to nested location coordinates
    if (lat == null || lng == null) {
      final coords = location?['coordinates'];
      if (coords is List && coords.length >= 2) {
        lat ??= (coords[1] as num?)?.toDouble();
        lng ??= (coords[0] as num?)?.toDouble();
      }
      lat ??= (location?['latitude'] as num?)?.toDouble();
      lng ??= (location?['longitude'] as num?)?.toDouble();
    }

    return VendorInfo(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      storeName:
          profile?['storeName']?.toString() ??
          json['storeName']?.toString() ??
          json['name']?.toString(),
      phone: profile?['phone']?.toString() ?? json['phone']?.toString(),
      address:
          json['address']?.toString() ??
          location?['address']?['fullAddress']?.toString() ??
          location?['address']?.toString() ??
          profile?['businessAddress']?.toString(),
      latitude: lat,
      longitude: lng,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'storeName': storeName,
    'phone': phone,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
  };
}

// -----------------------------------------------------------------------------
// OrderCommission - Commission breakdown from backend
// -----------------------------------------------------------------------------
class OrderCommission {
  final double vendorPlatformFee;
  final double deliveryPlatformFee;
  final double totalPlatformFee;
  final double vendorNetEarnings;
  final double riderNetEarnings;
  final double peakHourSurcharge;
  final DateTime? calculatedAt;
  final Map<String, dynamic>? ratesApplied;

  OrderCommission({
    this.vendorPlatformFee = 0,
    this.deliveryPlatformFee = 0,
    this.totalPlatformFee = 0,
    this.vendorNetEarnings = 0,
    this.riderNetEarnings = 0,
    this.peakHourSurcharge = 0,
    this.calculatedAt,
    this.ratesApplied,
  });

  factory OrderCommission.fromJson(Map<String, dynamic> json) {
    return OrderCommission(
      vendorPlatformFee: (json['vendorPlatformFee'] as num?)?.toDouble() ?? 0,
      deliveryPlatformFee:
          (json['deliveryPlatformFee'] as num?)?.toDouble() ?? 0,
      totalPlatformFee: (json['totalPlatformFee'] as num?)?.toDouble() ?? 0,
      vendorNetEarnings: (json['vendorNetEarnings'] as num?)?.toDouble() ?? 0,
      riderNetEarnings: (json['riderNetEarnings'] as num?)?.toDouble() ?? 0,
      peakHourSurcharge: (json['peakHourSurcharge'] as num?)?.toDouble() ?? 0,
      calculatedAt: json['calculatedAt'] != null
          ? DateTime.tryParse(json['calculatedAt'].toString())
          : null,
      ratesApplied: json['ratesApplied'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'vendorPlatformFee': vendorPlatformFee,
    'deliveryPlatformFee': deliveryPlatformFee,
    'totalPlatformFee': totalPlatformFee,
    'vendorNetEarnings': vendorNetEarnings,
    'riderNetEarnings': riderNetEarnings,
    'peakHourSurcharge': peakHourSurcharge,
    'calculatedAt': calculatedAt?.toIso8601String(),
    'ratesApplied': ratesApplied,
  };
}

// -----------------------------------------------------------------------------
// VendorPaymentDue
// -----------------------------------------------------------------------------
/// The cash the rider hands the vendor at pickup, resolved SERVER-SIDE.
///
/// Mirrors `trenda_backend/utils/vendorPaymentDue.js` — the one resolver behind both the pickup
/// preview (GET /api/delivery/deliveries/:id) and confirm-pickup, so the figure the rider is quoted
/// is the figure the order settles against.
///
/// ⚠️ This type deliberately carries the AMOUNT, not just a rate. Do not compute
/// `subtotal * percentage` from it: the backend applies a flat rate and a minimum fee on top, and
/// per-product overrides can price individual items differently within one order. [amount] is the
/// answer; [percentage] and [source] exist only to EXPLAIN it to the rider.
class VendorPaymentDue {
  /// Pay the vendor exactly this.
  final double amount;

  /// The vendor platform fee deducted from the subtotal to reach [amount].
  final double vendorPlatformFee;

  /// The rate that produced [vendorPlatformFee] — for display only.
  final double percentage;
  final double flatRate;
  final double minFee;

  /// Which municipality's rate resolved, when one did.
  final String? municipality;

  /// Which tier of the cascade set the rate: 'platform' | 'municipality' | 'product'.
  final String source;

  const VendorPaymentDue({
    required this.amount,
    this.vendorPlatformFee = 0,
    this.percentage = 0,
    this.flatRate = 0,
    this.minFee = 0,
    this.municipality,
    this.source = 'platform',
  });

  factory VendorPaymentDue.fromJson(Map<String, dynamic> json) {
    return VendorPaymentDue(
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      vendorPlatformFee: (json['vendorPlatformFee'] as num?)?.toDouble() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
      flatRate: (json['flatRate'] as num?)?.toDouble() ?? 0,
      minFee: (json['minFee'] as num?)?.toDouble() ?? 0,
      municipality: json['municipality']?.toString(),
      source: json['source']?.toString() ?? 'platform',
    );
  }

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'vendorPlatformFee': vendorPlatformFee,
    'percentage': percentage,
    'flatRate': flatRate,
    'minFee': minFee,
    'municipality': municipality,
    'source': source,
  };

  /// Human-readable rate, e.g. "2%" or "2% + ₱5". Empty when no rate was supplied.
  String get rateLabel {
    if (percentage <= 0 && flatRate <= 0) return '';
    final pct = percentage > 0
        ? '${percentage.toStringAsFixed(percentage % 1 == 0 ? 0 : 2)}%'
        : '';
    if (flatRate <= 0) return pct;
    final flat = '₱${flatRate.toStringAsFixed(flatRate % 1 == 0 ? 0 : 2)}';
    return pct.isEmpty ? flat : '$pct + $flat';
  }

  /// Why this rate applies, when it is not the platform default.
  String? get sourceLabel {
    switch (source) {
      case 'municipality':
        return municipality != null && municipality!.isNotEmpty
            ? '$municipality rate'
            : 'City rate';
      case 'product':
        return 'Product-specific rate';
      default:
        return null;
    }
  }
}
