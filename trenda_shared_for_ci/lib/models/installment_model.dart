class InstallmentPlan {
  final String id;
  final String productId;
  final String vendorId;
  final int durationMonths;
  final double finalPrice;
  final double minDownPaymentPercent;
  final double maxDownPaymentPercent;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // Expanded fields for UI
  final String? productName;
  final String? productImage;
  final double? originalPrice;

  InstallmentPlan({
    required this.id,
    required this.productId,
    required this.vendorId,
    required this.durationMonths,
    required this.finalPrice,
    required this.minDownPaymentPercent,
    required this.maxDownPaymentPercent,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.productName,
    this.productImage,
    this.originalPrice,
  });

  factory InstallmentPlan.fromJson(Map<String, dynamic> json) {
    return InstallmentPlan(
      id: json['_id'] ?? '',
      productId: json['product'] is Map
          ? json['product']['_id']
          : (json['product'] ?? ''),
      vendorId: json['vendor'] ?? '',
      durationMonths: json['durationMonths'] ?? 0,
      finalPrice: (json['finalPrice'] ?? 0).toDouble(),
      minDownPaymentPercent: (json['minDownPaymentPercent'] ?? 0).toDouble(),
      maxDownPaymentPercent: (json['maxDownPaymentPercent'] ?? 0).toDouble(),
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      productName: json['product'] is Map ? json['product']['name'] : null,
      productImage:
          json['product'] is Map &&
              json['product']['images'] != null &&
              (json['product']['images'] as List).isNotEmpty
          ? json['product']['images'][0]
          : null,
      originalPrice: json['product'] is Map
          ? (json['product']['price'] ?? json['product']['basePrice'] ?? 0)
                .toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'durationMonths': durationMonths,
      'finalPrice': finalPrice,
      'minDownPaymentPercent': minDownPaymentPercent,
      'maxDownPaymentPercent': maxDownPaymentPercent,
      'isActive': isActive,
    };
  }

  double calculateMonthlyPayment(double downPayment) {
    if (durationMonths <= 0) return 0;
    return (finalPrice - downPayment) / durationMonths;
  }
}

class InstallmentApplication {
  final String id;
  final String referenceNumber;
  final String customerId;
  final String vendorId;
  final String productId;
  final String planId;
  final String status;
  final String vendorStatus;
  final DateTime applicationDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? decisionDate;
  final DateTime? reviewDate;

  // Expanded fields from populated data
  final InstallmentPlan? plan;
  final Map<String, dynamic>? product;
  final Map<String, dynamic>? customer;
  final Map<String, dynamic>? vendor;

  // Form sections
  final FinancialSnapshot? financialSnapshot;
  final Map<String, dynamic>? personalInfo;
  final Map<String, dynamic>? spouseInfo;
  final Map<String, dynamic>? vendorDecision;
  final Map<String, dynamic>? currentAddress;
  final Map<String, dynamic>? permanentAddress;
  final Map<String, dynamic>? employment;
  final Map<String, dynamic>? income;
  final Map<String, dynamic>? expenses;
  final Map<String, dynamic>? household;
  final Map<String, dynamic>? authorization;
  final List<dynamic>? references;

  // Convenience getters
  String? get productName {
    if (product != null && product!['name'] != null) return product!['name'];
    return null;
  }

  String? get customerName {
    if (personalInfo != null && personalInfo!['fullName'] != null) {
      return personalInfo!['fullName'];
    }
    if (customer != null && customer!['name'] != null) {
      return customer!['name'];
    }
    return null;
  }

  String? get customerEmail {
    if (personalInfo != null && personalInfo!['email'] != null) {
      return personalInfo!['email'];
    }
    if (customer != null && customer!['email'] != null) {
      return customer!['email'];
    }
    return null;
  }

  InstallmentApplication({
    required this.id,
    required this.referenceNumber,
    required this.customerId,
    required this.vendorId,
    required this.productId,
    required this.planId,
    required this.status,
    required this.vendorStatus,
    required this.applicationDate,
    this.createdAt,
    this.updatedAt,
    this.decisionDate,
    this.reviewDate,
    this.plan,
    this.product,
    this.customer,
    this.vendor,
    this.financialSnapshot,
    this.personalInfo,
    this.spouseInfo,
    this.vendorDecision,
    this.currentAddress,
    this.permanentAddress,
    this.employment,
    this.income,
    this.expenses,
    this.household,
    this.authorization,
    this.references,
  });

