// trenda_shared/lib/models/delivery_info.dart
// Delivery metadata models for enhanced order tracking

class DeliveryInfo {
  final String? type; // 'express', 'pasabay', 'heavy_express'
  final String? assignedTo; // Rider ID who claimed the delivery
  final DeliveryETA? eta;
  final DeliveryBatchInfo? batchInfo;
  final double? earnings; // Actual earnings from backend
  final String? proofOfDeliveryUrl; // POD photo URL

  // 🆕 Municipality-based rate info
  final bool municipalityOverride; // True if local rates applied
  final String? municipality; // Municipality name if override applied

  // 🆕 Vendor pickup information
  final String? vendorId;
  final String? vendorName;
  final String? vendorPhone;
  final PickupAddress? pickupAddress; // Vendor store address

  // 🆕 Rider details
  final String? riderName;
  final String? riderPhone;
  final String? vehiclePlate;

  // 🆕 Fee Breakdown
  final double? baseDeliveryFee;
  final double? expressDeliveryFee;
  final double? heavyItemSurcharge;
  final double? timeWindowFee;
  final double? baseDistance; // ✅
  final double? excessFee; // ✅

  // 🆕 Route Info
  final double? totalDistance; // in meters

  // 🆕 Cross-municipality compensation
  final double? crossMunicipalityBonus;
  final String? riderMunicipality;
  final String? crossMunicipalityNote;

  // 🆕 Customer Action Requirements
  final bool requiresCustomerAction;
  final String? actionRequired;

  DeliveryInfo({
    this.type,
    this.assignedTo,
    this.eta,
    this.batchInfo,
    this.earnings,
    this.proofOfDeliveryUrl,
    this.municipalityOverride = false,
    this.municipality,
    this.vendorId,
    this.vendorName,
    this.vendorPhone,
    this.pickupAddress,
    this.riderName,
    this.riderPhone,
    this.vehiclePlate,
    this.baseDeliveryFee,
    this.expressDeliveryFee,
    this.heavyItemSurcharge,
    this.timeWindowFee,
    this.baseDistance, // ✅
    this.excessFee, // ✅
    this.totalDistance,
    this.crossMunicipalityBonus,
    this.riderMunicipality,
    this.crossMunicipalityNote,
    this.requiresCustomerAction = false,
    this.actionRequired,
  });

