// trenda_shared/lib/data/financial_repository.dart
// Financial repository for vendor financial management

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'base_repository.dart';
import '../models/financial_model.dart';

class FinancialRepository extends BaseRepository {
  FinancialRepository({super.baseUrl});

  /// Get financial statistics
  Future<FinancialStats> getFinancialStats({String? period}) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (period != null) queryParams['period'] = period;

      final uri = Uri.parse(
        '$baseUrl/api/vendor/financial/stats',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return FinancialStats.fromJson(body['data']);
    });
  }

  /// Get payout history
  Future<PayoutsFetchResult> getPayoutHistory({
    int page = 1,
    int limit = 20,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {'page': page.toString(), 'limit': limit.toString()};

      final uri = Uri.parse(
        '$baseUrl/api/vendor/financial/payouts',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      final payouts = (body['data'] as List)
          .map((e) => PayoutModel.fromJson(e))
          .toList();

      return PayoutsFetchResult(
        payouts: payouts,
        total: body['pagination']?['total'] ?? payouts.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  /// Request a payout
  Future<PayoutModel> requestPayout(double amount) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/financial/payout/request');

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({'amount': amount}),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return PayoutModel.fromJson(body['data']);
    });
  }

  /// Get transaction history
  Future<TransactionsFetchResult> getTransactionHistory({
    int page = 1,
    int limit = 20,
    String? type,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (type != null) 'type': type,
      };

      final uri = Uri.parse(
        '$baseUrl/api/vendor/financial/transactions',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);

      final transactions = (body['data'] as List)
          .map((e) => TransactionModel.fromJson(e))
          .toList();

      return TransactionsFetchResult(
        transactions: transactions,
        total: body['pagination']?['total'] ?? transactions.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  /// Get earnings breakdown
  Future<EarningsBreakdown> getEarningsBreakdown({String? period}) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (period != null) queryParams['period'] = period;

      final uri = Uri.parse(
        '$baseUrl/api/vendor/financial/earnings/breakdown',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return EarningsBreakdown.fromJson(body['data']);
    });
  }

  /// Get COD tracking
  Future<CODTracking> getCODTracking({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (startDate != null)
        queryParams['startDate'] = startDate.toIso8601String();
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse(
        '$baseUrl/api/vendor/financial/cod-tracking',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return CODTracking.fromJson(body['data']);
    });
  }

  /// Get commission summary from orders
  Future<CommissionSummary> getCommissionSummary({String? period}) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (period != null) queryParams['period'] = period;

      final uri = Uri.parse(
        '$baseUrl/api/vendor/financial/commission-summary',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return CommissionSummary.fromJson(body['data'] ?? {});
    });
  }

  /// Get payout schedule
  Future<PayoutSchedule> getPayoutSchedule() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/financial/payout-schedule');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return PayoutSchedule.fromJson(body['data']);
    });
  }

  /// Generate invoice
  Future<InvoiceModel> generateInvoice({
    required DateTime startDate,
    required DateTime endDate,
    String type = 'sales',
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/financial/invoices/generate');

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({
              'startDate': startDate.toIso8601String(),
              'endDate': endDate.toIso8601String(),
              'type': type,
            }),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return InvoiceModel.fromJson(body['data']);
    });
  }

  /// Download invoice PDF
  Future<String> downloadInvoicePDF(String invoiceId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse(
        '$baseUrl/api/vendor/financial/invoices/$invoiceId/pdf',
      );

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return body['data']['url'] ?? body['data']['pdfUrl'] ?? '';
    });
  }

  /// Get tax report
  Future<TaxReport> getTaxReport({int? year}) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{};
      if (year != null) queryParams['year'] = year.toString();

      final uri = Uri.parse(
        '$baseUrl/api/vendor/financial/tax-report',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return TaxReport.fromJson(body['data']);
    });
  }

  /// Get profit & loss statement
  Future<ProfitLossStatement> getProfitLossStatement({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      };

      final uri = Uri.parse(
        '$baseUrl/api/vendor/financial/profit-loss',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ProfitLossStatement.fromJson(body['data']);
    });
  }
}

class PayoutsFetchResult {
  final List<PayoutModel> payouts;
  final int total;
  final int page;
  final int totalPages;

  PayoutsFetchResult({
    required this.payouts,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}

class TransactionsFetchResult {
  final List<TransactionModel> transactions;
  final int total;
  final int page;
  final int totalPages;

  TransactionsFetchResult({
    required this.transactions,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}
