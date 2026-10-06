// trenda_shared/lib/models/dashboard_model.dart
// Dashboard model for vendor dashboard

// Helper function to safely parse int values
int _parseInt(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

// Helper function to safely parse double values
double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}

class DashboardModel {
  final StoreInfo storeInfo;
  final DashboardOverview overview;
  final ProductMetrics products;
  final OrderMetrics orders;
  final PerformanceMetrics performance;
  final List<DashboardAlert> alerts;
  final List<ActionItem> actionItems;
  final List<ActivityItem> recentActivity;
  final DashboardCharts charts;
  final ResellerMetrics reseller; // ✅ NEW: Reseller earnings

  DashboardModel({
    required this.storeInfo,
    required this.overview,
    required this.products,
    required this.orders,
    required this.performance,
    this.alerts = const [],
    this.actionItems = const [],
    this.recentActivity = const [],
    required this.charts,
    required this.reseller, // ✅ NEW
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    // Safely parse lists that might come as objects from backend
    List<DashboardAlert> parseAlerts(dynamic data) {
      if (data == null) return [];
      if (data is List)
        return data.map((e) => DashboardAlert.fromJson(e)).toList();
      return [];
    }

    List<ActionItem> parseActionItems(dynamic data) {
      if (data == null) return [];
      if (data is List) return data.map((e) => ActionItem.fromJson(e)).toList();
      return [];
    }

    List<ActivityItem> parseActivity(dynamic data) {
      if (data == null) return [];
      if (data is List)
        return data.map((e) => ActivityItem.fromJson(e)).toList();
      return [];
    }

    // Performance: Backend sends today in 'overview.today', not 'performance.today'
    // So we need to build performance from overview data
    final overview = json['overview'] ?? {};
    final todayData = overview['today'] ?? {};
    final periodData = overview['period'] ?? {};

    return DashboardModel(
      storeInfo: StoreInfo.fromJson(json['storeInfo'] ?? json['store'] ?? {}),
      overview: DashboardOverview.fromJson(overview),
      products: ProductMetrics.fromJson(json['products'] ?? {}),
      orders: OrderMetrics.fromJson(json['orders'] ?? {}),
      performance: PerformanceMetrics(
        today: PeriodPerformance(
          revenue: _parseDouble(todayData['revenue']),
          orders: _parseInt(todayData['orders']),
          growth: null,
        ),
        week: PeriodPerformance(
          revenue: _parseDouble(periodData['totalRevenue']),
          orders: _parseInt(periodData['totalOrders']),
          growth: null,
        ),
        month: PeriodPerformance.empty(),
      ),
      alerts: parseAlerts(json['alerts']),
      actionItems: parseActionItems(json['actionItems']),
      recentActivity: parseActivity(json['recentActivity']),
      charts: DashboardCharts.fromJson(json['charts'] ?? json['revenue'] ?? {}),
      reseller: ResellerMetrics.fromJson(json['reseller'] ?? {}), // ✅ NEW
    );
  }

  factory DashboardModel.empty() {
    return DashboardModel(
      storeInfo: StoreInfo.empty(),
      overview: DashboardOverview.empty(),
      products: ProductMetrics.empty(),
      orders: OrderMetrics.empty(),
      performance: PerformanceMetrics.empty(),
      alerts: [],
      actionItems: [],
      recentActivity: [],
      charts: DashboardCharts.empty(),
      reseller: ResellerMetrics.empty(), // ✅ NEW
    );
  }
}

class StoreInfo {
  final String id;
  final String name;
  final String? logo;
  final bool verified;
  final double rating;

  StoreInfo({
    required this.id,
    required this.name,
    this.logo,
    this.verified = false,
    this.rating = 0,
  });

  factory StoreInfo.fromJson(Map<String, dynamic> json) {
    return StoreInfo(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      logo: json['logo'],
      verified: json['verified'] ?? false,
      rating: (json['rating'] ?? 0).toDouble(),
    );
  }

  factory StoreInfo.empty() => StoreInfo(id: '', name: '');
}

class DashboardOverview {
  final double revenue;
  final int totalOrders;
  final int totalCustomers;
  final double averageOrderValue;
  final double netIncome;