  factory InstallmentApplication.fromJson(Map<String, dynamic> json) {
    return InstallmentApplication(
      id: json['_id'] ?? '',
      referenceNumber: json['referenceNumber'] ?? '',
      customerId: json['customer'] is Map
          ? json['customer']['_id']
          : (json['customer'] ?? ''),
      vendorId: json['vendor'] is Map
          ? json['vendor']['_id']
          : (json['vendor'] ?? ''),
      productId: json['product'] is Map
          ? json['product']['_id']
          : (json['product'] ?? ''),
      planId: json['installmentPlan'] is Map
          ? json['installmentPlan']['_id']
          : (json['installmentPlan'] ?? ''),
      status: json['status'] ?? 'Pending',
      vendorStatus: json['vendorStatus'] ?? 'Pending',
      applicationDate: json['applicationDate'] != null
          ? DateTime.parse(json['applicationDate'])
          : (json['createdAt'] != null
                ? DateTime.parse(json['createdAt'])
                : DateTime.now()),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      decisionDate: json['decisionDate'] != null
          ? DateTime.parse(json['decisionDate'])
          : null,
      reviewDate: json['reviewDate'] != null
          ? DateTime.parse(json['reviewDate'])
          : null,
      plan: json['installmentPlan'] is Map
          ? InstallmentPlan.fromJson(json['installmentPlan'])
          : null,
      product: json['product'] is Map
          ? Map<String, dynamic>.from(json['product'])
          : null,
      customer: json['customer'] is Map
          ? Map<String, dynamic>.from(json['customer'])
          : null,
      vendor: json['vendor'] is Map
          ? Map<String, dynamic>.from(json['vendor'])
          : null,
      financialSnapshot: json['financialSnapshot'] != null
          ? FinancialSnapshot.fromJson(json['financialSnapshot'])
          : null,
      personalInfo: json['personalInfo'] != null
          ? Map<String, dynamic>.from(json['personalInfo'])
          : null,
      spouseInfo: json['spouseInfo'] != null
          ? Map<String, dynamic>.from(json['spouseInfo'])
          : null,
      vendorDecision: json['vendorDecision'] != null
          ? Map<String, dynamic>.from(json['vendorDecision'])
          : null,
      currentAddress: json['currentAddress'] != null
          ? Map<String, dynamic>.from(json['currentAddress'])
          : null,
      permanentAddress: json['permanentAddress'] != null
          ? Map<String, dynamic>.from(json['permanentAddress'])
          : null,
      employment: json['employment'] != null
          ? Map<String, dynamic>.from(json['employment'])
          : null,
      income: json['income'] != null
          ? Map<String, dynamic>.from(json['income'])
          : null,
      expenses: json['expenses'] != null
          ? Map<String, dynamic>.from(json['expenses'])
          : null,
      household: json['household'] != null
          ? Map<String, dynamic>.from(json['household'])
          : null,
      authorization: json['authorization'] != null
          ? Map<String, dynamic>.from(json['authorization'])
          : null,
      references: json['references'] != null
          ? List<dynamic>.from(json['references'])
          : null,
    );
  }
}

class FinancialSnapshot {
  final double? productPrice;
  final double? downPayment;
  final int? loanTermMonths;
  final double? monthlyAmortization;
  final double? totalAmountPayable;
  final double? totalInterest;

  FinancialSnapshot({
    this.productPrice,
    this.downPayment,
    this.loanTermMonths,
    this.monthlyAmortization,
    this.totalAmountPayable,
    this.totalInterest,
  });

  factory FinancialSnapshot.fromJson(Map<String, dynamic> json) {
    return FinancialSnapshot(
      productPrice: (json['productPrice'] ?? 0).toDouble(),
      downPayment: (json['downPayment'] ?? 0).toDouble(),
      loanTermMonths: json['loanTermMonths'] ?? 0,
      monthlyAmortization: (json['monthlyAmortization'] ?? 0).toDouble(),
      totalAmountPayable: (json['totalAmountPayable'] ?? 0).toDouble(),
      totalInterest: (json['totalInterest'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productPrice': productPrice,
      'downPayment': downPayment,
      'loanTermMonths': loanTermMonths,
      'monthlyAmortization': monthlyAmortization,
      'totalAmountPayable': totalAmountPayable,
      'totalInterest': totalInterest,
    };
  }
}
