// trenda_shared/lib/models/report_model.dart
// Report and ban models for user reporting and moderation

/// User report
class UserReport {
  final String id;
  final ReportParticipant reporter;
  final ReportParticipant reported;
  final String reason;
  final String details;
  final String? conversationId;
  final String status; // pending, reviewing, resolved, dismissed
  final String adminNotes;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String actionTaken; // none, warning, temp_ban, perm_ban, dismissed
  final DateTime createdAt;
  final DateTime updatedAt;

  UserReport({
    required this.id,
    required this.reporter,
    required this.reported,
    required this.reason,
    this.details = '',
    this.conversationId,
    this.status = 'pending',
    this.adminNotes = '',
    this.reviewedBy,
    this.reviewedAt,
    this.actionTaken = 'none',
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserReport.fromJson(Map<String, dynamic> json) {
    return UserReport(
      id: json['_id'] ?? json['id'] ?? '',
      reporter: ReportParticipant.fromJson(json['reporter'] ?? {}),
      reported: ReportParticipant.fromJson(json['reported'] ?? {}),
      reason: json['reason'] ?? '',
      details: json['details'] ?? '',
      conversationId: json['conversationId'] is Map
          ? json['conversationId']['_id']
          : json['conversationId'],
      status: json['status'] ?? 'pending',
      adminNotes: json['adminNotes'] ?? '',
      reviewedBy: json['reviewedBy'] is Map
          ? json['reviewedBy']['name']
          : json['reviewedBy'],
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.parse(json['reviewedAt'])
          : null,
      actionTaken: json['actionTaken'] ?? 'none',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  String get reasonLabel {
    switch (reason) {
      case 'spam_scam': return 'Spam / Scam';
      case 'harassment_abuse': return 'Harassment / Abuse';
      case 'inappropriate_content': return 'Inappropriate Content';
      case 'fraud_fake': return 'Fraud / Fake';
      case 'other': return 'Other';
      default: return reason;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending': return 'Pending';
      case 'reviewing': return 'Reviewing';
      case 'resolved': return 'Resolved';
      case 'dismissed': return 'Dismissed';
      default: return status;
    }
  }
}

class ReportParticipant {
  final String userId;
  final String role;
  final String? name;
  final String? email;
  final String? photoUrl;
  final String? phone;

  ReportParticipant({
    required this.userId,
    required this.role,
    this.name,
    this.email,
    this.photoUrl,
    this.phone,
  });

  factory ReportParticipant.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is Map<String, dynamic>) {
      return ReportParticipant(
        userId: user['_id'] ?? user['id'] ?? '',
        role: json['role'] ?? 'customer',
        name: user['name'] ?? user['fullName'],
        email: user['email'],
        photoUrl: user['photoUrl'] ?? user['profileImage'],
        phone: user['phone'],
      );
    }
    return ReportParticipant(
      userId: user?.toString() ?? '',
      role: json['role'] ?? 'customer',
    );
  }
}

/// User ban
class UserBan {
  final String id;
  final BanUser user;
  final String type; // temporary, permanent
  final String scope; // chat, app
  final String reason;
  final String? reportId;
  final DateTime? expiresAt;
  final bool active;
  final DateTime? removedAt;
  final String? removedByName;
  final String? removalReason;
  final String? bannedByName;
  final DateTime createdAt;

  UserBan({
    required this.id,
    required this.user,
    required this.type,
    required this.scope,
    required this.reason,
    this.reportId,
    this.expiresAt,
    this.active = true,
    this.removedAt,
    this.removedByName,
    this.removalReason,
    this.bannedByName,
    required this.createdAt,
  });

  factory UserBan.fromJson(Map<String, dynamic> json) {
    return UserBan(
      id: json['_id'] ?? json['id'] ?? '',
      user: BanUser.fromJson(json['user'] ?? {}),
      type: json['type'] ?? 'temporary',
      scope: json['scope'] ?? 'chat',
      reason: json['reason'] ?? '',
      reportId: json['report'] is Map ? json['report']['_id'] : json['report'],
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      active: json['active'] ?? true,
      removedAt: json['removedAt'] != null
          ? DateTime.parse(json['removedAt'])
          : null,
      removedByName: json['removedBy'] is Map
          ? json['removedBy']['name']
          : null,
      removalReason: json['removalReason'],
      bannedByName: json['bannedBy'] is Map
          ? json['bannedBy']['name']
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  bool get isCurrentlyActive {
    if (!active) return false;
    if (type == 'temporary' && expiresAt != null && DateTime.now().isAfter(expiresAt!)) {
      return false;
    }
    return true;
  }

  String get typeLabel => type == 'permanent' ? 'Permanent' : 'Temporary';
  String get scopeLabel => scope == 'app' ? 'Full App' : 'Chat Only';
}

class BanUser {
  final String id;
  final String? name;
  final String? email;
  final String? photoUrl;
  final String? phone;
  final List<String> roles;

  BanUser({
    required this.id,
    this.name,
    this.email,
    this.photoUrl,
    this.phone,
    this.roles = const [],
  });

  factory BanUser.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return BanUser(
        id: json['_id'] ?? json['id'] ?? '',
        name: json['name'] ?? json['fullName'],
        email: json['email'],
        photoUrl: json['photoUrl'] ?? json['profileImage'],
        phone: json['phone'],
        roles: (json['roles'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
    }
    return BanUser(id: json?.toString() ?? '');
  }
}

/// Report counts for admin dashboard
class ReportCounts {
  final int pending;
  final int reviewing;
  final int resolved;
  final int dismissed;
  final int total;

  ReportCounts({
    this.pending = 0,
    this.reviewing = 0,
    this.resolved = 0,
    this.dismissed = 0,
    this.total = 0,
  });

  factory ReportCounts.fromJson(Map<String, dynamic> json) {
    return ReportCounts(
      pending: json['pending'] ?? 0,
      reviewing: json['reviewing'] ?? 0,
      resolved: json['resolved'] ?? 0,
      dismissed: json['dismissed'] ?? 0,
      total: json['total'] ?? 0,
    );
  }
}
