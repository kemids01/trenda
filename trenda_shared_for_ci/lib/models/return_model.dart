// trenda_shared/lib/models/return_model.dart
// Return request model for returns management

class ReturnModel {
  final String id;
  final String returnNumber;
  final ReturnType type;
  final String orderId;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String vendorId;
  final List<ReturnItem> items;
  final ReturnStatus status;
  final double totalRefund;
  final String? refundMethod;
  final String? transactionId;
  final List<String> images;
  final String? customerNotes;
  final String? vendorNotes;
  final String? adminNotes;
  final String? rejectionReason;
  final ReturnPickup? pickup;
  final ExchangeProduct? exchangeProduct;
  final DeliveryTask? deliveryTask;
  final double returnDeliveryFee;
  final ReturnTimeline timeline;
  final Map<String, dynamic>? shippingAddress;
  final Map<String, dynamic>? vendorAddress;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReturnModel({
    required this.id,
    required this.returnNumber,
    this.type = ReturnType.returnRefund,
    required this.orderId,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    this.customerEmail,
    this.customerPhone,
    required this.vendorId,
    required this.items,
    this.status = ReturnStatus.requested,
    this.totalRefund = 0,
    this.refundMethod,
    this.transactionId,
    this.images = const [],
    this.customerNotes,
    this.vendorNotes,
    this.adminNotes,
    this.rejectionReason,
    this.pickup,
    this.exchangeProduct,
    this.deliveryTask,
    this.returnDeliveryFee = 0,
    this.shippingAddress,
    this.vendorAddress,
    ReturnTimeline? timeline,
    required this.createdAt,
    required this.updatedAt,
  }) : timeline = timeline ?? ReturnTimeline();

