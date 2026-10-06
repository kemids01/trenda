// trenda_shared/lib/models/product_model.dart
// ============================================================================
// UPDATED PRODUCT MODEL - FULL VERSION (MERGED + ENHANCED)
// ============================================================================

import 'map_pin.dart';

class ProductVariant {
  final String id;
  final String name;
  final String? sku;
  final double price;
  final double? compareAtPrice;
  final int stock;
  final List<String> images;
  final Map<String, String> attributes; // e.g., color, size, material

  ProductVariant({
    required this.id,
    required this.name,
    this.sku,
    required this.price,
    this.compareAtPrice,
    required this.stock,
    this.images = const [],
    this.attributes = const {},
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString(),
      price: (json['price'] ?? 0).toDouble(),
      compareAtPrice: json['compareAtPrice']?.toDouble(),
      stock: json['stock'] ?? 0,
      images: List<String>.from(json['images'] ?? []),
      attributes: Map<String, String>.from(json['attributes'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sku': sku,
    'price': price,
    'compareAtPrice': compareAtPrice,
    'stock': stock,
    'images': images,
    'attributes': attributes,
  };

  ProductVariant copyWith({
    String? id,
    String? name,
    String? sku,
    double? price,
    double? compareAtPrice,
    int? stock,
    List<String>? images,
    Map<String, String>? attributes,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      stock: stock ?? this.stock,
      images: images ?? this.images,
      attributes: attributes ?? this.attributes,
    );
  }
}

// ============================================================================
// DIMENSIONS + LOCATION + AVAILABILITY STRUCTURES
// ============================================================================

class ProductDimensions {
  final double length;
  final double width;
  final double height;
  final String unit;

  ProductDimensions({
    required this.length,
    required this.width,
    required this.height,
    this.unit = 'cm',
  });

  factory ProductDimensions.fromJson(Map<String, dynamic> json) {
    return ProductDimensions(
      length: (json['length'] ?? 0).toDouble(),
      width: (json['width'] ?? 0).toDouble(),
      height: (json['height'] ?? 0).toDouble(),
      unit: json['unit'] ?? 'cm',
    );
  }

  Map<String, dynamic> toJson() => {
    'length': length,
    'width': width,
    'height': height,
    'unit': unit,
  };

  double get volume => length * width * height;
}

class ProductLocation {
  final String type;
  final List<double> coordinates; // [longitude, latitude]
  final String? address;
  final String? city;
  final String? region;
  final String? postalCode;

  ProductLocation({
    this.type = 'Point',
    required this.coordinates,
    this.address,
    this.city,
    this.region,
    this.postalCode,
  });

  factory ProductLocation.fromJson(Map<String, dynamic> json) {
    return ProductLocation(
      type: json['type'] ?? 'Point',
      coordinates: List<double>.from(json['coordinates'] ?? [0.0, 0.0]),
      address: json['address'],
      city: json['city'],
      region: json['region'],
      postalCode: json['postalCode'],
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'coordinates': coordinates,
    'address': address,
    'city': city,
    'region': region,
    'postalCode': postalCode,
  };
}

// ============================================================================
// AVAILABILITY STRUCTURE
// ============================================================================

class TimeSlot {
  final String day;
  final String start;
  final String end;
  final bool available;

  TimeSlot({
    required this.day,
    required this.start,
    required this.end,
    this.available = true,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      day: json['day'] ?? '',
      start: json['start'] ?? '',
      end: json['end'] ?? '',
      available: json['available'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'day': day,
    'start': start,
    'end': end,
    'available': available,
  };
}

class SeasonalAvailability {
  final DateTime startDate;
  final DateTime endDate;
  final bool available;
  final String? reason;

  SeasonalAvailability({
    required this.startDate,
    required this.endDate,
    this.available = true,
    this.reason,
  });

  factory SeasonalAvailability.fromJson(Map<String, dynamic> json) {
    return SeasonalAvailability(
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      available: json['available'] ?? true,
      reason: json['reason'],
    );
  }

  Map<String, dynamic> toJson() => {
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'available': available,
    'reason': reason,
  };
}

class ProductAvailability {
  final bool alwaysAvailable;
  final List<TimeSlot> timeSlots;
  final List<SeasonalAvailability> seasonalAvailability;
  final int preparationTime;
  final String? cutoffTime;
  final bool advanceOrderOnly;
  final int minAdvanceHours;

  ProductAvailability({
    this.alwaysAvailable = true,
    this.timeSlots = const [],
    this.seasonalAvailability = const [],
    this.preparationTime = 0,
    this.cutoffTime,
    this.advanceOrderOnly = false,
    this.minAdvanceHours = 24,
  });

  factory ProductAvailability.fromJson(Map<String, dynamic> json) {
    return ProductAvailability(
      alwaysAvailable: json['alwaysAvailable'] ?? true,
      timeSlots:
          (json['timeSlots'] as List?)
              ?.map((e) => TimeSlot.fromJson(e))
              .toList() ??
          [],
      seasonalAvailability:
          (json['seasonalAvailability'] as List?)
              ?.map((e) => SeasonalAvailability.fromJson(e))
              .toList() ??
          [],
      preparationTime: json['preparationTime'] ?? 0,
      cutoffTime: json['cutoffTime'],
      advanceOrderOnly: json['advanceOrderOnly'] ?? false,
      minAdvanceHours: json['minAdvanceHours'] ?? 24,
    );
  }

  Map<String, dynamic> toJson() => {
    'alwaysAvailable': alwaysAvailable,
    'timeSlots': timeSlots.map((e) => e.toJson()).toList(),
    'seasonalAvailability': seasonalAvailability
        .map((e) => e.toJson())
        .toList(),
    'preparationTime': preparationTime,
    'cutoffTime': cutoffTime,
    'advanceOrderOnly': advanceOrderOnly,
    'minAdvanceHours': minAdvanceHours,
  };
}

// ============================================================================
// STORE STATUS (for products from vendor stores)
// ============================================================================

/// Represents whether the vendor's store is currently open
class ProductStoreStatus {
  final bool isOpen;

  /// Legacy plain-string reopening value. The backend normally sends an OBJECT
  /// here (see [nextOpenDay]/[nextOpenAt]); this stays null in that case rather
  /// than holding a stringified map, which no UI can display.
  final String? nextOpenTime;

  /// Weekday the store next opens ('saturday'), from `nextOpen(.Time).day`.
  final String? nextOpenDay;

  /// Opening clock time ('08:00'), from `nextOpen(.Time).open` (VendorStoreHours)
  /// or `.time` (the VendorStore schedule shape).
  final String? nextOpenAt;

  /// Whether the store accepts orders right now. True when open, or when closed
  /// but the vendor enabled "accept orders while closed" (advance orders).
  /// Defaults true when the backend omits it (older payloads / open stores).
  final bool canOrder;

  ProductStoreStatus({
    this.isOpen = true,
    this.nextOpenTime,
    this.nextOpenDay,
    this.nextOpenAt,
    this.canOrder = true,
  });

  factory ProductStoreStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ProductStoreStatus(isOpen: true);

    // Backend uses `nextOpen` on the product feed and `nextOpenTime` elsewhere.
    // Either can be an object ({date, day, open, close, isSpecialHours}) — the
    // old `.toString()` on it rendered a raw map in the closed-store dialog.
    final next = json['nextOpen'] ?? json['nextOpenTime'];
    final Map<String, dynamic>? nextMap =
        next is Map ? Map<String, dynamic>.from(next) : null;

    return ProductStoreStatus(
      isOpen: json['isOpen'] ?? true,
      nextOpenTime: nextMap == null ? next?.toString() : null,
      // Flat keys are the round-trip form written by toJson (cart persistence).
      nextOpenDay: (nextMap?['day'] ?? json['nextOpenDay'])?.toString(),
      nextOpenAt:
          (nextMap?['open'] ?? nextMap?['time'] ?? json['nextOpenAt'])?.toString(),
      canOrder: json['canOrder'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'isOpen': isOpen,
    'nextOpenTime': nextOpenTime,
    'nextOpenDay': nextOpenDay,
    'nextOpenAt': nextOpenAt,
    'canOrder': canOrder,
  };
}

// ============================================================================
// RESELL CONFIGURATION (for vendor reseller system)
// ============================================================================

/// Configuration for allowing other vendors to resell this product
class ProductResellConfig {
  final bool enabled;
  final double commissionPercent;
  final bool publicResell;
  final double? minPrice;
  final double? maxPrice;

  ProductResellConfig({
    this.enabled = false,
    this.commissionPercent = 5.0,
    this.publicResell = true,
    this.minPrice,
    this.maxPrice,
  });

  factory ProductResellConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ProductResellConfig();
    return ProductResellConfig(
      enabled: json['enabled'] ?? false,
      commissionPercent: (json['commissionPercent'] ?? 5.0).toDouble(),
      publicResell: json['publicResell'] ?? true,
      minPrice: json['minPrice']?.toDouble(),
      maxPrice: json['maxPrice']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'commissionPercent': commissionPercent,
    'publicResell': publicResell,
    if (minPrice != null) 'minPrice': minPrice,
    if (maxPrice != null) 'maxPrice': maxPrice,
  };
}

// ============================================================================
// RESELLER INFO (for products that are resold by another vendor)
// ============================================================================

/// Information about the reseller relationship for resold products
class ProductResellerInfo {
  final bool isResale;
  final String? originalProductId;
  final String? originalVendorId;
  final String? originalVendorName;
  final String? originalVendorStoreName;
  final String? resellerVendorId;
  final double commissionPercent;
  final DateTime? resoldAt;

  ProductResellerInfo({
    this.isResale = false,
    this.originalProductId,
    this.originalVendorId,
    this.originalVendorName,
    this.originalVendorStoreName,
    this.resellerVendorId,
    this.commissionPercent = 5.0,
    this.resoldAt,
  });

  factory ProductResellerInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ProductResellerInfo();
    return ProductResellerInfo(
      isResale: json['isResale'] ?? false,
      originalProductId: json['originalProduct']?.toString(),
      originalVendorId: json['originalVendor']?.toString(),
      originalVendorName: json['originalVendorName']?.toString(),
      originalVendorStoreName: json['originalVendorStoreName']?.toString(),
      resellerVendorId: json['resellerVendor']?.toString(),
      commissionPercent: (json['commissionPercent'] ?? 5.0).toDouble(),
      resoldAt: json['resoldAt'] != null
          ? DateTime.tryParse(json['resoldAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'isResale': isResale,
    if (originalProductId != null) 'originalProduct': originalProductId,
    if (originalVendorId != null) 'originalVendor': originalVendorId,
    if (originalVendorName != null) 'originalVendorName': originalVendorName,
    if (originalVendorStoreName != null)
      'originalVendorStoreName': originalVendorStoreName,
    if (resellerVendorId != null) 'resellerVendor': resellerVendorId,
    'commissionPercent': commissionPercent,
    if (resoldAt != null) 'resoldAt': resoldAt!.toIso8601String(),
  };
}

// ============================================================================
// MAIN PRODUCT MODEL
// ============================================================================

class ProductModel {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? shortDescription;

  // Vendor
  final String vendorId;
  final String? vendorName;
  final String? storeName;

  // Pricing
  final double basePrice;
  final double? compareAtPrice;
  final double? cost;

  // Inventory
  final int totalStock;
  final int lowStockThreshold;
  final bool trackInventory;
  final bool allowBackorder;

  // Variants
  final bool hasVariants;
  final List<ProductVariant> variants;

  // Categorization
  final String category;
  final String? subcategory;
  final List<String> tags;

  // Media
  final List<String> images;
  final List<String> videos;

  // SEO
  final String? metaTitle;
  final String? metaDescription;

  // Shipping
  final double? weight;
  final ProductDimensions? dimensions;
  final bool freeShipping;
  final String? shippingClass;

  // Location / Delivery
  final ProductLocation? location;
  final double deliveryRadius;
  final bool pickupAvailable;
  final bool deliveryAvailable;

  // Availability
  final ProductAvailability? availability;

  // Status / Analytics
  final String status;
  final bool featured;
  final int views;
  final int sales;
  final double revenue;

  // Reviews
  final double averageRating;
  final int totalReviews;
  final bool freeDelivery;

  // Additional
  final String? brand;
  final String? manufacturer;
  final String? warranty;
  final String? returnPolicy;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  // Store Status (from vendor)
  final ProductStoreStatus? storeStatus;

  // Pending changes from staff edits (for vendor approval)
  final Map<String, dynamic>? pendingChanges;

  // ✅ NEW: Resell configuration for vendor reseller system
  final ProductResellConfig? resell;

  // ✅ NEW: Reseller info for resold products
  final ProductResellerInfo? resellerInfo;

  // ✅ Category-driven listing engine (2026-07-12) — additive, back-compat
  final String listingType;   // standard_physical | fresh | big_ticket | service
  final String pricingUnit;   // each | kg | bundle | piece | per_service | hourly | quote
  final Map<String, dynamic> attributes; // template-driven spec fields
  final bool installmentAvailable;
  final String transactionMode; // checkout | inquiry

  /// The seller's shop location, when the backend's gate allowed it. Null is the
  /// ordinary case — free vendors, hidden pins and unpinned stores all arrive as null.
  final MapPin? storePin;

  /// May a shopper message this shop? Server-resolved from the vendor's plan and the
  /// platform switch. ⚠️ Absent means TRUE — an older backend or a cached payload must
  /// never hide a button that still works.
  final bool chatEnabled;

  ProductModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.shortDescription,
    required this.vendorId,
    this.vendorName,
    this.storeName,
    required this.basePrice,
    this.compareAtPrice,
    this.cost,
    this.totalStock = 0,
    this.lowStockThreshold = 5,
    this.trackInventory = true,
    this.allowBackorder = false,
    this.hasVariants = false,
    this.variants = const [],
    required this.category,
    this.subcategory,
    this.tags = const [],
    this.images = const [],
    this.videos = const [],
    this.metaTitle,
    this.metaDescription,
    this.weight,
    this.dimensions,
    this.freeShipping = false,
    this.shippingClass,
    this.location,
    this.deliveryRadius = 10.0,
    this.pickupAvailable = true,
    this.deliveryAvailable = true,
    this.availability,
    this.status = 'draft',
    this.featured = false,
    this.views = 0,
    this.sales = 0,
    this.revenue = 0,
    this.averageRating = 0,
    this.totalReviews = 0,
    this.freeDelivery = false,
    this.brand,
    this.manufacturer,
    this.warranty,
    this.returnPolicy,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.storeStatus,
    this.pendingChanges,
    this.resell,
    this.resellerInfo,
    this.listingType = 'standard_physical',
    this.pricingUnit = 'each',
    this.attributes = const {},
    this.installmentAvailable = false,
    this.transactionMode = 'checkout',
    this.storePin,
    this.chatEnabled = true,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // ==========================================================================
  // JSON SERIALIZATION
  // ==========================================================================

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      shortDescription: json['shortDescription']?.toString(),
      vendorId: _extractVendorId(json['vendor']),
      vendorName: _extractVendorName(json['vendor']),
      storeName: json['storeName']?.toString(),
      basePrice: (json['basePrice'] ?? 0).toDouble(),
      compareAtPrice: json['compareAtPrice']?.toDouble(),
      cost: json['cost']?.toDouble(),
      totalStock: json['totalStock'] ?? 0,
      lowStockThreshold: json['lowStockThreshold'] ?? 5,
      trackInventory: json['trackInventory'] ?? true,
      allowBackorder: json['allowBackorder'] ?? false,
      hasVariants: json['hasVariants'] ?? false,
      variants:
          (json['variants'] as List?)
              ?.map((e) => ProductVariant.fromJson(e))
              .toList() ??
          [],
      category: json['category']?.toString() ?? 'Other',
      subcategory: json['subcategory']?.toString(),
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      images:
          (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      videos:
          (json['videos'] as List?)?.map((e) => e.toString()).toList() ?? [],
      metaTitle: json['metaTitle']?.toString(),
      metaDescription: json['metaDescription']?.toString(),
      weight: json['weight']?.toDouble(),
      dimensions: json['dimensions'] != null
          ? ProductDimensions.fromJson(json['dimensions'])
          : null,
      freeShipping: json['freeShipping'] ?? false,
      shippingClass: json['shippingClass']?.toString(),
      location: json['location'] != null
          ? ProductLocation.fromJson(json['location'])
          : null,
      deliveryRadius: (json['deliveryRadius'] ?? 10.0).toDouble(),
      pickupAvailable: json['pickupAvailable'] ?? true,
      deliveryAvailable: json['deliveryAvailable'] ?? true,
      availability: json['availability'] != null
          ? ProductAvailability.fromJson(json['availability'])
          : null,
      status: json['status']?.toString() ?? 'draft',
      featured: json['featured'] ?? false,
      views: json['views'] ?? 0,
      sales: json['sales'] ?? 0,
      revenue: (json['revenue'] ?? 0).toDouble(),
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      freeDelivery: json['freeDelivery'] == true,
      totalReviews: json['totalReviews'] ?? 0,
      brand: json['brand']?.toString(),
      manufacturer: json['manufacturer']?.toString(),
      warranty: json['warranty']?.toString(),
      returnPolicy: json['returnPolicy']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      storeStatus: json['storeStatus'] != null
          ? ProductStoreStatus.fromJson(json['storeStatus'])
          : null,
      pendingChanges: json['pendingChanges'] as Map<String, dynamic>?,
      resell: json['resell'] != null
          ? ProductResellConfig.fromJson(json['resell'])
          : null,
      resellerInfo: json['resellerInfo'] != null
          ? ProductResellerInfo.fromJson(json['resellerInfo'])
          : null,
      listingType: json['listingType']?.toString() ?? 'standard_physical',
      pricingUnit: json['pricingUnit']?.toString() ?? 'each',
      attributes: json['attributes'] is Map
          ? Map<String, dynamic>.from(json['attributes'])
          : const {},
      installmentAvailable: json['installmentAvailable'] == true,
      transactionMode: json['transactionMode']?.toString() ?? 'checkout',
      storePin: MapPin.fromJson(
        json['storePin'] is Map ? Map<String, dynamic>.from(json['storePin'] as Map) : null,
      ),
      chatEnabled: json['chatEnabled'] != false,
    );
  }

  static String _extractVendorId(dynamic vendor) {
    if (vendor is Map) {
      return vendor['_id']?.toString() ?? vendor['id']?.toString() ?? '';
    }
    return vendor?.toString() ?? '';
  }

  static String? _extractVendorName(dynamic vendor) {
    if (vendor is Map) {
      return vendor['name']?.toString() ?? vendor['displayName']?.toString();
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'shortDescription': shortDescription,
    'vendor': vendorId,
    'basePrice': basePrice,
    'compareAtPrice': compareAtPrice,
    'cost': cost,
    'totalStock': totalStock,
    'lowStockThreshold': lowStockThreshold,
    'trackInventory': trackInventory,
    'allowBackorder': allowBackorder,
    'hasVariants': hasVariants,
    'variants': variants.map((v) => v.toJson()).toList(),
    'category': category,
    'subcategory': subcategory,
    'tags': tags,
    'images': images,
    'videos': videos,
    'metaTitle': metaTitle,
    'metaDescription': metaDescription,
    'weight': weight,
    'dimensions': dimensions?.toJson(),
    'freeShipping': freeShipping,
    'shippingClass': shippingClass,
    'location': location?.toJson(),
    'deliveryRadius': deliveryRadius,
    'pickupAvailable': pickupAvailable,
    'deliveryAvailable': deliveryAvailable,
    'availability': availability?.toJson(),
    'status': status,
    'featured': featured,
    'brand': brand,
    'manufacturer': manufacturer,
    'listingType': listingType,
    'pricingUnit': pricingUnit,
    'attributes': attributes,
    'installmentAvailable': installmentAvailable,
    'transactionMode': transactionMode,
  };

  // ==========================================================================
  // COMPUTED PROPERTIES
  // ==========================================================================

  /// Returns the first valid image URL (excluding placeholders) or a placeholder
  String get mainImage {
    final validImages = images
        .where((img) => img.isNotEmpty && !img.contains('placeholder'))
        .toList();
    return validImages.isNotEmpty
        ? validImages.first
        : 'https://via.placeholder.com/400x400/f0f0f0/999999?text=No+Image';
  }

  /// Checks if product has any valid images (excluding placeholders)
  bool get hasImages =>
      images.any((img) => img.isNotEmpty && !img.contains('placeholder'));

  // ==========================================================================
  // COPYWITH
  // ==========================================================================

  ProductModel copyWith({
    String? name,
    String? description,
    String? shortDescription,
    double? basePrice,
    double? compareAtPrice,
    double? cost,
    int? totalStock,
    String? category,
    String? subcategory,
    List<String>? tags,
    List<String>? images,
    bool? featured,
    String? status,
    List<ProductVariant>? variants,
    ProductLocation? location,
    double? deliveryRadius,
    bool? pickupAvailable,
    bool? deliveryAvailable,
    ProductAvailability? availability,
    String? listingType,
    String? pricingUnit,
    Map<String, dynamic>? attributes,
    bool? installmentAvailable,
    String? transactionMode,
    MapPin? storePin,
    bool? chatEnabled,
  }) {
    return ProductModel(
      id: id,
      name: name ?? this.name,
      slug: slug,
      description: description ?? this.description,
      shortDescription: shortDescription ?? this.shortDescription,
      vendorId: vendorId,
      vendorName: vendorName,
      storeName: storeName,
      basePrice: basePrice ?? this.basePrice,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      cost: cost ?? this.cost,
      totalStock: totalStock ?? this.totalStock,
      lowStockThreshold: lowStockThreshold,
      trackInventory: trackInventory,
      allowBackorder: allowBackorder,
      hasVariants: hasVariants,
      variants: variants ?? this.variants,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      tags: tags ?? this.tags,
      images: images ?? this.images,
      videos: videos,
      metaTitle: metaTitle,
      metaDescription: metaDescription,
      weight: weight,
      dimensions: dimensions,
      freeShipping: freeShipping,
      shippingClass: shippingClass,
      location: location ?? this.location,
      deliveryRadius: deliveryRadius ?? this.deliveryRadius,
      pickupAvailable: pickupAvailable ?? this.pickupAvailable,
      deliveryAvailable: deliveryAvailable ?? this.deliveryAvailable,
      availability: availability ?? this.availability,
      status: status ?? this.status,
      featured: featured ?? this.featured,
      views: views,
      sales: sales,
      revenue: revenue,
      averageRating: averageRating,
      freeDelivery: freeDelivery,
      totalReviews: totalReviews,
      brand: brand,
      manufacturer: manufacturer,
      warranty: warranty,
      returnPolicy: returnPolicy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      storeStatus: storeStatus,
      pendingChanges: pendingChanges,
      resell: resell,
      resellerInfo: resellerInfo,
      listingType: listingType ?? this.listingType,
      pricingUnit: pricingUnit ?? this.pricingUnit,
      attributes: attributes ?? this.attributes,
      installmentAvailable: installmentAvailable ?? this.installmentAvailable,
      transactionMode: transactionMode ?? this.transactionMode,
      storePin: storePin ?? this.storePin,
      chatEnabled: chatEnabled ?? this.chatEnabled,
    );
  }

  // Computed helpers
  int get discountPercentage {
    if (compareAtPrice != null && compareAtPrice! > basePrice) {
      return (((compareAtPrice! - basePrice) / compareAtPrice!) * 100).round();
    }
    return 0;
  }

  double? get profitMargin => (cost != null) ? basePrice - cost! : null;

  double? get profitMarginPercentage =>
      (cost != null && cost! > 0) ? ((basePrice - cost!) / cost!) * 100 : null;

  int get stock => hasVariants && variants.isNotEmpty
      ? variants.fold(0, (sum, v) => sum + v.stock)
      : totalStock;

  bool get isLowStock => stock <= lowStockThreshold;
  bool get isOutOfStock => stock <= 0;
  bool get isActive => status == 'active';
}
