// trenda_shared/lib/models/performance_model.dart
// Vendor performance models

/// Vendor performance metrics
class VendorPerformance {
  final String vendorId;
  final PerformanceScore score;
  final PerformanceMetrics metrics;
  final String tier;
  final bool isSuspended;
  final DateTime? suspendedUntil;
  final DateTime lastUpdated;

  VendorPerformance({
    required this.vendorId,
    required this.score,
    required this.metrics,
    required this.tier,
    this.isSuspended = false,
    this.suspendedUntil,
    required this.lastUpdated,
  });

  factory VendorPerformance.fromJson(Map<String, dynamic> json) {
    // Safely extract performance score data
    final perfScoreRaw =
        json['performanceScore'] ??
        json['score'] ??
        json['currentScore'] ??
        <String, dynamic>{};
    final perfScore = perfScoreRaw is Map
        ? Map<String, dynamic>.from(perfScoreRaw)
        : <String, dynamic>{};

    // Safely extract metrics data
    final metricsRaw =
        json['metrics'] ?? json['current'] ?? <String, dynamic>{};
    final metricsData = metricsRaw is Map
        ? Map<String, dynamic>.from(metricsRaw)
        : <String, dynamic>{};

    return VendorPerformance(
      vendorId:
          json['vendorId']?.toString() ?? json['vendor']?.toString() ?? '',
      score: PerformanceScore.fromJson(perfScore),
      metrics: PerformanceMetrics.fromJson(metricsData),
      tier:
          perfScore['tier']?.toString() ??
          json['tier']?.toString() ??
          'standard',
      isSuspended: json['isSuspended'] == true || json['suspended'] == true,
      suspendedUntil: _parseDateTime(
        json['suspendedUntil'] ?? json['suspensionEndsAt'],
      ),
      lastUpdated:
          _parseDateTime(json['lastUpdated'] ?? json['updatedAt']) ??
          DateTime.now(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

/// Performance score breakdown
class PerformanceScore {
  final double overall;
  final double orderFulfillment;
  final double customerSatisfaction;
  final double responseTime;
  final double returnRate;
  final double qualityScore;

  PerformanceScore({
    required this.overall,
    required this.orderFulfillment,
    required this.customerSatisfaction,
    required this.responseTime,
    required this.returnRate,
    required this.qualityScore,
  });

  factory PerformanceScore.fromJson(Map<String, dynamic> json) {
    // Backend returns: { overallScore: 85, scores: { orderFulfillment: { score: 90, weight: 0.25 }, ... } }
    // Or it may come wrapped: { score: { overallScore: 85, ... }, status: '...' }
    final scoreData = json['score'] is Map
        ? Map<String, dynamic>.from(json['score'] as Map)
        : json;
    final scoresObj = scoreData['scores'] is Map
        ? Map<String, dynamic>.from(scoreData['scores'] as Map)
        : <String, dynamic>{};

    return PerformanceScore(
      overall:
          (scoreData['overallScore'] ??
                  scoreData['overall'] ??
                  json['total'] ??
                  0)
              .toDouble(),
      orderFulfillment: _extractScore(scoresObj['orderFulfillment']),
      customerSatisfaction: _extractScore(scoresObj['customerSatisfaction']),
      responseTime: _extractScore(
        scoresObj['customerService'],
      ), // Backend calls it customerService
      returnRate: _extractScore(
        scoresObj['shipping'],
      ), // Use shipping for delivery/return performance
      qualityScore: _extractScore(scoresObj['quality']),
    );
  }

  static double _extractScore(dynamic scoreObj) {
    if (scoreObj == null) return 0.0;
    if (scoreObj is num) return scoreObj.toDouble();
    if (scoreObj is Map) return (scoreObj['score'] ?? 0).toDouble();
    return 0.0;
  }

  String get grade {
    if (overall >= 90) return 'A';
    if (overall >= 80) return 'B';
    if (overall >= 70) return 'C';
    if (overall >= 60) return 'D';
    return 'F';
  }
}

/// Performance metrics details
class PerformanceMetrics {
  final int totalOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int lateShipments;
  final double avgResponseTimeHours;
  final double avgRating;
  final int totalReviews;
  final int totalReturns;
  final double returnRate;

  PerformanceMetrics({
    required this.totalOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.lateShipments,
    required this.avgResponseTimeHours,
    required this.avgRating,
    required this.totalReviews,
    required this.totalReturns,
    required this.returnRate,
  });

  factory PerformanceMetrics.fromJson(Map<String, dynamic> json) {
    // Backend structure: { orders: { total, cancelled, ... }, shipments: { late, ... }, ... }
    final orders = json['orders'] is Map
        ? Map<String, dynamic>.from(json['orders'] as Map)
        : <String, dynamic>{};
    final shipments = json['shipments'] is Map
        ? Map<String, dynamic>.from(json['shipments'] as Map)
        : <String, dynamic>{};
    final responses = json['responses'] is Map
        ? Map<String, dynamic>.from(json['responses'] as Map)
        : <String, dynamic>{};
    final satisfaction = json['satisfaction'] is Map
        ? Map<String, dynamic>.from(json['satisfaction'] as Map)
        : <String, dynamic>{};

    return PerformanceMetrics(
      totalOrders: orders['total'] ?? json['totalOrders'] ?? 0,
      completedOrders: orders['completed'] ?? json['completedOrders'] ?? 0,
      cancelledOrders: orders['cancelled'] ?? json['cancelledOrders'] ?? 0,
      lateShipments: shipments['late'] ?? json['lateShipments'] ?? 0,
      avgResponseTimeHours:
          (responses['avgResponseTime'] ??
                  json['avgResponseTimeHours'] ??
                  json['avgResponseTime'] ??
                  0)
              .toDouble(),
      avgRating: (satisfaction['averageRating'] ?? json['avgRating'] ?? 0)
          .toDouble(),
      totalReviews: satisfaction['totalReviews'] ?? json['totalReviews'] ?? 0,
      totalReturns: orders['returned'] ?? json['totalReturns'] ?? 0,
      returnRate: (orders['returnRate'] ?? json['returnRate'] ?? 0).toDouble(),
    );
  }

  double get fulfillmentRate =>
      totalOrders > 0 ? (completedOrders / totalOrders) * 100 : 0;
}

/// Performance warning
class PerformanceWarning {
  final String id;
  final String type;
  final String severity; // low, medium, high, critical
  final String message;
  final String? actionRequired;
  final bool isAcknowledged;
  final DateTime? acknowledgedAt;
  final DateTime createdAt;
  final DateTime? expiresAt;

  PerformanceWarning({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    this.actionRequired,
    this.isAcknowledged = false,
    this.acknowledgedAt,
    required this.createdAt,
    this.expiresAt,
  });

  factory PerformanceWarning.fromJson(Map<String, dynamic> json) {
    return PerformanceWarning(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? 'general',
      severity: json['severity'] ?? 'medium',
      message: json['message'] ?? '',
      actionRequired: json['actionRequired'],
      isAcknowledged: json['isAcknowledged'] ?? json['acknowledged'] ?? false,
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.tryParse(json['acknowledgedAt'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'])
          : null,
    );
  }

  bool get isActive =>
      !isAcknowledged &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
}

/// Performance penalty
class PerformancePenalty {
  final String id;
  final String type;
  final String reason;
  final double? feeAmount;
  final String status; // active, appealed, resolved, expired
  final String? appealReason;
  final String? appealStatus; // pending, approved, rejected
  final DateTime createdAt;
  final DateTime? resolvedAt;

  PerformancePenalty({
    required this.id,
    required this.type,
    required this.reason,
    this.feeAmount,
    required this.status,
    this.appealReason,
    this.appealStatus,
    required this.createdAt,
    this.resolvedAt,
  });

  factory PerformancePenalty.fromJson(Map<String, dynamic> json) {
    return PerformancePenalty(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? 'general',
      reason: json['reason'] ?? '',
      feeAmount: json['feeAmount']?.toDouble(),
      status: json['status'] ?? 'active',
      appealReason: json['appealReason'] ?? json['appeal']?['reason'],
      appealStatus: json['appealStatus'] ?? json['appeal']?['status'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'])
          : null,
    );
  }

  bool get canAppeal => status == 'active' && appealStatus == null;
}

/// Performance reward
class PerformanceReward {
  final String id;
  final String type;
  final String title;
  final String? description;
  final double? bonusAmount;
  final String? badge;
  final bool isClaimed;
  final DateTime earnedAt;
  final DateTime? expiresAt;

  PerformanceReward({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    this.bonusAmount,
    this.badge,
    this.isClaimed = false,
    required this.earnedAt,
    this.expiresAt,
  });

  factory PerformanceReward.fromJson(Map<String, dynamic> json) {
    return PerformanceReward(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? 'achievement',
      title: json['title'] ?? json['name'] ?? '',
      description: json['description'],
      bonusAmount: json['bonusAmount']?.toDouble(),
      badge: json['badge'],
      isClaimed: json['isClaimed'] ?? json['claimed'] ?? false,
      earnedAt: json['earnedAt'] != null
          ? DateTime.parse(json['earnedAt'])
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'])
          : null,
    );
  }
}

/// Performance history entry
class PerformanceHistoryEntry {
  final String period;
  final double score;
  final String tier;
  final DateTime date;

  PerformanceHistoryEntry({
    required this.period,
    required this.score,
    required this.tier,
    required this.date,
  });

  factory PerformanceHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PerformanceHistoryEntry(
      period: json['period'] ?? '',
      score: (json['score'] ?? 0).toDouble(),
      tier: json['tier'] ?? 'standard',
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now(),
    );
  }
}
