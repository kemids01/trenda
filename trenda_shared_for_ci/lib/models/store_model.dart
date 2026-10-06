// trenda_shared/lib/models/store_model.dart
// Store model for vendor store management

class StoreModel {
  final String id;
  final String vendorId;
  final String storeName;
  final String slug;
  final String? tagline;
  final String? description;
  final String? email;
  final String? phone;
  final String? website;
  final String? logo;
  final String? banner;
  final String primaryCategory;
  final List<String> categories;
  final String businessType;
  final List<StoreLocation> locations;
  final StoreSettings settings;
  final StorePolicies policies;
  final StoreMetrics metrics;
  final List<SocialLink> socialLinks;
  final bool verified;
  final String status;
  final String availabilityMode;
  final String? accentColor;
  final String? municipality; // canonical VendorStore.mainAddress.cityMunicipality
  final double rating;
  final int reviewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Does this vendor want shoppers to see where the shop is? Default true —
  /// every store predates the field, and absent means shown.
  final bool showStorePin;

  StoreModel({
    required this.id,
    required this.vendorId,
    required this.storeName,
    required this.slug,
    this.tagline,
    this.description,
    this.email,
    this.phone,
    this.website,
    this.logo,
    this.banner,
    required this.primaryCategory,
    this.categories = const [],
    this.businessType = 'individual',
    this.locations = const [],
    StoreSettings? settings,
    StorePolicies? policies,
    StoreMetrics? metrics,
    this.socialLinks = const [],
    this.verified = false,
    this.status = 'active',
    this.availabilityMode = 'auto',
    this.accentColor,
    this.municipality,
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.showStorePin = true,
  }) : settings = settings ?? StoreSettings(),
       policies = policies ?? StorePolicies(),
       metrics = metrics ?? StoreMetrics();

  /// The store's municipality for municipality-scoped features (e.g. the ad lock).
  /// Prefers the canonical `mainAddress.cityMunicipality`, falls back to the first location's city.
  String? get storeMunicipality {
    if (municipality != null && municipality!.trim().isNotEmpty) return municipality;
    if (locations.isNotEmpty && locations.first.address.city.trim().isNotEmpty) {
      return locations.first.address.city;
    }
    return null;
  }

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    return StoreModel(
      id: json['_id'] ?? json['id'] ?? '',
      vendorId: json['vendorId'] ?? json['vendor'] ?? '',
      storeName: json['storeName'] ?? '',
      slug: json['slug'] ?? '',
      tagline: json['tagline'],
      description: json['description'],
      email: json['email'],
      phone: json['phone'],
      website: json['website'],
      logo: json['logo'],
      banner: json['banner'],
      primaryCategory: json['primaryCategory'] ?? 'Other',
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      businessType: json['businessType'] ?? 'individual',
      locations:
          (json['locations'] as List<dynamic>?)
              ?.map((e) => StoreLocation.fromJson(e))
              .toList() ??
          [],
      settings: json['settings'] != null
          ? StoreSettings.fromJson(json['settings'])
          : StoreSettings(),
      policies: json['policies'] != null
          ? StorePolicies.fromJson(json['policies'])
          : StorePolicies(),
      metrics: json['metrics'] != null
          ? StoreMetrics.fromJson(json['metrics'])
          : StoreMetrics(),
      socialLinks:
          (json['socialLinks'] as List<dynamic>?)
              ?.map((e) => SocialLink.fromJson(e))
              .toList() ??
          [],
      verified: json['verified'] ?? false,
      status: json['status'] ?? 'active',
      availabilityMode: (json['availability'] is Map ? json['availability']['mode'] : null) ?? 'auto',
      accentColor: (json['theme'] is Map ? json['theme']['accentColor'] : null),
      municipality: (json['mainAddress'] is Map ? json['mainAddress']['cityMunicipality'] : null),
      rating: (json['rating'] ?? 0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      showStorePin: json['showStorePin'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'storeName': storeName,
      'showStorePin': showStorePin,
      'tagline': tagline,
      'description': description,
      'email': email,
      'phone': phone,
      'website': website,
      'primaryCategory': primaryCategory,
      'categories': categories,
      'businessType': businessType,
      'locations': locations.map((e) => e.toJson()).toList(),
      'socialLinks': socialLinks.map((e) => e.toJson()).toList(),
      'availability': {'mode': availabilityMode},
      'theme': {'accentColor': accentColor ?? ''},
    };
  }

  StoreModel copyWith({
    String? storeName,
    String? tagline,
    String? description,
    String? email,
    String? phone,
    String? website,
    String? logo,
    String? banner,
    String? primaryCategory,
    List<String>? categories,
    List<StoreLocation>? locations,
    StoreSettings? settings,
    StorePolicies? policies,
    List<SocialLink>? socialLinks,
    String? availabilityMode,
    String? accentColor,
    bool? showStorePin,
  }) {
    return StoreModel(
      id: id,
      vendorId: vendorId,
      storeName: storeName ?? this.storeName,
      slug: slug,
      tagline: tagline ?? this.tagline,
      description: description ?? this.description,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      logo: logo ?? this.logo,
      banner: banner ?? this.banner,
      primaryCategory: primaryCategory ?? this.primaryCategory,
      categories: categories ?? this.categories,
      businessType: businessType,
      locations: locations ?? this.locations,
      settings: settings ?? this.settings,
      policies: policies ?? this.policies,
      metrics: metrics,
      socialLinks: socialLinks ?? this.socialLinks,
      verified: verified,
      status: status,
      availabilityMode: availabilityMode ?? this.availabilityMode,
      accentColor: accentColor ?? this.accentColor,
      municipality: municipality,
      rating: rating,
      reviewCount: reviewCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      showStorePin: showStorePin ?? this.showStorePin,
    );
  }
}

class StoreLocation {
  final String? id;
  final String name;
  final StoreAddress address;
  final GeoCoordinates? coordinates;
  final String? phone;
  final bool isDefault;
  final bool isActive;

