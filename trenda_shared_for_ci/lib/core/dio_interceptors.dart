// trenda_shared/lib/core/dio_interceptors.dart
// ============================================================================
// DIO INTERCEPTORS - Enterprise-grade HTTP interceptors
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'logger.dart';

// ============================================================================
// RETRY INTERCEPTOR
// Automatically retries failed requests with exponential backoff
// ============================================================================

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Set<int> retryableStatusCodes;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.retryableStatusCodes = const {408, 429, 500, 502, 503, 504},
  });

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = err.requestOptions.extra['retryAttempt'] ?? 0;

    // Check if we should retry
    if (_shouldRetry(err, attempt)) {
      try {
        final nextAttempt = attempt + 1;
        final delay = _calculateDelay(nextAttempt);

        AppLogger.warning(
          'DioRetry',
          'Retrying request (attempt $nextAttempt/$maxRetries) after ${delay.inMilliseconds}ms',
        );

        await Future.delayed(delay);

        // Clone the request with updated retry count
        final options = err.requestOptions;
        options.extra['retryAttempt'] = nextAttempt;

        // Retry the request
        final response = await dio.fetch(options);
        handler.resolve(response);
        return;
      } catch (e) {
        // If retry also fails, let it go to error handler again
        if (e is DioException) {
          return super.onError(e, handler);
        }
      }
    }

    super.onError(err, handler);
  }

  bool _shouldRetry(DioException err, int attempt) {
    if (attempt >= maxRetries) return false;

    // Retry on connection errors
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    // Retry on network errors
    if (err.error is SocketException) {
      return true;
    }

    // Retry on specific status codes
    final statusCode = err.response?.statusCode;
    if (statusCode != null && retryableStatusCodes.contains(statusCode)) {
      return true;
    }

    return false;
  }

  Duration _calculateDelay(int attempt) {
    final multiplier = backoffMultiplier;
    final delayMs = initialDelay.inMilliseconds * (multiplier * attempt);
    // Cap at 30 seconds
    return Duration(milliseconds: delayMs.toInt().clamp(0, 30000));
  }
}

// ============================================================================
// AUTH INTERCEPTOR
// Automatically attaches Firebase auth token to requests
// ============================================================================

class AuthInterceptor extends Interceptor {
  String? _cachedToken;
  DateTime? _tokenExpiry;
  final Duration tokenBuffer;

  AuthInterceptor({this.tokenBuffer = const Duration(minutes: 5)});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth for public endpoints
    if (options.extra['skipAuth'] == true) {
      return handler.next(options);
    }

    try {
      final token = await _getValidToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      AppLogger.error('AuthInterceptor', 'Failed to get auth token: $e');
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // If 401, try refreshing token and retrying once
    if (err.response?.statusCode == 401 &&
        err.requestOptions.extra['retryAfterRefresh'] != true) {
      try {
        // Force refresh token
        _cachedToken = null;
        _tokenExpiry = null;

        final token = await _getValidToken(forceRefresh: true);
        if (token != null) {
          // Retry with new token
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $token';
          options.extra['retryAfterRefresh'] = true;

          final response = await Dio().fetch(options);
          return handler.resolve(response);
        }
      } catch (_) {
        // Token refresh failed, propagate original error
      }
    }

    handler.next(err);
  }

  Future<String?> _getValidToken({bool forceRefresh = false}) async {
    final now = DateTime.now();

    // Check if cached token is still valid
    if (!forceRefresh &&
        _cachedToken != null &&
        _tokenExpiry != null &&
        now.isBefore(_tokenExpiry!.subtract(tokenBuffer))) {
      return _cachedToken;
    }

    // Get fresh token from Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final result = await user.getIdTokenResult(forceRefresh);
      _cachedToken = result.token;
      _tokenExpiry = result.expirationTime;

      AppLogger.debug(
        'AuthInterceptor',
        'Token refreshed, expires: $_tokenExpiry',
      );
      return _cachedToken;
    } catch (e) {
      AppLogger.error('AuthInterceptor', 'Token refresh failed: $e');
      return null;
    }
  }

  /// Clear cached token (call on logout)
  void clearToken() {
    _cachedToken = null;
    _tokenExpiry = null;
  }
}

// ============================================================================
// LOGGING INTERCEPTOR
// Structured request/response logging for debugging
// ============================================================================

class LoggingInterceptor extends Interceptor {
  final bool logRequestBody;
  final bool logResponseBody;
  final int maxBodyLength;