  factory ReturnModel.fromJson(Map<String, dynamic> json) {
    // Extract shipping address from populated order
    Map<String, dynamic>? shippingAddr;
    if (json['order'] is Map<String, dynamic>) {
      shippingAddr = json['order']['shippingAddress'] as Map<String, dynamic>?;
    }
    shippingAddr ??= json['shippingAddress'] as Map<String, dynamic>?;

    // Extract vendor address if available
    Map<String, dynamic>? vendorAddr;
    vendorAddr = json['vendorAddress'] as Map<String, dynamic>?;

    // Extract customer phone from populated customer
    String? phone;
    if (json['customer'] is Map<String, dynamic>) {
      phone = json['customer']['phone'] as String?;
    }
    phone ??= json['customerPhone'] as String?;

    return ReturnModel(
      id: json['_id'] ?? json['id'] ?? '',
      returnNumber: json['returnNumber'] ?? '',
      type: ReturnType.fromString(json['type'] ?? 'return'),
      orderId: json['orderId'] ?? (json['order'] is String ? json['order'] : (json['order'] is Map ? json['order']['_id'] ?? '' : '')) ?? '',
      orderNumber: json['orderNumber'] ?? (json['order'] is Map ? json['order']['orderNumber'] ?? '' : ''),
      customerId: json['customerId'] ?? (json['customer'] is String ? json['customer'] : (json['customer'] is Map ? json['customer']['_id'] ?? '' : '')) ?? '',
      customerName: json['customerName'] ?? (json['customer'] is Map ? json['customer']['name'] ?? '' : ''),
      customerEmail: json['customerEmail'] ?? (json['customer'] is Map ? json['customer']['email'] : null),
      customerPhone: phone,
      vendorId: json['vendorId'] ?? json['vendor'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ReturnItem.fromJson(e))
              .toList() ??
          [],
      status: ReturnStatus.fromString(json['status'] ?? 'requested'),
      totalRefund: (json['totalRefund'] ?? 0).toDouble(),
      refundMethod: json['refundMethod'],
      transactionId: json['transactionId'],
      images:
          (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      customerNotes: json['customerNotes'],
      vendorNotes: json['vendorNotes'],
      adminNotes: json['adminNotes'],
      rejectionReason: json['rejectionReason'],
      pickup: json['pickup'] != null ? ReturnPickup.fromJson(json['pickup']) : null,
      exchangeProduct: json['exchangeProduct'] != null
          ? ExchangeProduct.fromJson(json['exchangeProduct'])
          : null,
      deliveryTask: json['deliveryTask'] != null
          ? DeliveryTask.fromJson(json['deliveryTask'])
          : null,
      returnDeliveryFee: (json['returnDeliveryFee'] ?? 0).toDouble(),
      shippingAddress: shippingAddr,
      vendorAddress: vendorAddr,
      timeline: json['timeline'] != null
          ? ReturnTimeline.fromJson(json['timeline'])
          : ReturnTimeline(),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isPending => status == ReturnStatus.requested || status == ReturnStatus.pendingReview;
  bool get isApproved => status == ReturnStatus.approved;
  bool get isRejected => status == ReturnStatus.rejected;
  bool get isCompleted => status == ReturnStatus.completed;
  bool get isCancelled => status == ReturnStatus.cancelled;
  bool get isProcessing => !isPending && !isRejected && !isCompleted && !isCancelled;
  bool get isExchange => type == ReturnType.exchange;

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  /// Municipality/barangay from the shipping address
  String get municipality => shippingAddress?['municipality'] ?? shippingAddress?['city'] ?? '';
  String get barangay => shippingAddress?['barangay'] ?? '';
  String get fullAddress {
    final parts = <String>[];
    final addr = shippingAddress;
    if (addr == null) return '';
    if (addr['street'] != null) parts.add(addr['street']);
    if (addr['barangay'] != null) parts.add(addr['barangay']);
    if (addr['municipality'] != null) parts.add(addr['municipality']);
    if (addr['city'] != null && addr['city'] != addr['municipality']) parts.add(addr['city']);
    if (addr['province'] != null) parts.add(addr['province']);
    return parts.join(', ');
  }
}

class ReturnItem {
  final String productId;
  final String productName;
  final String? productImage;
  final String? variant;
  final int quantity;
  final double price;
  final ReturnReason reason;
  final String? reasonDetails;
  final ItemCondition condition;

  ReturnItem({
    required this.productId,
    required this.productName,
    this.productImage,
    this.variant,
    required this.quantity,
    required this.price,
    required this.reason,
    this.reasonDetails,
    this.condition = ItemCondition.openedUnused,
  });

  factory ReturnItem.fromJson(Map<String, dynamic> json) {
    return ReturnItem(
      productId: json['productId'] ?? json['product'] ?? '',
      productName: json['productName'] ?? '',
      productImage: json['productImage'],
      variant: json['variant'],
      quantity: json['quantity'] ?? 1,
      price: (json['price'] ?? 0).toDouble(),
      reason: ReturnReason.fromString(json['reason'] ?? 'other'),
      reasonDetails: json['reasonDetails'],
      condition: ItemCondition.fromString(json['condition'] ?? 'opened_unused'),
    );
  }

  double get totalValue => price * quantity;
}

enum ReturnStatus {
  requested('requested'),
  pendingReview('pending_review'),
  approved('approved'),
  rejected('rejected'),
  pickupScheduled('pickup_scheduled'),
  pickedUp('picked_up'),
  inTransit('in_transit'),
  received('received'),
  inspecting('inspecting'),
  refundProcessing('refund_processing'),
  completed('completed'),
  cancelled('cancelled');

  final String value;
  const ReturnStatus(this.value);

  static ReturnStatus fromString(String value) {
    return ReturnStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReturnStatus.requested,
    );
  }

  String get displayName {
    switch (this) {
      case ReturnStatus.requested:
        return 'Requested';
      case ReturnStatus.pendingReview:
        return 'Pending Review';
      case ReturnStatus.approved:
        return 'Approved';
      case ReturnStatus.rejected:
        return 'Rejected';
      case ReturnStatus.pickupScheduled:
        return 'Pickup Scheduled';
      case ReturnStatus.pickedUp:
        return 'Picked Up';
      case ReturnStatus.inTransit:
        return 'In Transit';
      case ReturnStatus.received:
        return 'Received';
      case ReturnStatus.inspecting:
        return 'Inspecting';
      case ReturnStatus.refundProcessing:
        return 'Refund Processing';
      case ReturnStatus.completed:
        return 'Completed';
      case ReturnStatus.cancelled:
        return 'Cancelled';
    }
  }
}

enum ReturnReason {
  defective('defective'),
  wrongItem('wrong_item'),
  notAsDescribed('not_as_described'),
  damaged('damaged'),
  sizeIssue('size_issue'),
  qualityIssue('quality_issue'),
  other('other');

  final String value;
  const ReturnReason(this.value);

  static ReturnReason fromString(String value) {
    return ReturnReason.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReturnReason.other,
    );
  }

  /// Whether this reason qualifies for exchange (vendor-fault reasons)
  bool get isExchangeEligible => [
    ReturnReason.defective,
    ReturnReason.wrongItem,
    ReturnReason.notAsDescribed,
    ReturnReason.damaged,
  ].contains(this);

  String get displayName {
    switch (this) {
      case ReturnReason.defective:
        return 'Defective';
      case ReturnReason.wrongItem:
        return 'Wrong Item';
      case ReturnReason.notAsDescribed:
        return 'Not as Described';
      case ReturnReason.damaged:
        return 'Damaged';
      case ReturnReason.sizeIssue:
        return 'Size Issue';
      case ReturnReason.qualityIssue:
        return 'Quality Issue';
      case ReturnReason.other:
        return 'Other';
    }
  }
}

enum ReturnType {
  returnRefund('return'),
  exchange('exchange');

