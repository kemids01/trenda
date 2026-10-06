// trenda_shared/lib/models/inventory_model.dart
// Inventory management models

/// Inventory log entry for tracking stock changes
class InventoryLog {
  final String id;
  final String productId;
  final String productName;
  final String? variantId;
  final String? variantName;
  final String type; // adjustment, sale, return, restock, damage, etc.
  final int quantityBefore;
  final int quantityAfter;
  final int change;
  final String? reason;
  final String? reference; // order ID, etc.
  final String? performedBy;
  final DateTime createdAt;

  InventoryLog({
    required this.id,
    required this.productId,
    required this.productName,
    this.variantId,
    this.variantName,
    required this.type,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.change,
    this.reason,
    this.reference,
    this.performedBy,
    required this.createdAt,
  });

  factory InventoryLog.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    String productId;
    String productName;

    if (product is Map<String, dynamic>) {
      productId = product['_id'] ?? product['id'] ?? '';
      productName = product['name'] ?? '';
    } else {
      productId = product?.toString() ?? json['productId'] ?? '';
      productName = json['productName'] ?? '';
    }

    return InventoryLog(
      id: json['_id'] ?? json['id'] ?? '',
      productId: productId,
      productName: productName,
      variantId: json['variantId'],
      variantName: json['variantName'],
      type: json['type'] ?? json['changeType'] ?? 'adjustment',
      quantityBefore: json['quantityBefore'] ?? json['previousQuantity'] ?? 0,
      quantityAfter: json['quantityAfter'] ?? json['newQuantity'] ?? 0,
      change: json['change'] ?? json['quantityChange'] ?? 0,
      reason: json['reason'] ?? json['notes'],
      reference: json['reference'] ?? json['orderId'],
      performedBy: json['performedBy'] ?? json['updatedBy'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

/// Comprehensive inventory alerts
class InventoryAlertsData {
  final List<InventoryAlertItem> outOfStock;
  final List<InventoryAlertItem> lowStock;
  final List<InventoryAlertItem> criticalStock;
  final List<InventoryAlertItem> expiringStock;
  final int totalAlerts;
  final DateTime generatedAt;

  InventoryAlertsData({
    required this.outOfStock,
    required this.lowStock,
    required this.criticalStock,
    this.expiringStock = const [],
    required this.generatedAt,
  }) : totalAlerts =
           outOfStock.length +
           lowStock.length +
           criticalStock.length +
           expiringStock.length;

  factory InventoryAlertsData.fromJson(Map<String, dynamic> json) {
    // Backend returns nested structure: {alerts: {critical: [...], warning: [...], etc}, summary: {...}}
    final alerts = json['alerts'] as Map<String, dynamic>? ?? json;

    return InventoryAlertsData(
      outOfStock:
          (alerts['critical'] as List? ?? json['outOfStock'] as List? ?? [])
              .map((e) => InventoryAlertItem.fromJson(e))
              .toList(),
      lowStock: (alerts['warning'] as List? ?? json['lowStock'] as List? ?? [])
          .map((e) => InventoryAlertItem.fromJson(e))
          .toList(),
      criticalStock: (json['criticalStock'] as List? ?? [])
          .map((e) => InventoryAlertItem.fromJson(e))
          .toList(),
      expiringStock:
          (alerts['expiring'] as List? ?? json['expiringStock'] as List? ?? [])
              .map((e) => InventoryAlertItem.fromJson(e))
              .toList(),
      generatedAt: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : (json['generatedAt'] != null
                ? DateTime.parse(json['generatedAt'])
                : DateTime.now()),
    );
  }

  bool get hasAlerts => totalAlerts > 0;
  bool get hasCriticalAlerts =>
      outOfStock.isNotEmpty || criticalStock.isNotEmpty;
}

/// Individual alert item
class InventoryAlertItem {
  final String productId;
  final String productName;
  final String? variantId;
  final String? variantName;
  final String? imageUrl;
  final int currentStock;
  final int threshold;
  final String severity; // out_of_stock, critical, low, warning
  final int? daysUntilStockout;
  final DateTime? expiryDate;

  InventoryAlertItem({
    required this.productId,
    required this.productName,
    this.variantId,
    this.variantName,
    this.imageUrl,
    required this.currentStock,
    required this.threshold,
    required this.severity,
    this.daysUntilStockout,
    this.expiryDate,
  });

  factory InventoryAlertItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    String productId;
    String productName;
    String? imageUrl;

    if (product is Map<String, dynamic>) {
      productId = product['_id'] ?? product['id'] ?? '';
      productName = product['name'] ?? '';
      final images = product['images'] as List?;
      imageUrl = images?.isNotEmpty == true ? images!.first.toString() : null;
    } else if (json['_id'] != null) {
      // Backend returns alert with product data at root level
      productId = json['_id']?.toString() ?? '';
      productName = json['name'] ?? '';
      final images = json['images'] as List?;
      imageUrl = images?.isNotEmpty == true ? images!.first.toString() : null;
    } else {
      productId = product?.toString() ?? json['productId'] ?? '';
      productName = json['productName'] ?? '';
      imageUrl = json['imageUrl'];
    }

    return InventoryAlertItem(
      productId: productId,
      productName: productName,
      variantId: json['variantId'],
      variantName: json['variantName'],
      imageUrl: imageUrl,
      currentStock:
          json['currentStock'] ?? json['stock'] ?? json['totalStock'] ?? 0,
      threshold: json['threshold'] ?? json['lowStockThreshold'] ?? 10,
      severity: json['severity'] ?? _calculateSeverity(json),
      daysUntilStockout: json['daysUntilStockout'],
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'].toString())
          : null,
    );
  }

  static String _calculateSeverity(Map<String, dynamic> json) {
    final stock = json['currentStock'] ?? json['stock'] ?? 0;
    if (stock == 0) return 'out_of_stock';
    final threshold = json['threshold'] ?? 10;
    if (stock <= threshold / 2) return 'critical';
    if (stock <= threshold) return 'low';
    return 'warning';
  }
}

/// Inventory statistics
class InventoryStats {
  final int totalProducts;
  final int totalStock;
  final double totalValue;
  final int outOfStockCount;
  final int lowStockCount;
  final int criticalStockCount;
  final double avgTurnoverDays;
  final Map<String, int> stockByCategory;

  InventoryStats({
    required this.totalProducts,
    required this.totalStock,
    required this.totalValue,
    required this.outOfStockCount,
    required this.lowStockCount,
    required this.criticalStockCount,
    this.avgTurnoverDays = 0,
    this.stockByCategory = const {},
  });

  factory InventoryStats.fromJson(Map<String, dynamic> json) {
    // Backend returns nested structure: {inventory: {...}, movements: {...}}
    final inventory = json['inventory'] as Map<String, dynamic>? ?? json;
    final stockHealth = inventory['stockHealth'] as Map<String, dynamic>?;

    return InventoryStats(
      totalProducts: inventory['totalProducts'] ?? json['totalProducts'] ?? 0,
      totalStock:
          inventory['totalStock'] ??
          json['totalStock'] ??
          json['totalUnits'] ??
          0,
      totalValue:
          (inventory['totalValue'] ??
                  json['totalValue'] ??
                  json['inventoryValue'] ??
                  0)
              .toDouble(),
      outOfStockCount:
          stockHealth?['critical'] ??
          inventory['outOfStockCount'] ??
          json['outOfStockCount'] ??
          json['outOfStock'] ??
          0,
      lowStockCount:
          stockHealth?['warning'] ??
          inventory['lowStockCount'] ??
          json['lowStockCount'] ??
          json['lowStock'] ??
          0,
      criticalStockCount:
          stockHealth?['critical'] ??
          inventory['criticalStockCount'] ??
          json['criticalStockCount'] ??
          json['criticalStock'] ??
          0,
      avgTurnoverDays:
          (inventory['avgTurnoverDays'] ?? json['avgTurnoverDays'] ?? 0)
              .toDouble(),
      stockByCategory: Map<String, int>.from(
        inventory['stockByCategory'] ?? json['stockByCategory'] ?? {},
      ),
    );
  }
}

/// Inventory forecast
class InventoryForecast {
  final String productId;
  final String productName;
  final int currentStock;
  final double avgDailySales;
  final int daysUntilStockout;
  final int recommendedReorderQty;
  final DateTime? recommendedReorderDate;
  final List<ForecastDataPoint> forecast;

  InventoryForecast({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.avgDailySales,
    required this.daysUntilStockout,
    required this.recommendedReorderQty,
    this.recommendedReorderDate,
    this.forecast = const [],
  });

  factory InventoryForecast.fromJson(Map<String, dynamic> json) {
    return InventoryForecast(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      currentStock: json['currentStock'] ?? 0,
      avgDailySales: (json['avgDailySales'] ?? json['averageDailySales'] ?? 0)
          .toDouble(),
      daysUntilStockout: json['daysUntilStockout'] ?? json['daysOfStock'] ?? 0,
      recommendedReorderQty:
          json['recommendedReorderQty'] ??
          json['suggestedReorderQuantity'] ??
          0,
      recommendedReorderDate: json['recommendedReorderDate'] != null
          ? DateTime.tryParse(json['recommendedReorderDate'])
          : null,
      forecast: (json['forecast'] as List? ?? [])
          .map((e) => ForecastDataPoint.fromJson(e))
          .toList(),
    );
  }
}

/// Forecast data point
class ForecastDataPoint {
  final DateTime date;
  final int predictedStock;
  final double confidence;

  ForecastDataPoint({
    required this.date,
    required this.predictedStock,
    required this.confidence,
  });

  factory ForecastDataPoint.fromJson(Map<String, dynamic> json) {
    return ForecastDataPoint(
      date: DateTime.parse(json['date']),
      predictedStock: json['predictedStock'] ?? json['stock'] ?? 0,
      confidence: (json['confidence'] ?? 0.8).toDouble(),
    );
  }
}

/// Auto-reorder rule
class AutoReorderRule {
  final String productId;
  final bool enabled;
  final int reorderPoint;
  final int reorderQuantity;
  final String? preferredSupplier;
  final bool autoApprove;

  AutoReorderRule({
    required this.productId,
    required this.enabled,
    required this.reorderPoint,
    required this.reorderQuantity,
    this.preferredSupplier,
    this.autoApprove = false,
  });

  factory AutoReorderRule.fromJson(Map<String, dynamic> json) {
    return AutoReorderRule(
      productId: json['productId'] ?? '',
      enabled: json['enabled'] ?? json['autoReorder'] ?? false,
      reorderPoint: json['reorderPoint'] ?? json['threshold'] ?? 10,
      reorderQuantity: json['reorderQuantity'] ?? json['quantity'] ?? 50,
      preferredSupplier: json['preferredSupplier'],
      autoApprove: json['autoApprove'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'enabled': enabled,
    'reorderPoint': reorderPoint,
    'reorderQuantity': reorderQuantity,
    if (preferredSupplier != null) 'preferredSupplier': preferredSupplier,
    'autoApprove': autoApprove,
  };
}

/// Inventory value report
class InventoryValueReport {
  final double totalValue;
  final double costOfGoodsSold;
  final double grossProfit;
  final List<CategoryValue> valueByCategory;
  final List<ProductValue> topProducts;
  final DateTime generatedAt;

  InventoryValueReport({
    required this.totalValue,
    required this.costOfGoodsSold,
    required this.grossProfit,
    this.valueByCategory = const [],
    this.topProducts = const [],
    required this.generatedAt,
  });

  factory InventoryValueReport.fromJson(Map<String, dynamic> json) {
    return InventoryValueReport(
      totalValue: (json['totalValue'] ?? 0).toDouble(),
      costOfGoodsSold: (json['costOfGoodsSold'] ?? json['cogs'] ?? 0)
          .toDouble(),
      grossProfit: (json['grossProfit'] ?? 0).toDouble(),
      valueByCategory: (json['valueByCategory'] as List? ?? [])
          .map((e) => CategoryValue.fromJson(e))
          .toList(),
      topProducts: (json['topProducts'] as List? ?? [])
          .map((e) => ProductValue.fromJson(e))
          .toList(),
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'])
          : DateTime.now(),
    );
  }
}

class CategoryValue {
  final String category;
  final double value;
  final int productCount;

  CategoryValue({
    required this.category,
    required this.value,
    required this.productCount,
  });

  factory CategoryValue.fromJson(Map<String, dynamic> json) {
    return CategoryValue(
      category: json['category'] ?? json['_id'] ?? '',
      value: (json['value'] ?? json['totalValue'] ?? 0).toDouble(),
      productCount: json['productCount'] ?? json['count'] ?? 0,
    );
  }
}

class ProductValue {
  final String productId;
  final String name;
  final int stock;
  final double value;

  ProductValue({
    required this.productId,
    required this.name,
    required this.stock,
    required this.value,
  });

  factory ProductValue.fromJson(Map<String, dynamic> json) {
    return ProductValue(
      productId: json['productId'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      stock: json['stock'] ?? json['totalStock'] ?? 0,
      value: (json['value'] ?? 0).toDouble(),
    );
  }
}