  factory DeliveryInfo.fromJson(Map<String, dynamic> json) {
    // ✅ FIXED: Parse earnings from multiple possible sources
    // Priority: 1) delivery.earnings 2) commission.riderNetEarnings (municipality-based)
    double? earnings = json['earnings']?.toDouble();

    // Check if parent has commission data with riderNetEarnings
    // This is set by backend Order.calculateCommission() with municipality overrides
    if (earnings == null || earnings == 0) {
      final commission = json['commission'] as Map<String, dynamic>?;
      if (commission != null) {
        earnings = commission['riderNetEarnings']?.toDouble();
      }
    }

    // ✅ NEW: Extract municipality override info from commission
    bool municipalityOverride = false;
    String? municipality;
    final commission = json['commission'] as Map<String, dynamic>?;
    if (commission != null) {
      final ratesApplied = commission['ratesApplied'] as Map<String, dynamic>?;
      if (ratesApplied != null) {
        municipalityOverride = ratesApplied['municipalityOverride'] == true;
        municipality = ratesApplied['municipality']?.toString();
      }
    }

    // Extract cross-municipality compensation info
    double? crossMunicipalityBonus;
    String? riderMunicipality;
    String? crossMunicipalityNote;
    if (commission != null) {
      crossMunicipalityBonus = (commission['crossMunicipalityBonus'] as num?)?.toDouble();
      riderMunicipality = commission['riderMunicipality']?.toString();
      crossMunicipalityNote = commission['crossMunicipalityNote']?.toString();
    }

    return DeliveryInfo(
      type: json['type']?.toString(),
      assignedTo: json['assignedTo']?.toString(),
      eta: json['eta'] != null ? DeliveryETA.fromJson(json['eta']) : null,
      batchInfo: json['batchInfo'] != null
          ? DeliveryBatchInfo.fromJson(json['batchInfo'])
          : null,
      earnings: earnings,
      proofOfDeliveryUrl:
          json['proofOfDeliveryUrl']?.toString() ??
          json['proofPhotoUrl']?.toString(),
      municipalityOverride: municipalityOverride,
      municipality: municipality,
      vendorId:
          json['vendorId']?.toString() ?? json['vendor']?['_id']?.toString(),
      vendorName:
          json['vendorName']?.toString() ??
          json['vendor']?['businessName']?.toString(),
      vendorPhone:
          json['vendorPhone']?.toString() ??
          json['vendor']?['phone']?.toString(),
      pickupAddress: json['pickupAddress'] != null
          ? PickupAddress.fromJson(json['pickupAddress'])
          : (json['vendor']?['storeAddress'] != null
                ? PickupAddress.fromJson(json['vendor']['storeAddress'])
                : null),
      riderName: json['riderName']?.toString(),
      riderPhone: json['riderPhone']?.toString(),
      vehiclePlate: json['vehiclePlate']?.toString(),
      baseDeliveryFee: (json['baseDeliveryFee'] as num?)?.toDouble(),
      expressDeliveryFee: (json['expressDeliveryFee'] as num?)?.toDouble(),
      heavyItemSurcharge: (json['heavyItemSurcharge'] as num?)?.toDouble(),
      timeWindowFee: (json['timeWindowFee'] as num?)?.toDouble(),
      baseDistance: (json['baseDistance'] as num?)?.toDouble(), // ✅
      excessFee: (json['distanceFee'] as num?)
          ?.toDouble(), // ✅ Map backend 'distanceFee' to excessFee
      // Check both route.totalDistance and optimizedRoute.totalDistance or direct field
      totalDistance:
          (json['totalDistance'] as num?)?.toDouble() ??
          (json['route']?['totalDistance'] as num?)?.toDouble() ??
          (json['optimizedRoute']?['totalDistance'] as num?)?.toDouble(),
      crossMunicipalityBonus: crossMunicipalityBonus,
      riderMunicipality: riderMunicipality,
      crossMunicipalityNote: crossMunicipalityNote,
      requiresCustomerAction: json['requiresCustomerAction'] == true,
      actionRequired: json['actionRequired']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'assignedTo': assignedTo,
    'eta': eta?.toJson(),
    'batchInfo': batchInfo?.toJson(),
    'earnings': earnings,
    'proofOfDeliveryUrl': proofOfDeliveryUrl,
    'municipalityOverride': municipalityOverride,
    'municipality': municipality,
    'vendorId': vendorId,
    'vendorName': vendorName,
    'vendorPhone': vendorPhone,
    'pickupAddress': pickupAddress?.toJson(),
    'riderName': riderName,
    'riderPhone': riderPhone,
    'vehiclePlate': vehiclePlate,
    'baseDeliveryFee': baseDeliveryFee,
    'expressDeliveryFee': expressDeliveryFee,
    'heavyItemSurcharge': heavyItemSurcharge,
    'timeWindowFee': timeWindowFee,
    'baseDistance': baseDistance, // ✅
    'distanceFee': excessFee, // ✅ Map back to backend expectation if needed
    'totalDistance': totalDistance,
    'crossMunicipalityBonus': crossMunicipalityBonus,
    'riderMunicipality': riderMunicipality,
    'crossMunicipalityNote': crossMunicipalityNote,
    'requiresCustomerAction': requiresCustomerAction,
    'actionRequired': actionRequired,
  };
}

// 🆕 Pickup Address for vendor store location
class PickupAddress {
  final String? storeName;
  final String? street;
  final String? barangay;
  final String? city;
  final String? region;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? landmark;

  PickupAddress({
    this.storeName,
    this.street,
    this.barangay,
    this.city,
    this.region,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.landmark,
  });

  factory PickupAddress.fromJson(Map<String, dynamic> json) {
    return PickupAddress(
      storeName: json['storeName']?.toString() ?? json['name']?.toString(),
      street: json['street']?.toString(),
      barangay: json['barangay']?.toString(),
      city: json['city']?.toString(),
      region: json['region']?.toString(),
      postalCode: json['postalCode']?.toString(),
      latitude: json['latitude']?.toDouble() ?? json['lat']?.toDouble(),
      longitude: json['longitude']?.toDouble() ?? json['lng']?.toDouble(),
      landmark: json['landmark']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'storeName': storeName,
    'street': street,
    'barangay': barangay,
    'city': city,
    'region': region,
    'postalCode': postalCode,
    'latitude': latitude,
    'longitude': longitude,
    'landmark': landmark,
  };

  String get fullAddress {
    final parts = [
      street,
      barangay,
      city,
      region,
      postalCode,
    ].where((p) => p != null && p.isNotEmpty).toList();
    return parts.join(', ');
  }

  bool get hasCoordinates => latitude != null && longitude != null;
}

class DeliveryETA {
  final DateTime? calculated;
  final int? confidence; // 0-100

