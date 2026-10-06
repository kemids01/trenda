// trenda_shared/lib/models/security_model.dart
// Security models for API keys, 2FA, and audit logs

/// API Key for vendor integrations
class APIKey {
  final String id;
  final String name;
  final String keyPrefix; // First 8 chars for display
  final String? fullKey; // Only available on creation
  final List<String> permissions;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final DateTime? expiresAt;
  final int usageCount;

  APIKey({
    required this.id,
    required this.name,
    required this.keyPrefix,
    this.fullKey,
    this.permissions = const [],
    this.isActive = true,
    required this.createdAt,
    this.lastUsedAt,
    this.expiresAt,
    this.usageCount = 0,
  });

  factory APIKey.fromJson(Map<String, dynamic> json) {
    return APIKey(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? 'Unnamed Key',
      keyPrefix: json['keyPrefix'] ?? json['prefix'] ?? '********',
      fullKey: json['fullKey'] ?? json['key'],
      permissions: List<String>.from(json['permissions'] ?? []),
      isActive: json['isActive'] ?? json['active'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.tryParse(json['lastUsedAt'])
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'])
          : null,
      usageCount: json['usageCount'] ?? json['usage']?['count'] ?? 0,
    );
  }

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
}

/// Audit log entry
class AuditLogEntry {
  final String id;
  final String action;
  final String resource;
  final String? resourceId;
  final String severity; // info, warning, critical
  final Map<String, dynamic>? details;
  final String? ipAddress;
  final String? userAgent;
  final DateTime timestamp;

  AuditLogEntry({
    required this.id,
    required this.action,
    required this.resource,
    this.resourceId,
    required this.severity,
    this.details,
    this.ipAddress,
    this.userAgent,
    required this.timestamp,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['_id'] ?? json['id'] ?? '',
      action: json['action'] ?? '',
      resource: json['resource'] ?? json['resourceType'] ?? '',
      resourceId: json['resourceId'],
      severity: json['severity'] ?? 'info',
      details: json['details'] ?? json['metadata'],
      ipAddress: json['ipAddress'] ?? json['ip'],
      userAgent: json['userAgent'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : (json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now()),
    );
  }
}

/// Two-Factor Authentication status
class TwoFactorStatus {
  final bool isEnabled;
  final String? method; // totp, sms
  final DateTime? enabledAt;
  final int backupCodesRemaining;
  final bool hasBackupCodes;

  TwoFactorStatus({
    required this.isEnabled,
    this.method,
    this.enabledAt,
    this.backupCodesRemaining = 0,
    this.hasBackupCodes = false,
  });

  factory TwoFactorStatus.fromJson(Map<String, dynamic> json) {
    return TwoFactorStatus(
      isEnabled: json['isEnabled'] ?? json['enabled'] ?? false,
      method: json['method'],
      enabledAt: json['enabledAt'] != null
          ? DateTime.tryParse(json['enabledAt'])
          : null,
      backupCodesRemaining: json['backupCodesRemaining'] ?? json['backupCodes']?['remaining'] ?? 0,
      hasBackupCodes: json['hasBackupCodes'] ?? (json['backupCodesRemaining'] ?? 0) > 0,
    );
  }
}

/// 2FA setup response
class TwoFactorSetup {
  final String secret;
  final String qrCodeUrl;
  final String otpauthUrl;

  TwoFactorSetup({
    required this.secret,
    required this.qrCodeUrl,
    required this.otpauthUrl,
  });

  factory TwoFactorSetup.fromJson(Map<String, dynamic> json) {
    return TwoFactorSetup(
      secret: json['secret'] ?? '',
      qrCodeUrl: json['qrCodeUrl'] ?? json['qrCode'] ?? '',
      otpauthUrl: json['otpauthUrl'] ?? json['otpauth'] ?? '',
    );
  }
}

/// Backup codes response
class BackupCodesResponse {
  final List<String> codes;
  final DateTime generatedAt;

  BackupCodesResponse({
    required this.codes,
    required this.generatedAt,
  });