  StoreLocation({
    this.id,
    this.name = 'Main',
    required this.address,
    this.coordinates,
    this.phone,
    this.isDefault = false,
    this.isActive = true,
  });

  factory StoreLocation.fromJson(Map<String, dynamic> json) {
    return StoreLocation(
      id: json['_id'] ?? json['id'],
      name: json['name'] ?? 'Main',
      address: StoreAddress.fromJson(json['address'] ?? {}),
      coordinates: json['coordinates'] != null
          ? GeoCoordinates.fromJson(json['coordinates'])
          : null,
      phone: json['phone'],
      isDefault: json['isDefault'] ?? false,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address.toJson(),
      if (coordinates != null) 'coordinates': coordinates!.toJson(),
      if (phone != null) 'phone': phone,
      'isDefault': isDefault,
      'isActive': isActive,
    };
  }
}

class StoreAddress {
  final String? street;
  final String? barangay;
  final String city;
  final String? province;
  final String?
  region; // ✅ Added for storing region (e.g., "Region II - Cagayan Valley")
  final String? postalCode;
  final String country;

  StoreAddress({
    this.street,
    this.barangay,
    required this.city,
    this.province,
    this.region,
    this.postalCode,
    this.country = 'Philippines',
  });

  factory StoreAddress.fromJson(Map<String, dynamic> json) {
    return StoreAddress(
      street: json['street'],
      barangay: json['barangay'],
      city: json['city'] ?? '',
      province: json['province'],
      region: json['region'],
      postalCode: json['postalCode'],
      country: json['country'] ?? 'Philippines',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (street != null) 'street': street,
      if (barangay != null) 'barangay': barangay,
      'city': city,
      if (province != null) 'province': province,
      if (region != null) 'region': region,
      if (postalCode != null) 'postalCode': postalCode,
      'country': country,
    };
  }

  String get fullAddress {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (barangay != null && barangay!.isNotEmpty) parts.add(barangay!);
    parts.add(city);
    if (province != null && province!.isNotEmpty) parts.add(province!);
    if (postalCode != null && postalCode!.isNotEmpty) parts.add(postalCode!);
    return parts.join(', ');
  }
}

class GeoCoordinates {
  final double longitude;
  final double latitude;