  DeliveryETA({this.calculated, this.confidence});

  factory DeliveryETA.fromJson(Map<String, dynamic> json) {
    return DeliveryETA(
      calculated: json['calculated'] != null
          ? DateTime.parse(json['calculated'])
          : null,
      confidence: json['confidence'],
    );
  }

  Map<String, dynamic> toJson() => {
    'calculated': calculated?.toIso8601String(),
    'confidence': confidence,
  };
}

class DeliveryBatchInfo {
  final String? batchId;
  final String? batchCode;
  final String? barangay;
  final int? currentBatchSize;
  final int? targetBatchSize;
  final String? batchStatus; // 'collecting', 'ready', 'assigned', 'in_transit', 'completed'
  final String? batchTypeName;
  final String? batchTypeCode;
  final double? feeMultiplier;
  final double? originalFee;
  final double? discountedFee;
  final double? savings;
  final DateTime? estimatedDispatch;
  final DateTime? expiresAt;
  final int? memberCount;
  final double? progress;
  final int? slotsRemaining;
  final int? expiresInMinutes;

  DeliveryBatchInfo({
    this.batchId,
    this.batchCode,
    this.barangay,
    this.currentBatchSize,
    this.targetBatchSize,
    this.batchStatus,
    this.batchTypeName,
    this.batchTypeCode,
    this.feeMultiplier,
    this.originalFee,
    this.discountedFee,
    this.savings,
    this.estimatedDispatch,
    this.expiresAt,
    this.memberCount,
    this.progress,
    this.slotsRemaining,
    this.expiresInMinutes,
  });

  factory DeliveryBatchInfo.fromJson(Map<String, dynamic> json) {
    final current = json['currentBatchSize'] as int? ?? json['currentOrders'] as int? ?? 0;
    final target = json['targetBatchSize'] as int? ?? json['targetOrders'] as int? ?? 0;

    return DeliveryBatchInfo(
      batchId: json['batchId']?.toString() ?? json['batchCode']?.toString(),
      batchCode: json['batchCode']?.toString() ?? json['batchId']?.toString(),
      barangay: json['barangay']?.toString(),
      currentBatchSize: current,
      targetBatchSize: target,
      batchStatus: json['batchStatus']?.toString() ?? json['status']?.toString(),
      batchTypeName: json['batchTypeName']?.toString(),
      batchTypeCode: json['batchTypeCode']?.toString(),
      feeMultiplier: (json['feeMultiplier'] as num?)?.toDouble(),
      originalFee: (json['originalFee'] as num?)?.toDouble(),
      discountedFee: (json['discountedFee'] as num?)?.toDouble(),
      savings: (json['savings'] as num?)?.toDouble(),
      estimatedDispatch: json['estimatedBatchDate'] != null
          ? DateTime.tryParse(json['estimatedBatchDate'].toString())
          : (json['estimatedDispatch'] != null
              ? DateTime.tryParse(json['estimatedDispatch'].toString())
              : null),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      memberCount: json['memberCount'] as int? ?? current,
      progress: (json['progress'] as num?)?.toDouble() ??
          (target > 0 ? current / target : 0.0),
      slotsRemaining: json['slotsRemaining'] as int? ?? (target - current),
      expiresInMinutes: json['expiresIn'] as int? ?? json['expiresInMinutes'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'batchId': batchId,
    'batchCode': batchCode,
    'barangay': barangay,
    'currentBatchSize': currentBatchSize,
    'targetBatchSize': targetBatchSize,
    'batchStatus': batchStatus,
    'batchTypeName': batchTypeName,
    'batchTypeCode': batchTypeCode,
    'feeMultiplier': feeMultiplier,
    'originalFee': originalFee,
    'discountedFee': discountedFee,
    'savings': savings,
    'estimatedBatchDate': estimatedDispatch?.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'memberCount': memberCount,
    'progress': progress,
    'slotsRemaining': slotsRemaining,
    'expiresInMinutes': expiresInMinutes,
  };

  /// Whether this batch is actively collecting orders
  bool get isCollecting => batchStatus == 'collecting' || batchStatus == 'WAITING';

  /// Whether this batch is ready for dispatch
  bool get isReady => batchStatus == 'ready' || batchStatus == 'READY';

  /// Human-readable progress string
  String get progressText => '${currentBatchSize ?? 0}/${targetBatchSize ?? 0}';
}