  final String value;
  const ReturnType(this.value);

  static ReturnType fromString(String value) {
    return ReturnType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReturnType.returnRefund,
    );
  }

  String get displayName {
    switch (this) {
      case ReturnType.returnRefund:
        return 'Return & Refund';
      case ReturnType.exchange:
        return 'Exchange (Same Product)';
    }
  }
}

enum ItemCondition {
  unopened('unopened'),
  openedUnused('opened_unused'),
  used('used'),
  damaged('damaged');

  final String value;
  const ItemCondition(this.value);

  static ItemCondition fromString(String value) {
    return ItemCondition.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ItemCondition.openedUnused,
    );
  }

  String get displayName {
    switch (this) {
      case ItemCondition.unopened:
        return 'Unopened';
      case ItemCondition.openedUnused:
        return 'Opened (Unused)';
      case ItemCondition.used:
        return 'Used';
      case ItemCondition.damaged:
        return 'Damaged';
    }
  }
}

class ReturnPickup {
  final DateTime? scheduledDate;
  final String? courier;
  final String? trackingNumber;
  final String? address;
  final String? notes;

  ReturnPickup({
    this.scheduledDate,
    this.courier,
    this.trackingNumber,
    this.address,
    this.notes,
  });

  factory ReturnPickup.fromJson(Map<String, dynamic> json) {
    return ReturnPickup(
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.tryParse(json['scheduledDate'])
          : null,
      courier: json['courier'],
      trackingNumber: json['trackingNumber'],
      address: json['address'],
      notes: json['notes'],
    );
  }
}

class ReturnTimeline {
  final DateTime? requested;
  final DateTime? reviewed;
  final DateTime? approved;
  final DateTime? rejected;
  final DateTime? pickupScheduled;
  final DateTime? pickedUp;
  final DateTime? received;
  final DateTime? inspected;
  final DateTime? refundProcessed;
  final DateTime? completed;
  final DateTime? cancelled;

  ReturnTimeline({
    this.requested,
    this.reviewed,
    this.approved,
    this.rejected,
    this.pickupScheduled,
    this.pickedUp,
    this.received,
    this.inspected,
    this.refundProcessed,
    this.completed,
    this.cancelled,
  });

  factory ReturnTimeline.fromJson(Map<String, dynamic> json) {
    return ReturnTimeline(
      requested: json['requested'] != null ? DateTime.tryParse(json['requested']) : null,
      reviewed: json['reviewed'] != null ? DateTime.tryParse(json['reviewed']) : null,
      approved: json['approved'] != null ? DateTime.tryParse(json['approved']) : null,
      rejected: json['rejected'] != null ? DateTime.tryParse(json['rejected']) : null,
      pickupScheduled: json['pickupScheduled'] != null
          ? DateTime.tryParse(json['pickupScheduled'])
          : null,
      pickedUp: json['pickedUp'] != null ? DateTime.tryParse(json['pickedUp']) : null,
      received: json['received'] != null ? DateTime.tryParse(json['received']) : null,
      inspected: json['inspected'] != null ? DateTime.tryParse(json['inspected']) : null,
      refundProcessed: json['refundProcessed'] != null
          ? DateTime.tryParse(json['refundProcessed'])
          : null,
      completed: json['completed'] != null ? DateTime.tryParse(json['completed']) : null,
      cancelled: json['cancelled'] != null ? DateTime.tryParse(json['cancelled']) : null,
    );
  }
}

class ExchangeProduct {
  final String productId;
  final String productName;
  final String? productImage;
  final String? variantId;
  final String? variantName;
  final int quantity;
  final String? notes;

  ExchangeProduct({
    required this.productId,
    required this.productName,
    this.productImage,
    this.variantId,
    this.variantName,
    required this.quantity,
    this.notes,
  });