  DashboardOverview({
    this.revenue = 0,
    this.totalOrders = 0,
    this.totalCustomers = 0,
    this.averageOrderValue = 0,
    this.netIncome = 0,
  });

  factory DashboardOverview.fromJson(Map<String, dynamic> json) {
    return DashboardOverview(
      revenue: _parseDouble(json['revenue']),
      totalOrders: _parseInt(json['orders']),
      totalCustomers: _parseInt(json['customers']),
      averageOrderValue: _parseDouble(json['averageOrderValue']),
      netIncome: _parseDouble(json['netIncome']),
    );
  }

  factory DashboardOverview.empty() => DashboardOverview();
}

class ProductMetrics {
  final int total;
  final int active;
  final int lowStock;
  final int outOfStock;

  ProductMetrics({
    this.total = 0,
    this.active = 0,
    this.lowStock = 0,
    this.outOfStock = 0,
  });

  factory ProductMetrics.fromJson(Map<String, dynamic> json) {
    return ProductMetrics(
      total: _parseInt(json['total']),
      active: _parseInt(json['active']),
      lowStock: _parseInt(json['lowStock']),
      outOfStock: _parseInt(json['outOfStock']),
    );
  }

  factory ProductMetrics.empty() => ProductMetrics();
}

class OrderMetrics {
  final int total;
  final int pending;
  final int processing;
  final int completed;
  final int cancelled;
  final int returns;

  OrderMetrics({
    this.total = 0,
    this.pending = 0,
    this.processing = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.returns = 0,
  });

  factory OrderMetrics.fromJson(Map<String, dynamic> json) {
    return OrderMetrics(
      total: _parseInt(json['total']),
      pending: _parseInt(json['pending']),
      processing: _parseInt(json['processing']),
      completed: _parseInt(json['completed']),
      cancelled: _parseInt(json['cancelled']),
      returns: _parseInt(json['returns']),
    );
  }

  factory OrderMetrics.empty() => OrderMetrics();
}

class PerformanceMetrics {
  final PeriodPerformance today;
  final PeriodPerformance week;
  final PeriodPerformance month;

  PerformanceMetrics({
    required this.today,
    required this.week,
    required this.month,
  });

  factory PerformanceMetrics.fromJson(Map<String, dynamic> json) {
    return PerformanceMetrics(
      today: PeriodPerformance.fromJson(json['today'] ?? {}),
      week: PeriodPerformance.fromJson(json['week'] ?? {}),
      month: PeriodPerformance.fromJson(json['month'] ?? {}),
    );
  }

  factory PerformanceMetrics.empty() => PerformanceMetrics(
    today: PeriodPerformance.empty(),
    week: PeriodPerformance.empty(),
    month: PeriodPerformance.empty(),
  );
}

class PeriodPerformance {
  final double revenue;
  final int orders;
  final double? growth;

  PeriodPerformance({this.revenue = 0, this.orders = 0, this.growth});

  factory PeriodPerformance.fromJson(Map<String, dynamic> json) {
    return PeriodPerformance(
      revenue: _parseDouble(json['revenue']),
      orders: _parseInt(json['orders']),
      growth: json['growth'] != null ? _parseDouble(json['growth']) : null,
    );
  }

  factory PeriodPerformance.empty() => PeriodPerformance();
}

class DashboardAlert {
  final String type; // 'low_stock', 'new_order', 'return_request'
  final String message;
  final String severity; // 'info', 'warning', 'critical'
  final String? link;
  final DateTime timestamp;

  DashboardAlert({
    required this.type,
    required this.message,
    this.severity = 'info',
    this.link,
    required this.timestamp,
  });