  factory BackupCodesResponse.fromJson(Map<String, dynamic> json) {
    return BackupCodesResponse(
      codes: List<String>.from(json['codes'] ?? json['backupCodes'] ?? []),
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'])
          : DateTime.now(),
    );
  }
}

/// IP Whitelist entry
class IPWhitelistEntry {
  final String id;
  final String ipAddress;
  final String? label;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  IPWhitelistEntry({
    required this.id,
    required this.ipAddress,
    this.label,
    this.isActive = true,
    required this.createdAt,
    this.lastUsedAt,
  });

  factory IPWhitelistEntry.fromJson(Map<String, dynamic> json) {
    return IPWhitelistEntry(
      id: json['_id'] ?? json['id'] ?? '',
      ipAddress: json['ipAddress'] ?? json['ip'] ?? '',
      label: json['label'] ?? json['description'],
      isActive: json['isActive'] ?? json['active'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.tryParse(json['lastUsedAt'])
          : null,
    );
  }
}

/// Webhook configuration
class WebhookConfig {
  final String id;
  final String url;
  final List<String> events;
  final String? secret;
  final bool isActive;
  final DateTime createdAt;
  final WebhookStats? stats;

  WebhookConfig({
    required this.id,
    required this.url,
    required this.events,
    this.secret,
    this.isActive = true,
    required this.createdAt,
    this.stats,
  });

  factory WebhookConfig.fromJson(Map<String, dynamic> json) {
    return WebhookConfig(
      id: json['_id'] ?? json['id'] ?? '',
      url: json['url'] ?? '',
      events: List<String>.from(json['events'] ?? []),
      secret: json['secret'],
      isActive: json['isActive'] ?? json['active'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      stats: json['stats'] != null
          ? WebhookStats.fromJson(json['stats'])
          : null,
    );
  }
}

class WebhookStats {
  final int totalCalls;
  final int successfulCalls;
  final int failedCalls;
  final DateTime? lastCalledAt;

  WebhookStats({
    required this.totalCalls,
    required this.successfulCalls,
    required this.failedCalls,
    this.lastCalledAt,
  });

  factory WebhookStats.fromJson(Map<String, dynamic> json) {
    return WebhookStats(
      totalCalls: json['totalCalls'] ?? json['total'] ?? 0,
      successfulCalls: json['successfulCalls'] ?? json['success'] ?? 0,
      failedCalls: json['failedCalls'] ?? json['failed'] ?? 0,
      lastCalledAt: json['lastCalledAt'] != null
          ? DateTime.tryParse(json['lastCalledAt'])
          : null,
    );
  }
}

/// Security overview
class SecurityOverview {
  final TwoFactorStatus twoFactor;
  final int activeApiKeys;
  final int activeWebhooks;
  final int ipWhitelistCount;
  final int recentSecurityEvents;
  final DateTime? lastPasswordChange;
  final DateTime? lastLogin;

  SecurityOverview({
    required this.twoFactor,
    required this.activeApiKeys,
    required this.activeWebhooks,
    required this.ipWhitelistCount,
    required this.recentSecurityEvents,
    this.lastPasswordChange,
    this.lastLogin,
  });

  factory SecurityOverview.fromJson(Map<String, dynamic> json) {
    return SecurityOverview(
      twoFactor: TwoFactorStatus.fromJson(json['twoFactor'] ?? json['2fa'] ?? {}),
      activeApiKeys: json['activeApiKeys'] ?? json['apiKeys'] ?? 0,
      activeWebhooks: json['activeWebhooks'] ?? json['webhooks'] ?? 0,
      ipWhitelistCount: json['ipWhitelistCount'] ?? json['ipWhitelist'] ?? 0,
      recentSecurityEvents: json['recentSecurityEvents'] ?? 0,
      lastPasswordChange: json['lastPasswordChange'] != null
          ? DateTime.tryParse(json['lastPasswordChange'])
          : null,
      lastLogin: json['lastLogin'] != null
          ? DateTime.tryParse(json['lastLogin'])
          : null,
    );
  }
}
