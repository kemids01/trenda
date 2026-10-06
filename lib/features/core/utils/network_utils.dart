//lib/features/core/utils/network_utils.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class NetworkUtils {
  NetworkUtils._();

  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(milliseconds: 500);
  static const Duration _timeout =
      Duration(seconds: 60); // Increased for Render cold start
  static const Duration _tokenTimeout = Duration(seconds: 15);

  /// ✅ FIXED: Token fetch with guest mode support
  /// Returns null if user is not authenticated (guest mode)
  static Future<String?> getIdToken({bool forceRefresh = false}) async {
    User? user = FirebaseAuth.instance.currentUser;

    // For guest users, return null immediately (no blocking wait)
    if (user == null) {
      if (kDebugMode) debugPrint('📝 Guest mode: No Firebase user');
      return null;
    }

    try {
      final token = await user.getIdToken(forceRefresh).timeout(
            _tokenTimeout,
            onTimeout: () => throw TimeoutException('Token fetch timeout'),
          );

      if (token == null || token.isEmpty) {
        throw Exception('Empty token returned from Firebase');
      }

      return token;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ getIdToken error: $e');
      rethrow;
    }
  }

  /// Authenticated request. Returns null if the user is not signed in (guest mode)
  /// or no answer arrived after the retries.
  ///
  /// [retryOnNetworkError] re-sends after a timeout / dropped connection. Leave it
  /// on ONLY for requests that are safe to repeat (reads, PUT/DELETE, upserts):
  /// a timeout does not mean the server did nothing, and re-sending a POST such as
  /// "cancel", "request a refund" or "add 1 to cart" can apply it twice. A 401 is
  /// always retried once with a fresh token — the server rejected it unprocessed.
  static Future<http.Response?> authenticatedRequest(
    Future<http.Response> Function(String token) requestFn, {
    bool retryOnTokenExpiry = true,
    bool retryOnNetworkError = true,
  }) async {
    int attempt = 0;

    while (attempt < _maxRetries) {
      try {
        final token = await getIdToken(forceRefresh: attempt > 0);

        // If no token (guest mode), return null
        if (token == null) {
          if (kDebugMode)
            debugPrint('📝 Guest mode: Skipping authenticated request');
          return null;
        }

        final res = await requestFn(token).timeout(_timeout);

        // Handle 401 with token refresh
        if (res.statusCode == 401 && attempt == 0 && retryOnTokenExpiry) {
          if (kDebugMode) debugPrint('⚠️ Token expired, refreshing...');
          attempt++;
          await Future.delayed(_baseDelay);
          continue;
        }

        return res;
      } on SocketException catch (e) {
        if (kDebugMode) debugPrint('🌐 Network error: $e');
        if (!retryOnNetworkError) return null;
      } on TimeoutException catch (e) {
        if (kDebugMode) debugPrint('⏱ Timeout: $e');
        if (!retryOnNetworkError) return null;
      } on FirebaseAuthException catch (e) {
        if (kDebugMode) debugPrint('🔒 Auth error: ${e.code}');
        // Don't retry auth errors
        return null;
      } catch (e) {
        // package:http reports a dropped connection as ClientException, not
        // SocketException — it lands here and is just as unsafe to re-send.
        if (kDebugMode) debugPrint('❌ Unexpected error: $e');
        if (!retryOnNetworkError) return null;
      }

      attempt++;
      if (attempt < _maxRetries) {
        final delay = _baseDelay * (1 << (attempt - 1));
        if (kDebugMode) debugPrint('⏳ Retry in ${delay.inMilliseconds}ms...');
        await Future.delayed(delay);
      }
    }

    if (kDebugMode) debugPrint('❌ Max retries exceeded');
    return null;
  }

  /// ✅ Generic retry for non-authenticated requests
  static Future<http.Response?> retryRequest(
    Future<http.Response> Function() requestFn,
  ) async {
    int attempt = 0;

    while (attempt < _maxRetries) {
      try {
        return await requestFn().timeout(_timeout);
      } on SocketException catch (e) {
        if (kDebugMode) debugPrint('🌐 Network error: $e');
      } on TimeoutException catch (e) {
        if (kDebugMode) debugPrint('⏱ Timeout: $e');
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Error: $e');
        rethrow; // Don't retry non-network errors
      }

      attempt++;
      if (attempt < _maxRetries) {
        final delay = _baseDelay * (1 << attempt);
        await Future.delayed(delay);
      }
    }

    return null;
  }

  /// ✅ Safe JSON decoder
  static Map<String, dynamic> decodeJson(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (e) {
      if (kDebugMode) debugPrint('❌ JSON decode error: $e');
      return {};
    }
  }

  /// HTTP helpers
  static Future<Map<String, dynamic>> getJson(String url) async {
    final res = await authenticatedRequest(
      (token) => http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    return res != null ? decodeJson(res) : {};
  }

  /// POST is NOT re-sent after a timeout (see [authenticatedRequest]).
  static Future<http.Response?> postJson(
    String url,
    Map<String, dynamic> body,
  ) {
    return authenticatedRequest(
      retryOnNetworkError: false,
      (token) => http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ),
    );
  }

  static Future<http.Response?> putJson(
    String url,
    Map<String, dynamic> body,
  ) {
    return authenticatedRequest(
      (token) => http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ),
    );
  }

  static Future<http.Response?> deleteJson(String url) {
    return authenticatedRequest(
      (token) => http.delete(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
  }
}
