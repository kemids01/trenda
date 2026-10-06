// trenda_shared/lib/models/approval_model.dart
// Models for vendor approval requests

/// Approval request model
class ApprovalRequest {
  final String id;
  final String vendor;
  final String vendorName;
  final String type; // store_settings, account_settings
  final String status; // pending, approved, rejected
  final Map<String, dynamic> previousData;
  final Map<String, dynamic> requestedData;
  final String? adminNotes;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  ApprovalRequest({
    required this.id,
    required this.vendor,
    required this.vendorName,
    required this.type,
    required this.status,
    required this.previousData,
    required this.requestedData,
    this.adminNotes,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    return ApprovalRequest(
      id: json['_id'] ?? json['id'] ?? '',
      vendor: json['vendor'] ?? '',
      vendorName: json['vendorName'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? 'pending',
      previousData: Map<String, dynamic>.from(json['previousData'] ?? {}),
      requestedData: Map<String, dynamic>.from(json['requestedData'] ?? {}),
      adminNotes: json['adminNotes'],
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'])
          : (json['createdAt'] != null
                ? DateTime.parse(json['createdAt'])
                : DateTime.now()),
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.parse(json['reviewedAt'])
          : null,
      reviewedBy: json['reviewedBy']?['name'] ?? json['reviewedBy']?.toString(),
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get typeDisplayName {
    switch (type) {
      case 'store_settings':
        return 'Store Settings';
      case 'account_settings':
        return 'Account Settings';
      case 'address_change':
        return 'Address Change';
      case 'profile_picture':
        return 'Profile Picture';
      default:
        return type;
    }
  }
}

/// Result for paginated approval list
class ApprovalListResult {
  final List<ApprovalRequest> requests;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  ApprovalListResult({
    required this.requests,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory ApprovalListResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List? ?? [];
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};

    return ApprovalListResult(
      requests: data.map((e) => ApprovalRequest.fromJson(e)).toList(),
      page: pagination['page'] ?? 1,
      limit: pagination['limit'] ?? 20,
      total: pagination['total'] ?? data.length,
      totalPages: pagination['totalPages'] ?? 1,
    );
  }

  bool get hasMore => page < totalPages;
}

/// Result for approval request details with vendor info
class ApprovalDetailResult {
  final ApprovalRequest request;
  final VendorSummary? vendor;

  ApprovalDetailResult({required this.request, this.vendor});

  factory ApprovalDetailResult.fromJson(Map<String, dynamic> json) {
    return ApprovalDetailResult(
      request: ApprovalRequest.fromJson(json['request']),
      vendor: json['vendor'] != null
          ? VendorSummary.fromJson(json['vendor'])
          : null,
    );
  }
}

/// Simple vendor summary for approval details
class VendorSummary {
  final String businessName;
  final String ownerName;
  final String? email;
  final String? phone;
  final String? profilePicture;

  VendorSummary({
    required this.businessName,
    required this.ownerName,
    this.email,
    this.phone,
    this.profilePicture,
  });

  factory VendorSummary.fromJson(Map<String, dynamic> json) {
    return VendorSummary(
      businessName: json['businessName'] ?? '',
      ownerName: json['ownerName'] ?? '',
      email: json['email'],
      phone: json['phone'],
      profilePicture: json['profilePicture'],
    );
  }
}

/// Approval statistics
class ApprovalStats {
  final ApprovalStatusStats pending;
  final ApprovalStatusStats approved;
  final ApprovalStatusStats rejected;

  ApprovalStats({
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  factory ApprovalStats.fromJson(Map<String, dynamic> json) {
    return ApprovalStats(
      pending: ApprovalStatusStats.fromJson(json['pending'] ?? {}),
      approved: ApprovalStatusStats.fromJson(json['approved'] ?? {}),
      rejected: ApprovalStatusStats.fromJson(json['rejected'] ?? {}),
    );
  }

  int get totalPending => pending.total;
}

class ApprovalStatusStats {
  final int total;
  final int storeSettings;
  final int accountSettings;

  ApprovalStatusStats({
    required this.total,
    required this.storeSettings,
    required this.accountSettings,
  });

  factory ApprovalStatusStats.fromJson(Map<String, dynamic> json) {
    return ApprovalStatusStats(
      total: json['total'] ?? 0,
      storeSettings: json['store_settings'] ?? 0,
      accountSettings: json['account_settings'] ?? 0,
    );
  }
}
