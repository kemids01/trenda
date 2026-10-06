// trenda_shared/lib/models/promotion_model.dart
// Promotion model for vendor promotions management

class PromotionModel {
  final String id;
  final String vendorId;
  final String title;
  final String? description;
  final PromotionType type;
  final double value;
  final DateTime startDate;
  final DateTime endDate;
  final double? minPurchaseAmount;
  final double? maxDiscountAmount;
  final int? usageLimit;
  final int usageCount;
  final List<String> applicableProducts;
  final List<String> applicableCategories;
  final String? couponCode;
  final PromotionStatus status;
  final PromotionAnalytics? analytics;
  final DateTime createdAt;
  final DateTime updatedAt;

  PromotionModel({
    required this.id,
    required this.vendorId,
    required this.title,
    this.description,
    required this.type,
    required this.value,
    required this.startDate,
    required this.endDate,
    this.minPurchaseAmount,
    this.maxDiscountAmount,
    this.usageLimit,
    this.usageCount = 0,
    this.applicableProducts = const [],
    this.applicableCategories = const [],
    this.couponCode,
    this.status = PromotionStatus.active,
    this.analytics,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    return PromotionModel(
      id: json['_id'] ?? json['id'] ?? '',
      vendorId: json['vendorId'] ?? json['vendor'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      type: PromotionType.fromString(json['type'] ?? 'percentage'),
      value: (json['value'] ?? 0).toDouble(),
      startDate: DateTime.tryParse(json['startDate'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate'] ?? '') ??
          DateTime.now().add(const Duration(days: 7)),
      minPurchaseAmount: json['minPurchaseAmount']?.toDouble(),
      maxDiscountAmount: json['maxDiscountAmount']?.toDouble(),
      usageLimit: json['usageLimit'],
      usageCount: json['usageCount'] ?? 0,
      applicableProducts: (json['applicableProducts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      applicableCategories: (json['applicableCategories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      couponCode: json['couponCode'],
      status: PromotionStatus.fromString(json['status'] ?? 'active'),
      analytics: json['analytics'] != null
          ? PromotionAnalytics.fromJson(json['analytics'])
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'type': type.value,
      'value': value,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      if (minPurchaseAmount != null) 'minPurchaseAmount': minPurchaseAmount,
      if (maxDiscountAmount != null) 'maxDiscountAmount': maxDiscountAmount,
      if (usageLimit != null) 'usageLimit': usageLimit,
      if (applicableProducts.isNotEmpty) 'applicableProducts': applicableProducts,
      if (applicableCategories.isNotEmpty) 'applicableCategories': applicableCategories,
      if (couponCode != null) 'couponCode': couponCode,
    };
  }

  bool get isActive => status == PromotionStatus.active;
  bool get isExpired => DateTime.now().isAfter(endDate);
  bool get isScheduled => DateTime.now().isBefore(startDate);
  bool get isRunning => !isExpired && !isScheduled && isActive;

  int get remainingUsage => usageLimit != null ? usageLimit! - usageCount : -1;
  bool get hasUnlimitedUsage => usageLimit == null;

  double get usagePercentage {
    if (usageLimit == null || usageLimit == 0) return 0;
    return (usageCount / usageLimit!) * 100;
  }

  PromotionModel copyWith({
    String? title,
    String? description,
    PromotionType? type,
    double? value,
    DateTime? startDate,
    DateTime? endDate,
    double? minPurchaseAmount,
    double? maxDiscountAmount,
    int? usageLimit,
    List<String>? applicableProducts,
    List<String>? applicableCategories,
    String? couponCode,
    PromotionStatus? status,
  }) {
    return PromotionModel(
      id: id,
      vendorId: vendorId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      value: value ?? this.value,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      minPurchaseAmount: minPurchaseAmount ?? this.minPurchaseAmount,
      maxDiscountAmount: maxDiscountAmount ?? this.maxDiscountAmount,
      usageLimit: usageLimit ?? this.usageLimit,
      usageCount: usageCount,
      applicableProducts: applicableProducts ?? this.applicableProducts,
      applicableCategories: applicableCategories ?? this.applicableCategories,
      couponCode: couponCode ?? this.couponCode,
      status: status ?? this.status,
      analytics: analytics,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

enum PromotionType {
  percentage('percentage'),
  fixed('fixed'),
  buyXGetY('buy_x_get_y'),
  freeShipping('free_shipping');

  final String value;
  const PromotionType(this.value);

  static PromotionType fromString(String value) {
    return PromotionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PromotionType.percentage,
    );
  }

  String get displayName {
    switch (this) {
      case PromotionType.percentage:
        return 'Percentage Discount';
      case PromotionType.fixed:
        return 'Fixed Amount';
      case PromotionType.buyXGetY:
        return 'Buy X Get Y';
      case PromotionType.freeShipping:
        return 'Free Shipping';
    }
  }
}

enum PromotionStatus {
  active('active'),
  inactive('inactive'),
  scheduled('scheduled'),
  expired('expired');

  final String value;
  const PromotionStatus(this.value);

  static PromotionStatus fromString(String value) {
    return PromotionStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PromotionStatus.active,
    );
  }
}

class PromotionAnalytics {
  final int totalOrders;
  final double totalRevenue;
  final double totalDiscount;
  final int uniqueCustomers;
  final double averageOrderValue;
  final double conversionRate;
  final List<DailyUsage> dailyUsage;

  PromotionAnalytics({
    this.totalOrders = 0,
    this.totalRevenue = 0,
    this.totalDiscount = 0,
    this.uniqueCustomers = 0,
    this.averageOrderValue = 0,
    this.conversionRate = 0,
    this.dailyUsage = const [],
  });

  factory PromotionAnalytics.fromJson(Map<String, dynamic> json) {
    return PromotionAnalytics(
      totalOrders: json['totalOrders'] ?? 0,
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      totalDiscount: (json['totalDiscount'] ?? 0).toDouble(),
      uniqueCustomers: json['uniqueCustomers'] ?? 0,
      averageOrderValue: (json['averageOrderValue'] ?? 0).toDouble(),
      conversionRate: (json['conversionRate'] ?? 0).toDouble(),
      dailyUsage: (json['dailyUsage'] as List<dynamic>?)
              ?.map((e) => DailyUsage.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class DailyUsage {
  final DateTime date;
  final int count;
  final double revenue;

  DailyUsage({
    required this.date,
    required this.count,
    required this.revenue,
  });

  factory DailyUsage.fromJson(Map<String, dynamic> json) {
    return DailyUsage(
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      count: json['count'] ?? 0,
      revenue: (json['revenue'] ?? 0).toDouble(),
    );
  }
}

class PromotionStatistics {
  final int totalPromotions;
  final int activePromotions;
  final int scheduledPromotions;
  final int expiredPromotions;
  final double totalDiscountGiven;
  final double totalRevenueGenerated;
  final int totalOrdersWithPromo;
  final PromotionModel? topPerforming;

  PromotionStatistics({
    this.totalPromotions = 0,
    this.activePromotions = 0,
    this.scheduledPromotions = 0,
    this.expiredPromotions = 0,
    this.totalDiscountGiven = 0,
    this.totalRevenueGenerated = 0,
    this.totalOrdersWithPromo = 0,
    this.topPerforming,
  });

  factory PromotionStatistics.fromJson(Map<String, dynamic> json) {
    return PromotionStatistics(
      totalPromotions: json['totalPromotions'] ?? 0,
      activePromotions: json['activePromotions'] ?? 0,
      scheduledPromotions: json['scheduledPromotions'] ?? 0,
      expiredPromotions: json['expiredPromotions'] ?? 0,
      totalDiscountGiven: (json['totalDiscountGiven'] ?? 0).toDouble(),
      totalRevenueGenerated: (json['totalRevenueGenerated'] ?? 0).toDouble(),
      totalOrdersWithPromo: json['totalOrdersWithPromo'] ?? 0,
      topPerforming: json['topPerforming'] != null
          ? PromotionModel.fromJson(json['topPerforming'])
          : null,
    );
  }
}
