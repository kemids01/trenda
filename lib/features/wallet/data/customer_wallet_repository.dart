// trenda_frontend/lib/features/wallet/data/customer_wallet_repository.dart
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trenda_shared/core/config.dart';

class CustomerWalletRepository {
  final Dio _dio;

  CustomerWalletRepository()
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.backendBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  Future<Map<String, String>> _getAuthHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final token = await user.getIdToken();
    return {'Authorization': 'Bearer $token'};
  }

  /// Get wallet balance + recent transactions
  Future<Map<String, dynamic>> getWallet({int transactionLimit = 20}) async {
    final headers = await _getAuthHeaders();
    final response = await _dio.get(
      '/api/customer/wallet',
      queryParameters: {'transactionLimit': transactionLimit},
      options: Options(headers: headers),
    );
    return response.data['data'] ?? {};
  }

  /// Get transaction history (paginated)
  Future<Map<String, dynamic>> getTransactions({
    int page = 1,
    int limit = 20,
    String? type,
    String? category,
  }) async {
    final headers = await _getAuthHeaders();
    final response = await _dio.get(
      '/api/customer/wallet/transactions',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (type != null) 'type': type,
        if (category != null) 'category': category,
      },
      options: Options(headers: headers),
    );
    return response.data['data'] ?? {};
  }

  /// Get active payment methods for recharge
  Future<List<Map<String, dynamic>>> getActivePaymentMethods() async {
    final response = await _dio.get('/api/payment-methods/active');
    return List<Map<String, dynamic>>.from(response.data['methods'] ?? []);
  }

  /// Create recharge request
  Future<Map<String, dynamic>> createRechargeRequest({
    required double amount,
    required String paymentMethodId,
    required String receiptImage,
  }) async {
    final headers = await _getAuthHeaders();
    final response = await _dio.post(
      '/api/customer/wallet/recharge',
      data: {
        'amount': amount,
        'paymentMethodId': paymentMethodId,
        'receiptImage': receiptImage,
      },
      options: Options(headers: headers),
    );
    return response.data['request'] ?? {};
  }

  /// Get recharge history
  Future<Map<String, dynamic>> getRechargeHistory({
    int page = 1,
    int limit = 20,
  }) async {
    final headers = await _getAuthHeaders();
    final response = await _dio.get(
      '/api/customer/wallet/recharge-history',
      queryParameters: {'page': page, 'limit': limit},
      options: Options(headers: headers),
    );
    return {
      'requests':
          List<Map<String, dynamic>>.from(response.data['requests'] ?? []),
      'pagination': response.data['pagination'] ?? {},
    };
  }
}