  factory ExchangeProduct.fromJson(Map<String, dynamic> json) {
    final variant = json['variant'] as Map<String, dynamic>?;
    return ExchangeProduct(
      productId: json['product'] ?? json['productId'] ?? '',
      productName: json['productName'] ?? '',
      productImage: json['productImage'],
      variantId: variant?['id'],
      variantName: variant?['name'],
      quantity: json['quantity'] ?? 1,
      notes: json['notes'],
    );
  }
}

class DeliveryTask {
  final String? riderId;
  final String? riderFirebaseUid;
  final String? riderName;
  final String? originalOrderId;
  final double pickupFee;
  final double deliveryFee;
  final double totalFee;
  final String paidBy;
  final String status;
  final DateTime? assignedAt;
  final DateTime? pickupStartedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredToVendorAt;
  final DateTime? replacementPickedUpAt;
  final DateTime? replacementDeliveredAt;
  final DateTime? completedAt;
  final List<String> proofPhotos;
  final String? notes;

  DeliveryTask({
    this.riderId,
    this.riderFirebaseUid,
    this.riderName,
    this.originalOrderId,
    this.pickupFee = 0,
    this.deliveryFee = 0,
    this.totalFee = 0,
    this.paidBy = 'vendor',
    this.status = 'pending',
    this.assignedAt,
    this.pickupStartedAt,
    this.pickedUpAt,
    this.deliveredToVendorAt,
    this.replacementPickedUpAt,
    this.replacementDeliveredAt,
    this.completedAt,
    this.proofPhotos = const [],
    this.notes,
  });

  factory DeliveryTask.fromJson(Map<String, dynamic> json) {
    return DeliveryTask(
      riderId: json['riderId'],
      riderFirebaseUid: json['riderFirebaseUid'],
      riderName: json['riderName'],
      originalOrderId: json['originalOrderId'],
      pickupFee: (json['pickupFee'] ?? 0).toDouble(),
      deliveryFee: (json['deliveryFee'] ?? 0).toDouble(),
      totalFee: (json['totalFee'] ?? 0).toDouble(),
      paidBy: json['paidBy'] ?? 'vendor',
      status: json['status'] ?? 'pending',
      assignedAt: json['assignedAt'] != null ? DateTime.tryParse(json['assignedAt']) : null,
      pickupStartedAt: json['pickupStartedAt'] != null ? DateTime.tryParse(json['pickupStartedAt']) : null,
      pickedUpAt: json['pickedUpAt'] != null ? DateTime.tryParse(json['pickedUpAt']) : null,
      deliveredToVendorAt: json['deliveredToVendorAt'] != null ? DateTime.tryParse(json['deliveredToVendorAt']) : null,
      replacementPickedUpAt: json['replacementPickedUpAt'] != null ? DateTime.tryParse(json['replacementPickedUpAt']) : null,
      replacementDeliveredAt: json['replacementDeliveredAt'] != null ? DateTime.tryParse(json['replacementDeliveredAt']) : null,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt']) : null,
      proofPhotos: (json['proofPhotos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      notes: json['notes'],
    );
  }

  bool get isActive => !['completed', 'failed', 'pending'].contains(status);
  bool get isCompleted => status == 'completed';
}

class ReturnStats {
  final int totalReturns;
  final int pendingReturns;
  final int approvedReturns;
  final int rejectedReturns;
  final int completedReturns;
  final double totalRefunded;
  final double averageRefundAmount;
  final Map<String, int> byReason;

  ReturnStats({
    this.totalReturns = 0,
    this.pendingReturns = 0,
    this.approvedReturns = 0,
    this.rejectedReturns = 0,
    this.completedReturns = 0,
    this.totalRefunded = 0,
    this.averageRefundAmount = 0,
    this.byReason = const {},
  });

  factory ReturnStats.fromJson(Map<String, dynamic> json) {
    return ReturnStats(
      totalReturns: json['totalReturns'] ?? 0,
      pendingReturns: json['pendingReturns'] ?? 0,
      approvedReturns: json['approvedReturns'] ?? 0,
      rejectedReturns: json['rejectedReturns'] ?? 0,
      completedReturns: json['completedReturns'] ?? 0,
      totalRefunded: (json['totalRefunded'] ?? 0).toDouble(),
      averageRefundAmount: (json['averageRefundAmount'] ?? 0).toDouble(),
      byReason: (json['byReason'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
    );
  }
}