  GeoCoordinates({required this.longitude, required this.latitude});

  factory GeoCoordinates.fromJson(Map<String, dynamic> json) {
    // Handle GeoJSON format
    if (json['type'] == 'Point' && json['coordinates'] != null) {
      final coords = json['coordinates'] as List;
      return GeoCoordinates(
        longitude: (coords[0] as num).toDouble(),
        latitude: (coords[1] as num).toDouble(),
      );
    }
    return GeoCoordinates(
      longitude: (json['longitude'] ?? json['lng'] ?? 0).toDouble(),
      latitude: (json['latitude'] ?? json['lat'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': 'Point',
      'coordinates': [longitude, latitude],
    };
  }
}

class StoreSettings {
  final bool autoAcceptOrders;
  final int orderProcessingTime; // in hours
  final double minOrderAmount;
  final int? maxOrdersPerDay;
  final bool lowStockAlert;
  final int lowStockThreshold;
  final bool acceptReturns;
  final int returnPeriod; // in days
  final bool chargeTax;
  final double taxRate;

  StoreSettings({
    this.autoAcceptOrders = false,
    this.orderProcessingTime = 24,
    this.minOrderAmount = 0,
    this.maxOrdersPerDay,
    this.lowStockAlert = true,
    this.lowStockThreshold = 10,
    this.acceptReturns = true,
    this.returnPeriod = 7,
    this.chargeTax = false,
    this.taxRate = 0,
  });

  factory StoreSettings.fromJson(Map<String, dynamic> json) {
    return StoreSettings(
      autoAcceptOrders: json['autoAcceptOrders'] ?? false,
      orderProcessingTime: json['orderProcessingTime'] ?? 24,
      minOrderAmount: (json['minOrderAmount'] ?? 0).toDouble(),
      maxOrdersPerDay: json['maxOrdersPerDay'],
      lowStockAlert: json['lowStockAlert'] ?? true,
      lowStockThreshold: json['lowStockThreshold'] ?? 10,
      acceptReturns: json['acceptReturns'] ?? true,
      returnPeriod: json['returnPeriod'] ?? 7,
      chargeTax: json['chargeTax'] ?? false,
      taxRate: (json['taxRate'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoAcceptOrders': autoAcceptOrders,
      'orderProcessingTime': orderProcessingTime,
      'minOrderAmount': minOrderAmount,
      if (maxOrdersPerDay != null) 'maxOrdersPerDay': maxOrdersPerDay,
      'lowStockAlert': lowStockAlert,
      'lowStockThreshold': lowStockThreshold,
      'acceptReturns': acceptReturns,
      'returnPeriod': returnPeriod,
      'chargeTax': chargeTax,
      'taxRate': taxRate,
    };
  }
}

class StorePolicies {
  final String? returnPolicy;
  final String? shippingPolicy;
  final String? privacyPolicy;
  final String? termsOfService;

  StorePolicies({
    this.returnPolicy,
    this.shippingPolicy,
    this.privacyPolicy,
    this.termsOfService,
  });

  factory StorePolicies.fromJson(Map<String, dynamic> json) {
    return StorePolicies(
      returnPolicy: json['returnPolicy'],
      shippingPolicy: json['shippingPolicy'],
      privacyPolicy: json['privacyPolicy'],
      termsOfService: json['termsOfService'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (returnPolicy != null) 'returnPolicy': returnPolicy,
      if (shippingPolicy != null) 'shippingPolicy': shippingPolicy,
      if (privacyPolicy != null) 'privacyPolicy': privacyPolicy,
      if (termsOfService != null) 'termsOfService': termsOfService,
    };
  }
}

class StoreMetrics {
  final int totalProducts;
  final int totalOrders;
  final double totalRevenue;
  final int totalCustomers;

  StoreMetrics({
    this.totalProducts = 0,
    this.totalOrders = 0,
    this.totalRevenue = 0,
    this.totalCustomers = 0,
  });

  factory StoreMetrics.fromJson(Map<String, dynamic> json) {
    return StoreMetrics(
      totalProducts: json['totalProducts'] ?? 0,
      totalOrders: json['totalOrders'] ?? 0,
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      totalCustomers: json['totalCustomers'] ?? 0,
    );
  }
}

class SocialLink {
  final String platform;
  final String url;

  SocialLink({required this.platform, required this.url});

  factory SocialLink.fromJson(Map<String, dynamic> json) {
    return SocialLink(platform: json['platform'] ?? '', url: json['url'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'platform': platform, 'url': url};
  }
}

class StoreStaffMember {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String? avatar;
  final String role;
  final List<String> permissions;
  final String status;
  final DateTime addedAt;
  final DateTime? lastActive;

  StoreStaffMember({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.avatar,
    required this.role,
    required this.permissions,
    this.status = 'active',
    required this.addedAt,
    this.lastActive,
  });

  factory StoreStaffMember.fromJson(Map<String, dynamic> json) {
    // Backend returns 'user' as populated object with {name, email, photoUrl}
    // or as a string ID if not populated
    final userField = json['user'];
    String userId = '';
    String name = '';
    String email = '';
    String? avatar;

    if (userField is Map<String, dynamic>) {
      // Populated user object
      userId = userField['_id'] ?? userField['id'] ?? '';
      name = userField['name'] ?? 'Unknown';
      email = userField['email'] ?? '';
      avatar = userField['photoUrl'] ?? userField['avatar'];
    } else if (userField is String) {
      // Just the user ID
      userId = userField;
      name = json['name'] ?? 'Unknown';
      email = json['email'] ?? '';
      avatar = json['avatar'];
    } else {
      // Fallback to direct fields
      userId = json['userId'] ?? '';
      name = json['name'] ?? 'Unknown';
      email = json['email'] ?? '';
      avatar = json['avatar'];
    }

    return StoreStaffMember(
      id: json['_id'] ?? json['id'] ?? '',
      userId: userId,
      name: name,
      email: email,
      avatar: avatar,
      role: json['role'] ?? 'staff',
      permissions:
          (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: json['status'] ?? 'active',
      addedAt: DateTime.tryParse(json['addedAt'] ?? '') ?? DateTime.now(),
      lastActive: json['lastActive'] != null
          ? DateTime.tryParse(json['lastActive'])
          : null,
    );
  }

  static const List<String> availableRoles = [
    'manager',
    'staff',
    'cashier',
    'inventory_manager',
  ];

  static const List<String> availablePermissions = [
    'manage_products',
    'manage_orders',
    'manage_inventory',
    'view_reports',
    'manage_staff',
    'manage_settings',
    'process_refunds',
    'manage_promotions',
  ];
}

class StoreHours {
  final String dayOfWeek;
  final bool isOpen;
  final String? openTime;
  final String? closeTime;
  final List<BreakTime> breaks;

  StoreHours({
    required this.dayOfWeek,
    this.isOpen = true,
    this.openTime,
    this.closeTime,
    this.breaks = const [],
  });

  factory StoreHours.fromJson(Map<String, dynamic> json) {
    return StoreHours(
      dayOfWeek: json['dayOfWeek'] ?? '',
      isOpen: json['isOpen'] ?? true,
      openTime: json['openTime'],
      closeTime: json['closeTime'],
      breaks:
          (json['breaks'] as List<dynamic>?)
              ?.map((e) => BreakTime.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayOfWeek': dayOfWeek,
      'isOpen': isOpen,
      if (openTime != null) 'openTime': openTime,
      if (closeTime != null) 'closeTime': closeTime,
      'breaks': breaks.map((e) => e.toJson()).toList(),
    };
  }
}

class BreakTime {
  final String startTime;
  final String endTime;

  BreakTime({required this.startTime, required this.endTime});

  factory BreakTime.fromJson(Map<String, dynamic> json) {
    return BreakTime(
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'startTime': startTime, 'endTime': endTime};
  }
}
