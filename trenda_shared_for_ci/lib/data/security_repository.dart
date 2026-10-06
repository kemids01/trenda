// trenda_shared/lib/data/security_repository.dart
// Repository for vendor security features

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'base_repository.dart';
import '../models/security_model.dart';

class SecurityRepository extends BaseRepository {
  SecurityRepository({super.baseUrl});

  // ============================================================================
  // API KEYS
  // ============================================================================

  /// Generate a new API key
  Future<APIKey> generateAPIKey({
    required String name,
    List<String>? permissions,
    DateTime? expiresAt,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/security/api-keys');

      final data = <String, dynamic>{
        'name': name,
        if (permissions != null) 'permissions': permissions,
        if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
      };

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return APIKey.fromJson(body['data']);
    });
  }

  /// List all API keys
  Future<List<APIKey>> listAPIKeys({bool? activeOnly}) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (activeOnly != null) queryParams['active'] = activeOnly.toString();

      final uri = Uri.parse('$baseUrl/api/vendor/security/api-keys')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return (body['data'] as List)
          .map((k) => APIKey.fromJson(k))
          .toList();
    });
  }

  /// Revoke an API key
  Future<void> revokeAPIKey(String keyId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/security/api-keys/$keyId');

      final response = await http
          .delete(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
    });
  }

  /// Rotate an API key
  Future<APIKey> rotateAPIKey(String keyId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/security/api-keys/$keyId/rotate');

      final response = await http
          .post(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return APIKey.fromJson(body['data']);
    });
  }

  // ============================================================================
  // TWO-FACTOR AUTHENTICATION
  // ============================================================================

  /// Get 2FA status
  Future<TwoFactorStatus> get2FAStatus() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/security/2fa/status');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return TwoFactorStatus.fromJson(body['data']);
    });
  }

  /// Enable 2FA (returns setup data)
  Future<TwoFactorSetup> enable2FA({String method = 'totp'}) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/security/2fa/enable');

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({'method': method}),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return TwoFactorSetup.fromJson(body['data']);
    });
  }

  /// Verify 2FA code (completes setup)
  Future<BackupCodesResponse> verify2FA(String code) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/security/2fa/verify');

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({'code': code}),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return BackupCodesResponse.fromJson(body['data']);
    });
  }

  /// Disable 2FA
  Future<void> disable2FA(String code) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/security/2fa/disable');

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({'code': code}),
          )
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
    });
  }

  /// Generate new backup codes
  Future<BackupCodesResponse> generateBackupCodes(String code) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/security/2fa/backup-codes');

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({'code': code}),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return BackupCodesResponse.fromJson(body['data']);
    });
  }

  // ============================================================================
  // AUDIT LOGS
  // ============================================================================

  /// Get audit logs
  Future<AuditLogsFetchResult> getAuditLogs({
    int page = 1,
    int limit = 50,
    String? action,
    String? resource,
    DateTime? startDate,
    DateTime? endDate,
    String? severity,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (action != null) 'action': action,
        if (resource != null) 'resource': resource,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
        if (severity != null) 'severity': severity,
      };

      final uri = Uri.parse('$baseUrl/api/vendor/security/audit-logs')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final logs = (body['data'] as List)
          .map((l) => AuditLogEntry.fromJson(l))
          .toList();

      return AuditLogsFetchResult(
        logs: logs,
        total: body['pagination']?['total'] ?? logs.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  // ============================================================================
  // SECURITY OVERVIEW
  // ============================================================================

  /// Get security overview
  Future<SecurityOverview> getSecurityOverview() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/security/overview');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return SecurityOverview.fromJson(body['data']);
    });
  }
}

class AuditLogsFetchResult {
  final List<AuditLogEntry> logs;
  final int total;
  final int page;
  final int totalPages;

  AuditLogsFetchResult({
    required this.logs,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}
