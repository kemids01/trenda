// trenda_shared/lib/data/report_repository.dart
// Repository for report and ban operations

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'base_repository.dart';
import '../models/report_model.dart';

class ReportRepository extends BaseRepository {
  ReportRepository({super.baseUrl});

  // ========================================================================
  // USER-FACING
  // ========================================================================

  /// Submit a report
  Future<UserReport> submitReport({
    required String reportedUserId,
    required String reason,
    String? details,
    String? conversationId,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/reports/submit');

      final data = <String, dynamic>{
        'reportedUserId': reportedUserId,
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
        if (conversationId != null) 'conversationId': conversationId,
      };

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return UserReport.fromJson(body['data']);
    });
  }

  /// Check if current user is banned
  Future<BanStatus> checkBanStatus() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/reports/ban-status');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final data = body['data'];
      return BanStatus(
        isBanned: data['isBanned'] ?? false,
        bans: (data['bans'] as List? ?? [])
            .map((b) => UserBan.fromJson(b))
            .toList(),
      );
    });
  }

  // ========================================================================
  // ADMIN-ONLY
  // ========================================================================

  /// Get all reports (admin)
  Future<ReportsFetchResult> getReports({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (status != null) params['status'] = status;

      final uri = Uri.parse('$baseUrl/api/reports/all')
          .replace(queryParameters: params);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final reports = (body['data'] as List)
          .map((r) => UserReport.fromJson(r))
          .toList();

      return ReportsFetchResult(
        reports: reports,
        total: body['pagination']?['total'] ?? reports.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  /// Get report counts (admin)
  Future<ReportCounts> getReportCounts() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/reports/counts');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ReportCounts.fromJson(body['data']);
    });
  }

  /// Update report status/action (admin)
  Future<UserReport> updateReport(
    String reportId, {
    String? status,
    String? adminNotes,
    String? actionTaken,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/reports/$reportId');

      final data = <String, dynamic>{
        if (status != null) 'status': status,
        if (adminNotes != null) 'adminNotes': adminNotes,
        if (actionTaken != null) 'actionTaken': actionTaken,
      };

      final response = await http
          .put(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return UserReport.fromJson(body['data']);
    });
  }

  /// Ban a user (admin)
  Future<UserBan> banUser({
    required String userId,
    required String type,
    required String reason,
    String scope = 'chat',
    int? durationDays,
    String? reportId,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/reports/ban');

      final data = <String, dynamic>{
        'userId': userId,
        'type': type,
        'reason': reason,
        'scope': scope,
        if (durationDays != null) 'durationDays': durationDays,
        if (reportId != null) 'reportId': reportId,
      };

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return UserBan.fromJson(body['data']);
    });
  }

  /// Get all bans (admin)
  Future<BansFetchResult> getBans({
    bool? active,
    String? userId,
    int page = 1,
    int limit = 20,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (active != null) params['active'] = active.toString();
      if (userId != null) params['userId'] = userId;

      final uri = Uri.parse('$baseUrl/api/reports/bans')
          .replace(queryParameters: params);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final bans = (body['data'] as List)
          .map((b) => UserBan.fromJson(b))
          .toList();

      return BansFetchResult(
        bans: bans,
        total: body['pagination']?['total'] ?? bans.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  /// Remove a ban (admin)
  Future<UserBan> removeBan(String banId, {String? removalReason}) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/reports/bans/$banId/remove');

      final data = <String, dynamic>{
        if (removalReason != null) 'removalReason': removalReason,
      };

      final response = await http
          .put(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return UserBan.fromJson(body['data']);
    });
  }
}

// Result types
class BanStatus {
  final bool isBanned;
  final List<UserBan> bans;
  BanStatus({required this.isBanned, required this.bans});
}

class ReportsFetchResult {
  final List<UserReport> reports;
  final int total;
  final int page;
  final int totalPages;
  ReportsFetchResult({
    required this.reports,
    required this.total,
    required this.page,
    required this.totalPages,
  });
  bool get hasMore => page < totalPages;
}

class BansFetchResult {
  final List<UserBan> bans;
  final int total;
  final int page;
  final int totalPages;
  BansFetchResult({
    required this.bans,
    required this.total,
    required this.page,
    required this.totalPages,
  });
  bool get hasMore => page < totalPages;
}
