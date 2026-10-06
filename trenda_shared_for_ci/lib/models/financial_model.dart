// trenda_shared/lib/models/financial_model.dart
// Financial models for vendor financial management

class FinancialStats {
  final double totalRevenue;
  final double pendingBalance;
  final double availableBalance;
  final double totalPayouts;
  final double totalFees;
  final double netIncome;
  final RevenueBreakdown breakdown;
  final List<RevenueTrend> trends;

  FinancialStats({
    this.totalRevenue = 0,
    this.pendingBalance = 0,
    this.availableBalance = 0,
    this.totalPayouts = 0,
    this.totalFees = 0,
    this.netIncome = 0,
    RevenueBreakdown? breakdown,
    this.trends = const [],
  }) : breakdown = breakdown ?? RevenueBreakdown();

  factory FinancialStats.fromJson(Map<String, dynamic> json) {
    return FinancialStats(
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      pendingBalance: (json['pendingBalance'] ?? 0).toDouble(),
      availableBalance: (json['availableBalance'] ?? 0).toDouble(),
      totalPayouts: (json['totalPayouts'] ?? 0).toDouble(),
      totalFees: (json['totalFees'] ?? 0).toDouble(),
      netIncome: (json['netIncome'] ?? 0).toDouble(),
      breakdown: json['breakdown'] != null
          ? RevenueBreakdown.fromJson(json['breakdown'])
          : RevenueBreakdown(),
      trends:
          (json['trends'] as List<dynamic>?)
              ?.map((e) => RevenueTrend.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class RevenueBreakdown {
  final double productSales;
  final double shippingFees;
  final double returns;
  final double platformFees;
  final double paymentFees;
  final double taxes;

  RevenueBreakdown({
    this.productSales = 0,
    this.shippingFees = 0,
    this.returns = 0,
    this.platformFees = 0,
    this.paymentFees = 0,
    this.taxes = 0,
  });

  factory RevenueBreakdown.fromJson(Map<String, dynamic> json) {
    return RevenueBreakdown(
      productSales: (json['productSales'] ?? 0).toDouble(),
      shippingFees: (json['shippingFees'] ?? 0).toDouble(),
      returns: (json['returns'] ?? 0).toDouble(),
      platformFees: (json['platformFees'] ?? 0).toDouble(),
      paymentFees: (json['paymentFees'] ?? 0).toDouble(),
      taxes: (json['taxes'] ?? 0).toDouble(),
    );
  }

  double get totalFees => platformFees + paymentFees;
  double get grossRevenue => productSales + shippingFees;
  double get netRevenue => grossRevenue - returns - totalFees - taxes;
}

class RevenueTrend {
  final DateTime date;
  final double revenue;
  final double orders;
  final double averageOrderValue;

  RevenueTrend({
    required this.date,
    required this.revenue,
    required this.orders,
    required this.averageOrderValue,
  });

  factory RevenueTrend.fromJson(Map<String, dynamic> json) {
    return RevenueTrend(
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      revenue: (json['revenue'] ?? 0).toDouble(),
      orders: (json['orders'] ?? 0).toDouble(),
      averageOrderValue: (json['averageOrderValue'] ?? 0).toDouble(),
    );
  }
}

class PayoutModel {
  final String id;
  final String vendorId;
  final double amount;
  final PayoutStatus status;
  final PayoutMethod method;
  final String? transactionId;
  final String? bankName;
  final String? accountNumber;
  final String? accountName;
  final String? notes;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final DateTime? completedAt;
  final String? rejectionReason;

  PayoutModel({
    required this.id,
    required this.vendorId,
    required this.amount,
    this.status = PayoutStatus.pending,
    required this.method,
    this.transactionId,
    this.bankName,
    this.accountNumber,
    this.accountName,
    this.notes,
    required this.requestedAt,
    this.processedAt,
    this.completedAt,
    this.rejectionReason,
  });

  factory PayoutModel.fromJson(Map<String, dynamic> json) {
    return PayoutModel(
      id: json['_id'] ?? json['id'] ?? '',
      vendorId: json['vendorId'] ?? json['vendor'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      status: PayoutStatus.fromString(json['status'] ?? 'pending'),
      method: PayoutMethod.fromString(json['method'] ?? 'bank_transfer'),
      transactionId: json['transactionId'],
      bankName: json['bankName'],
      accountNumber: json['accountNumber'],
      accountName: json['accountName'],
      notes: json['notes'],
      requestedAt:
          DateTime.tryParse(json['requestedAt'] ?? '') ?? DateTime.now(),
      processedAt: json['processedAt'] != null
          ? DateTime.tryParse(json['processedAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
      rejectionReason: json['rejectionReason'],
    );
  }

  bool get isPending => status == PayoutStatus.pending;
  bool get isProcessing => status == PayoutStatus.processing;
  bool get isCompleted => status == PayoutStatus.completed;
  bool get isRejected => status == PayoutStatus.rejected;
}

enum PayoutStatus {
  pending('pending'),
  processing('processing'),
  completed('completed'),
  rejected('rejected'),
  cancelled('cancelled');

  final String value;
  const PayoutStatus(this.value);

  static PayoutStatus fromString(String value) {
    return PayoutStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PayoutStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case PayoutStatus.pending:
        return 'Pending';
      case PayoutStatus.processing:
        return 'Processing';
      case PayoutStatus.completed:
        return 'Completed';
      case PayoutStatus.rejected:
        return 'Rejected';
      case PayoutStatus.cancelled:
        return 'Cancelled';
    }
  }
}

enum PayoutMethod {
  bankTransfer('bank_transfer'),
  gcash('gcash'),
  paymaya('paymaya'),
  paypal('paypal');

  final String value;
  const PayoutMethod(this.value);

  static PayoutMethod fromString(String value) {
    return PayoutMethod.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PayoutMethod.bankTransfer,
    );
  }

  String get displayName {
    switch (this) {
      case PayoutMethod.bankTransfer:
        return 'Bank Transfer';
      case PayoutMethod.gcash:
        return 'GCash';
      case PayoutMethod.paymaya:
        return 'PayMaya';
      case PayoutMethod.paypal:
        return 'PayPal';
    }
  }
}

class TransactionModel {
  final String id;
  final String orderId;
  final String? orderNumber;
  final TransactionType type;
  final double amount;
  final double? fee;
  final double netAmount;
  final String status;
  final String? description;
  final String? paymentMethod;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.orderId,
    this.orderNumber,
    required this.type,
    required this.amount,
    this.fee,
    required this.netAmount,
    required this.status,
    this.description,
    this.paymentMethod,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['_id'] ?? json['id'] ?? '',
      orderId: json['orderId'] ?? json['order'] ?? '',
      orderNumber: json['orderNumber'],
      type: TransactionType.fromString(json['type'] ?? 'sale'),
      amount: (json['amount'] ?? 0).toDouble(),
      fee: json['fee']?.toDouble(),
      netAmount: (json['netAmount'] ?? json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      description: json['description'],
      paymentMethod: json['paymentMethod'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

enum TransactionType {
  sale('sale'),
  refund('refund'),
  payout('payout'),
  fee('fee'),
  adjustment('adjustment');

  final String value;
  const TransactionType(this.value);

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TransactionType.sale,
    );
  }
}

class EarningsBreakdown {
  final List<ProductEarning> topProducts;
  final Map<String, double> byCategory;
  final Map<String, double> byPaymentMethod;
  final double periodTotal;
  final double averageOrderValue;

  EarningsBreakdown({
    this.topProducts = const [],
    this.byCategory = const {},
    this.byPaymentMethod = const {},
    this.periodTotal = 0,
    this.averageOrderValue = 0,
  });

  factory EarningsBreakdown.fromJson(Map<String, dynamic> json) {
    return EarningsBreakdown(
      topProducts:
          (json['topProducts'] as List<dynamic>?)
              ?.map((e) => ProductEarning.fromJson(e))
              .toList() ??
          [],
      byCategory:
          (json['byCategory'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      byPaymentMethod:
          (json['byPaymentMethod'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      periodTotal: (json['periodTotal'] ?? 0).toDouble(),
      averageOrderValue: (json['averageOrderValue'] ?? 0).toDouble(),
    );
  }
}

class ProductEarning {
  final String productId;
  final String productName;
  final String? productImage;
  final int quantitySold;
  final double revenue;
  final double percentage;

  ProductEarning({
    required this.productId,
    required this.productName,
    this.productImage,
    required this.quantitySold,
    required this.revenue,
    required this.percentage,
  });

  factory ProductEarning.fromJson(Map<String, dynamic> json) {
    return ProductEarning(
      productId: json['productId'] ?? json['product'] ?? '',
      productName: json['productName'] ?? '',
      productImage: json['productImage'],
      quantitySold: json['quantitySold'] ?? 0,
      revenue: (json['revenue'] ?? 0).toDouble(),
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}

class CODTracking {
  final List<CODOrder> pendingCOD;
  final List<CODOrder> collectedCOD;
  final double totalPendingAmount;
  final double totalCollectedAmount;
  final double totalRemittedAmount;

  CODTracking({
    this.pendingCOD = const [],
    this.collectedCOD = const [],
    this.totalPendingAmount = 0,
    this.totalCollectedAmount = 0,
    this.totalRemittedAmount = 0,
  });

  factory CODTracking.fromJson(Map<String, dynamic> json) {
    return CODTracking(
      pendingCOD:
          (json['pendingCOD'] as List<dynamic>?)
              ?.map((e) => CODOrder.fromJson(e))
              .toList() ??
          [],
      collectedCOD:
          (json['collectedCOD'] as List<dynamic>?)
              ?.map((e) => CODOrder.fromJson(e))
              .toList() ??
          [],
      totalPendingAmount: (json['totalPendingAmount'] ?? 0).toDouble(),
      totalCollectedAmount: (json['totalCollectedAmount'] ?? 0).toDouble(),
      totalRemittedAmount: (json['totalRemittedAmount'] ?? 0).toDouble(),
    );
  }
}

class CODOrder {
  final String orderId;
  final String orderNumber;
  final double amount;
  final DateTime deliveredAt;
  final DateTime? collectedAt;
  final DateTime? remittedAt;

  CODOrder({
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    required this.deliveredAt,
    this.collectedAt,
    this.remittedAt,
  });

  factory CODOrder.fromJson(Map<String, dynamic> json) {
    return CODOrder(
      orderId: json['orderId'] ?? json['order'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      deliveredAt:
          DateTime.tryParse(json['deliveredAt'] ?? '') ?? DateTime.now(),
      collectedAt: json['collectedAt'] != null
          ? DateTime.tryParse(json['collectedAt'])
          : null,
      remittedAt: json['remittedAt'] != null
          ? DateTime.tryParse(json['remittedAt'])
          : null,
    );
  }
}

class PayoutSchedule {
  final String frequency; // weekly, biweekly, monthly
  final int dayOfWeek; // 0-6 for weekly
  final int? dayOfMonth; // 1-28 for monthly
  final double minimumAmount;
  final bool autoPayoutEnabled;
  final DateTime? nextPayoutDate;
  final double nextPayoutAmount;

  PayoutSchedule({
    this.frequency = 'weekly',
    this.dayOfWeek = 5, // Friday
    this.dayOfMonth,
    this.minimumAmount = 500,
    this.autoPayoutEnabled = false,
    this.nextPayoutDate,
    this.nextPayoutAmount = 0,
  });

  factory PayoutSchedule.fromJson(Map<String, dynamic> json) {
    return PayoutSchedule(
      frequency: json['frequency'] ?? 'weekly',
      dayOfWeek: json['dayOfWeek'] ?? 5,
      dayOfMonth: json['dayOfMonth'],
      minimumAmount: (json['minimumAmount'] ?? 500).toDouble(),
      autoPayoutEnabled: json['autoPayoutEnabled'] ?? false,
      nextPayoutDate: json['nextPayoutDate'] != null
          ? DateTime.tryParse(json['nextPayoutDate'])
          : null,
      nextPayoutAmount: (json['nextPayoutAmount'] ?? 0).toDouble(),
    );
  }
}

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String vendorId;
  final InvoiceType type;
  final DateTime startDate;
  final DateTime endDate;
  final double subtotal;
  final double fees;
  final double taxes;
  final double total;
  final List<InvoiceItem> items;
  final DateTime generatedAt;
  final String? pdfUrl;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.vendorId,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.subtotal,
    required this.fees,
    required this.taxes,
    required this.total,
    this.items = const [],
    required this.generatedAt,
    this.pdfUrl,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['_id'] ?? json['id'] ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      vendorId: json['vendorId'] ?? json['vendor'] ?? '',
      type: InvoiceType.fromString(json['type'] ?? 'sales'),
      startDate: DateTime.tryParse(json['startDate'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate'] ?? '') ?? DateTime.now(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      fees: (json['fees'] ?? 0).toDouble(),
      taxes: (json['taxes'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => InvoiceItem.fromJson(e))
              .toList() ??
          [],
      generatedAt:
          DateTime.tryParse(json['generatedAt'] ?? '') ?? DateTime.now(),
      pdfUrl: json['pdfUrl'],
    );
  }
}

enum InvoiceType {
  sales('sales'),
  payout('payout');

  final String value;
  const InvoiceType(this.value);

  static InvoiceType fromString(String value) {
    return InvoiceType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => InvoiceType.sales,
    );
  }
}

class InvoiceItem {
  final String description;
  final int quantity;
  final double unitPrice;
  final double amount;

  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      description: json['description'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }
}

class TaxReport {
  final int year;
  final double totalSales;
  final double totalTaxCollected;
  final double totalRefunds;
  final double netTaxable;
  final List<MonthlyTax> monthlyBreakdown;

  TaxReport({
    required this.year,
    this.totalSales = 0,
    this.totalTaxCollected = 0,
    this.totalRefunds = 0,
    this.netTaxable = 0,
    this.monthlyBreakdown = const [],
  });

  factory TaxReport.fromJson(Map<String, dynamic> json) {
    return TaxReport(
      year: json['year'] ?? DateTime.now().year,
      totalSales: (json['totalSales'] ?? 0).toDouble(),
      totalTaxCollected: (json['totalTaxCollected'] ?? 0).toDouble(),
      totalRefunds: (json['totalRefunds'] ?? 0).toDouble(),
      netTaxable: (json['netTaxable'] ?? 0).toDouble(),
      monthlyBreakdown:
          (json['monthlyBreakdown'] as List<dynamic>?)
              ?.map((e) => MonthlyTax.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class MonthlyTax {
  final int month;
  final double sales;
  final double tax;

  MonthlyTax({required this.month, required this.sales, required this.tax});

  factory MonthlyTax.fromJson(Map<String, dynamic> json) {
    return MonthlyTax(
      month: json['month'] ?? 1,
      sales: (json['sales'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
    );
  }
}

class ProfitLossStatement {
  final DateTime startDate;
  final DateTime endDate;
  final double grossRevenue;
  final double returns;
  final double netRevenue;
  final double costOfGoods;
  final double grossProfit;
  final double platformFees;
  final double paymentFees;
  final double shippingCosts;
  final double otherExpenses;
  final double totalExpenses;
  final double netProfit;
  final double profitMargin;

  ProfitLossStatement({
    required this.startDate,
    required this.endDate,
    this.grossRevenue = 0,
    this.returns = 0,
    this.netRevenue = 0,
    this.costOfGoods = 0,
    this.grossProfit = 0,
    this.platformFees = 0,
    this.paymentFees = 0,
    this.shippingCosts = 0,
    this.otherExpenses = 0,
    this.totalExpenses = 0,
    this.netProfit = 0,
    this.profitMargin = 0,
  });

  factory ProfitLossStatement.fromJson(Map<String, dynamic> json) {
    return ProfitLossStatement(
      startDate: DateTime.tryParse(json['startDate'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate'] ?? '') ?? DateTime.now(),
      grossRevenue: (json['grossRevenue'] ?? 0).toDouble(),
      returns: (json['returns'] ?? 0).toDouble(),
      netRevenue: (json['netRevenue'] ?? 0).toDouble(),
      costOfGoods: (json['costOfGoods'] ?? 0).toDouble(),
      grossProfit: (json['grossProfit'] ?? 0).toDouble(),
      platformFees: (json['platformFees'] ?? 0).toDouble(),
      paymentFees: (json['paymentFees'] ?? 0).toDouble(),
      shippingCosts: (json['shippingCosts'] ?? 0).toDouble(),
      otherExpenses: (json['otherExpenses'] ?? 0).toDouble(),
      totalExpenses: (json['totalExpenses'] ?? 0).toDouble(),
      netProfit: (json['netProfit'] ?? 0).toDouble(),
      profitMargin: (json['profitMargin'] ?? 0).toDouble(),
    );
  }
}

// ============================================================================
// COMMISSION MODELS
// ============================================================================

/// Commission summary for vendor dashboard
class CommissionSummary {
  final double totalCommissionPaid;
  final double vendorCommissionTotal;
  final double deliveryCommissionTotal;
  final double netEarnings;
  final int orderCount;
  final double averageCommissionRate;
  final List<CommissionOrderBreakdown> recentOrders;

  CommissionSummary({
    this.totalCommissionPaid = 0,
    this.vendorCommissionTotal = 0,
    this.deliveryCommissionTotal = 0,
    this.netEarnings = 0,
    this.orderCount = 0,
    this.averageCommissionRate = 15,
    this.recentOrders = const [],
  });

  factory CommissionSummary.fromJson(Map<String, dynamic> json) {
    return CommissionSummary(
      totalCommissionPaid: (json['totalCommissionPaid'] ?? 0).toDouble(),
      vendorCommissionTotal: (json['vendorCommissionTotal'] ?? 0).toDouble(),
      deliveryCommissionTotal: (json['deliveryCommissionTotal'] ?? 0)
          .toDouble(),
      netEarnings: (json['netEarnings'] ?? 0).toDouble(),
      orderCount: json['orderCount'] ?? 0,
      averageCommissionRate: (json['averageCommissionRate'] ?? 15).toDouble(),
      recentOrders:
          (json['recentOrders'] as List<dynamic>?)
              ?.map((e) => CommissionOrderBreakdown.fromJson(e))
              .toList() ??
          [],
    );
  }

  factory CommissionSummary.empty() => CommissionSummary();
}

/// Commission breakdown for individual order
class CommissionOrderBreakdown {
  final String orderId;
  final String orderNumber;
  final double subtotal;
  final double vendorCommission;
  final double deliveryCommission;
  final double totalCommission;
  final double netAmount;
  final DateTime createdAt;

  CommissionOrderBreakdown({
    required this.orderId,
    required this.orderNumber,
    this.subtotal = 0,
    this.vendorCommission = 0,
    this.deliveryCommission = 0,
    this.totalCommission = 0,
    this.netAmount = 0,
    required this.createdAt,
  });

  factory CommissionOrderBreakdown.fromJson(Map<String, dynamic> json) {
    return CommissionOrderBreakdown(
      orderId: json['orderId'] ?? json['_id'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      vendorCommission:
          (json['vendorCommission'] ??
                  json['commission']?['vendorCommission'] ??
                  0)
              .toDouble(),
      deliveryCommission:
          (json['deliveryCommission'] ??
                  json['commission']?['deliveryCommission'] ??
                  0)
              .toDouble(),
      totalCommission:
          (json['totalCommission'] ??
                  json['commission']?['totalCommission'] ??
                  0)
              .toDouble(),
      netAmount:
          (json['netAmount'] ?? json['commission']?['vendorNetEarnings'] ?? 0)
              .toDouble(),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