  LoggingInterceptor({
    this.logRequestBody = true,
    this.logResponseBody = true,
    this.maxBodyLength = 500,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final buffer = StringBuffer();
    buffer.writeln(
      '┌─────────────────────────────────────────────────────────',
    );
    buffer.writeln('│ 📤 ${options.method} ${options.uri}');

    if (options.headers.isNotEmpty) {
      buffer.writeln('│ Headers: ${_sanitizeHeaders(options.headers)}');
    }

    if (logRequestBody && options.data != null) {
      final body = _truncate(options.data.toString());
      buffer.writeln('│ Body: $body');
    }

    buffer.writeln(
      '└─────────────────────────────────────────────────────────',
    );
    AppLogger.debug('HTTP', buffer.toString());

    options.extra['requestStartTime'] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final startTime =
        response.requestOptions.extra['requestStartTime'] as DateTime?;
    final duration = startTime != null
        ? DateTime.now().difference(startTime).inMilliseconds
        : 0;

    final buffer = StringBuffer();
    buffer.writeln(
      '┌─────────────────────────────────────────────────────────',
    );
    buffer.writeln(
      '│ 📥 ${response.statusCode} ${response.requestOptions.uri}',
    );
    buffer.writeln('│ Duration: ${duration}ms');

    if (logResponseBody && response.data != null) {
      final body = _truncate(response.data.toString());
      buffer.writeln('│ Body: $body');
    }

    buffer.writeln(
      '└─────────────────────────────────────────────────────────',
    );

    final emoji = response.statusCode! < 400 ? '✅' : '⚠️';
    AppLogger.debug('HTTP', '$emoji ${buffer.toString()}');

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final startTime = err.requestOptions.extra['requestStartTime'] as DateTime?;
    final duration = startTime != null
        ? DateTime.now().difference(startTime).inMilliseconds
        : 0;

    final buffer = StringBuffer();
    buffer.writeln(
      '┌─────────────────────────────────────────────────────────',
    );
    buffer.writeln('│ ❌ ${err.type} ${err.requestOptions.uri}');
    buffer.writeln('│ Duration: ${duration}ms');
    buffer.writeln('│ Message: ${err.message}');

    if (err.response != null) {
      buffer.writeln('│ Status: ${err.response?.statusCode}');
      if (logResponseBody && err.response?.data != null) {
        final body = _truncate(err.response!.data.toString());
        buffer.writeln('│ Response: $body');
      }
    }

    buffer.writeln(
      '└─────────────────────────────────────────────────────────',
    );
    AppLogger.error('HTTP', buffer.toString());

    handler.next(err);
  }

  String _truncate(String text) {
    if (text.length <= maxBodyLength) return text;
    return '${text.substring(0, maxBodyLength)}... (truncated)';
  }

  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = Map<String, dynamic>.from(headers);
    // Hide sensitive headers
    if (sanitized.containsKey('Authorization')) {
      final auth = sanitized['Authorization'] as String?;
      if (auth != null && auth.length > 20) {
        sanitized['Authorization'] = '${auth.substring(0, 20)}...';
      }
    }
    return sanitized;
  }
}

// ============================================================================
// CONNECTIVITY INTERCEPTOR
// Checks network connectivity before making requests
// ============================================================================

class ConnectivityInterceptor extends Interceptor {
  final Future<bool> Function() checkConnectivity;

  ConnectivityInterceptor({required this.checkConnectivity});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final isConnected = await checkConnectivity();

    if (!isConnected) {
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'No internet connection',
          message: 'Please check your network connection and try again.',
        ),
      );
    }

    handler.next(options);
  }
}

// ============================================================================
// CONFIGURED DIO FACTORY
// Creates a Dio instance with all interceptors configured
// ============================================================================

class TrendaDio {
  static Dio? _instance;
  static AuthInterceptor? _authInterceptor;

  /// Get a configured Dio instance
  static Dio getInstance({
    required String baseUrl,
    Duration connectTimeout = const Duration(seconds: 30),
    Duration receiveTimeout = const Duration(seconds: 30),
    bool enableLogging = true,
    bool enableRetry = true,
    Future<bool> Function()? connectivityChecker,
  }) {
    _instance ??= _createDio(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      enableLogging: enableLogging,
      enableRetry: enableRetry,
      connectivityChecker: connectivityChecker,
    );
    return _instance!;
  }

  static Dio _createDio({
    required String baseUrl,
    required Duration connectTimeout,
    required Duration receiveTimeout,
    required bool enableLogging,
    required bool enableRetry,
    Future<bool> Function()? connectivityChecker,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors in order

    // 1. Connectivity check (first)
    if (connectivityChecker != null) {
      dio.interceptors.add(
        ConnectivityInterceptor(checkConnectivity: connectivityChecker),
      );
    }

    // 2. Auth interceptor
    _authInterceptor = AuthInterceptor();
    dio.interceptors.add(_authInterceptor!);

    // 3. Retry interceptor
    if (enableRetry) {
      dio.interceptors.add(RetryInterceptor(dio: dio));
    }

    // 4. Logging (last, to capture final request/response)
    if (enableLogging) {
      dio.interceptors.add(LoggingInterceptor());
    }

    return dio;
  }

  /// Reset the singleton instance (for testing or reconfiguration)
  static void reset() {
    _instance = null;
    _authInterceptor = null;
  }

  /// Clear auth token (call on logout)
  static void clearAuth() {
    _authInterceptor?.clearToken();
  }
}