  factory DashboardAlert.fromJson(Map<String, dynamic> json) {
    return DashboardAlert(
      type: json['type'] ?? '',
      message: json['message'] ?? '',
      severity: json['severity'] ?? 'info',
      link: json['link'],
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isCritical => severity == 'critical';
  bool get isWarning => severity == 'warning';
}

class ActionItem {
  final String id;
  final String title;
  final String description;
  final String type;
  final String actionLabel;
  final String actionLink;
  final int priority;

  ActionItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.actionLabel,
    required this.actionLink,
    this.priority = 0,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      actionLabel: json['actionLabel']?.toString() ?? 'View',
      actionLink: json['actionLink']?.toString() ?? '',
      priority: _parseInt(json['priority']),
    );
  }
}

class ActivityItem {
  final String id;
  final String type;
  final String title;
  final String? subtitle;
  final DateTime timestamp;
  final String? status;
  final double? amount;
  final String? image;

  ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.timestamp,
    this.status,
    this.amount,
    this.image,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      status: json['status'],
      amount: json['amount']?.toDouble(),
      image: json['image'],
    );
  }
}

class DashboardCharts {
  final List<ChartData> revenue;
  final List<ChartData> orders;

  DashboardCharts({this.revenue = const [], this.orders = const []});

  factory DashboardCharts.fromJson(Map<String, dynamic> json) {
    return DashboardCharts(
      revenue:
          (json['revenue'] as List<dynamic>?)
              ?.map((e) => ChartData.fromJson(e))
              .toList() ??
          [],
      orders:
          (json['orders'] as List<dynamic>?)
              ?.map((e) => ChartData.fromJson(e))
              .toList() ??
          [],
    );
  }

  factory DashboardCharts.empty() => DashboardCharts();
}

class ChartData {
  final DateTime date;
  final double value;
  final String label;

  ChartData({required this.date, required this.value, required this.label});

  factory ChartData.fromJson(Map<String, dynamic> json) {
    return ChartData(
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      value: (json['value'] ?? 0).toDouble(),
      label: json['label'] ?? '',
    );
  }
}

// ============================================================================
// RESELLER METRICS - NEW
// ============================================================================

class ResellerMetrics {
  final bool enabled;
  final double balance;
  final double pendingBalance;
  final double totalEarned;
  final double totalWithdrawn;
  final double thisMonth;
  final int totalResales;
  final List<ResellerCommission> recentCommissions;

  ResellerMetrics({
    required this.enabled,
    required this.balance,
    required this.pendingBalance,
    required this.totalEarned,
    required this.totalWithdrawn,
    required this.thisMonth,
    required this.totalResales,
    required this.recentCommissions,
  });

  factory ResellerMetrics.fromJson(Map<String, dynamic> json) {
    return ResellerMetrics(
      enabled: json['enabled'] ?? false,
      balance: _parseDouble(json['balance']),
      pendingBalance: _parseDouble(json['pendingBalance']),
      totalEarned: _parseDouble(json['totalEarned']),
      totalWithdrawn: _parseDouble(json['totalWithdrawn']),
      thisMonth: _parseDouble(json['thisMonth']),
      totalResales: _parseInt(json['totalResales']),
      recentCommissions:
          (json['recentCommissions'] as List?)
              ?.map((e) => ResellerCommission.fromJson(e))
              .toList() ??
          [],
    );
  }

  factory ResellerMetrics.empty() {
    return ResellerMetrics(
      enabled: false,
      balance: 0,
      pendingBalance: 0,
      totalEarned: 0,
      totalWithdrawn: 0,
      thisMonth: 0,
      totalResales: 0,
      recentCommissions: [],
    );
  }
}

class ResellerCommission {
  final String id;
  final double amount;
  final String productName;
  final String orderNumber;
  final double commissionPercent;
  final DateTime? date;

  ResellerCommission({
    required this.id,
    required this.amount,
    required this.productName,
    required this.orderNumber,
    required this.commissionPercent,
    this.date,
  });

  factory ResellerCommission.fromJson(Map<String, dynamic> json) {
    return ResellerCommission(
      id: json['id']?.toString() ?? '',
      amount: _parseDouble(json['amount']),
      productName: json['productName'] ?? 'Product',
      orderNumber: json['orderNumber'] ?? '',
      commissionPercent: _parseDouble(json['commissionPercent']),
      date: DateTime.tryParse(json['date'] ?? ''),
    );
  }
}
