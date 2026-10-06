// trenda_frontend/lib/features/checkout/data/pasabay_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// GET /api/pasabay/batches/:municipality/:barangay, with both NAMES as single path segments.
///
/// ⚠️ Built with `Uri.pathSegments` rather than string interpolation. Spaces were never the problem
/// (Dart percent-encodes those itself), but a SLASH in a name becomes a path separator: the route
/// gains an extra segment, stops matching, and the 404 is swallowed into a silent "no batches".
/// Two live PSGC barangays carry one — `Camalaggoan/D Leaño` and `Caddangan/Limbauan` — so pasabay
/// was unreachable for everyone in either. `#` and `?` would likewise escape into a fragment/query.
Uri activeBatchesUri(String baseUrl, String municipality, String barangay) {
  final base = Uri.parse(baseUrl);
  return base.replace(
    pathSegments: [
      ...base.pathSegments.where((s) => s.isNotEmpty),
      'api', 'pasabay', 'batches', municipality, barangay,
    ],
  );
}

class PasabayRepository {
  final String baseUrl;
  final String Function() getToken;

  PasabayRepository({required this.baseUrl, required this.getToken});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${getToken()}',
      };

  /// Get active batches in a barangay
  Future<PasabayBatchesResponse> getActiveBatches(
      String municipality, String barangay) async {
    try {
      final uri = activeBatchesUri(baseUrl, municipality, barangay);
      final response = await http.get(uri, headers: _headers);
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return PasabayBatchesResponse.fromJson(data['data']);
      }
      return PasabayBatchesResponse(batches: [], enabled: false);
    } catch (e) {
      return PasabayBatchesResponse(batches: [], enabled: false);
    }
  }

  /// Preview fee for all batch types
  Future<List<PasabayFeePreview>> previewFees({
    required String municipality,
    required String barangay,
    double? normalDeliveryFee,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/pasabay/fee-preview');
      final response = await http.post(
        uri,
        headers: _headers,
        body: json.encode({
          'municipality': municipality,
          'barangay': barangay,
          'normalDeliveryFee': normalDeliveryFee,
        }),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final previews = data['data']['previews'] as List? ?? [];
        return previews.map((p) => PasabayFeePreview.fromJson(p)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Join a batch
  Future<PasabayJoinResult?> joinBatch({
    required String orderId,
    required String municipality,
    required String barangay,
    String? batchTypeId,
    double? normalDeliveryFee,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/pasabay/join');
      final response = await http.post(
        uri,
        headers: _headers,
        body: json.encode({
          'orderId': orderId,
          'municipality': municipality,
          'barangay': barangay,
          if (batchTypeId != null) 'batchTypeId': batchTypeId,
          if (normalDeliveryFee != null) 'normalDeliveryFee': normalDeliveryFee,
        }),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return PasabayJoinResult.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> leaveBatch(String batchId, String orderId) async {
    try {
      final path = batchId.isEmpty ? 'leave' : 'leave/$batchId';
      final uri = Uri.parse('$baseUrl/api/pasabay/$path');
      final response = await http.post(
        uri,
        headers: _headers,
        body: json.encode({'orderId': orderId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get batch details
  Future<Map<String, dynamic>?> getBatchDetails(String batchId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/pasabay/batch/$batchId');
      final response = await http.get(uri, headers: _headers);
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['data']['batch'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Upgrade order to Express Delivery
  Future<bool> upgradeToExpress(String orderId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/pasabay/upgrade-to-express');
      final response = await http.post(
        uri,
        headers: _headers,
        body: json.encode({'orderId': orderId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Rejoin a new batch
  Future<bool> rejoinBatch(String orderId, {String? batchTypeId}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/pasabay/rejoin-batch');
      final response = await http.post(
        uri,
        headers: _headers,
        body: json.encode({
          'orderId': orderId,
          if (batchTypeId != null) 'batchTypeId': batchTypeId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Change delivery type of an order
  Future<bool> changeDeliveryType(String orderId, String newDeliveryType, {String? batchTypeId}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/checkout/orders/$orderId/change-delivery-type');
      final response = await http.put(
        uri,
        headers: _headers,
        body: json.encode({
          'newDeliveryType': newDeliveryType,
          if (batchTypeId != null) 'batchTypeId': batchTypeId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

// ── Response Models ────────────────────────────────────────────────────

class PasabayBatchesResponse {
  final List<PasabayActiveBatch> batches;
  final bool enabled;
  final bool allowCustomerBatchCreation;
  final int maxActiveBatches;

  PasabayBatchesResponse({
    required this.batches,
    this.enabled = true,
    this.allowCustomerBatchCreation = false,
    this.maxActiveBatches = 5,
  });

  factory PasabayBatchesResponse.fromJson(Map<String, dynamic> json) {
    final batchList = json['batches'] as List? ?? [];
    final config = json['barangayConfig'] as Map<String, dynamic>? ?? {};

    return PasabayBatchesResponse(
      batches: batchList.map((b) => PasabayActiveBatch.fromJson(b)).toList(),
      enabled: json['enabled'] ?? true,
      allowCustomerBatchCreation:
          config['allowCustomerBatchCreation'] ?? false,
      maxActiveBatches: config['maxActiveBatches'] ?? 5,
    );
  }
}

class PasabayActiveBatch {
  final String id;
  final String batchCode;
  final String barangay;
  final int currentOrders;
  final int targetOrders;
  final String status;
  final double progress;
  final int slotsRemaining;
  final int expiresInMinutes;
  final DateTime? expiresAt;
  final PasabayBatchTypeInfo? batchType;
  final PasabayFeeInfo? feeInfo;

  PasabayActiveBatch({
    required this.id,
    required this.batchCode,
    required this.barangay,
    required this.currentOrders,
    required this.targetOrders,
    required this.status,
    required this.progress,
    required this.slotsRemaining,
    required this.expiresInMinutes,
    this.expiresAt,
    this.batchType,
    this.feeInfo,
  });

  factory PasabayActiveBatch.fromJson(Map<String, dynamic> json) {
    return PasabayActiveBatch(
      id: json['_id']?.toString() ?? '',
      batchCode: json['batchCode']?.toString() ?? '',
      barangay: json['barangay']?.toString() ?? '',
      currentOrders: json['currentOrders'] ?? 0,
      targetOrders: json['targetOrders'] ?? 0,
      status: json['status']?.toString() ?? 'WAITING',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      slotsRemaining: json['slotsRemaining'] ?? 0,
      expiresInMinutes: json['expiresIn'] ?? 0,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      batchType: json['batchType'] != null
          ? PasabayBatchTypeInfo.fromJson(json['batchType'])
          : null,
      feeInfo: json['feeInfo'] != null
          ? PasabayFeeInfo.fromJson(json['feeInfo'])
          : null,
    );
  }
}

class PasabayBatchTypeInfo {
  final String id;
  final String name;
  final String code;
  final int targetOrders;
  final String? description;
  final String? icon;
  final String? color;
  final double? feeMultiplier;
  final double? flatFee;

  /// How long a batch of this tier waits to fill before it times out.
  final int? timeoutMinutes;

  /// False for a tier an admin switched off. Absent = active (older payloads).
  final bool active;

  PasabayBatchTypeInfo({
    required this.id,
    required this.name,
    required this.code,
    required this.targetOrders,
    this.description,
    this.icon,
    this.color,
    this.feeMultiplier,
    this.flatFee,
    this.timeoutMinutes,
    this.active = true,
  });

  factory PasabayBatchTypeInfo.fromJson(Map<String, dynamic> json) {
    return PasabayBatchTypeInfo(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      targetOrders: json['targetOrders'] ?? 5,
      description: json['description']?.toString(),
      icon: json['icon']?.toString(),
      color: json['color']?.toString(),
      feeMultiplier: (json['feeMultiplier'] as num?)?.toDouble(),
      flatFee: (json['flatFee'] as num?)?.toDouble(),
      timeoutMinutes: (json['timeoutMinutes'] as num?)?.toInt(),
      active: json['active'] != false,
    );
  }
}

class PasabayFeeInfo {
  final double originalFee;
  final double discountedFee;
  final double savings;
  final String feeMode;
  final double multiplier;
  final String batchTypeName;

  PasabayFeeInfo({
    required this.originalFee,
    required this.discountedFee,
    required this.savings,
    required this.feeMode,
    required this.multiplier,
    required this.batchTypeName,
  });

  factory PasabayFeeInfo.fromJson(Map<String, dynamic> json) {
    return PasabayFeeInfo(
      originalFee: (json['originalFee'] as num?)?.toDouble() ?? 0,
      discountedFee: (json['discountedFee'] as num?)?.toDouble() ?? 0,
      savings: (json['savings'] as num?)?.toDouble() ?? 0,
      feeMode: json['feeMode']?.toString() ?? 'multiplier',
      multiplier: (json['multiplier'] as num?)?.toDouble() ?? 0,
      batchTypeName: json['batchTypeName']?.toString() ?? '',
    );
  }

  int get savingsPercent =>
      originalFee > 0 ? ((savings / originalFee) * 100).round() : 0;
}

class PasabayFeePreview {
  final PasabayBatchTypeInfo? batchType;
  final PasabayFeeInfo? feeInfo;

  PasabayFeePreview({this.batchType, this.feeInfo});

  factory PasabayFeePreview.fromJson(Map<String, dynamic> json) {
    return PasabayFeePreview(
      batchType: json['batchType'] != null
          ? PasabayBatchTypeInfo.fromJson(json['batchType'])
          : null,
      feeInfo: json['feeInfo'] != null
          ? PasabayFeeInfo.fromJson(json['feeInfo'])
          : null,
    );
  }
}

class PasabayJoinResult {
  final Map<String, dynamic>? batch;
  final PasabayFeeInfo? feeInfo;
  final Map<String, dynamic>? order;

  PasabayJoinResult({this.batch, this.feeInfo, this.order});

  factory PasabayJoinResult.fromJson(Map<String, dynamic> json) {
    return PasabayJoinResult(
      batch: json['batch'] as Map<String, dynamic>?,
      feeInfo: json['feeInfo'] != null
          ? PasabayFeeInfo.fromJson(json['feeInfo'])
          : null,
      order: json['order'] as Map<String, dynamic>?,
    );
  }
}
