// ============================================================================
// lib/core/http/trenda_http_client.dart - ULTRA-SAFE HTTP CLIENT
// ============================================================================
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:trenda_shared/core/config.dart';

class TrendaHttpClient {
  // Token cache to avoid excessive Firebase calls
  static String? _cachedToken;
  static DateTime? _tokenExpiry;

  /// Get authentication token with caching and retry logic
  static Future<String> _getToken({
    bool forceRefresh = false,
    int retries = 3,
  }) async {
    // Use cached token if valid and not forcing refresh
    if (!forceRefresh && _cachedToken != null && _tokenExpiry != null) {
      final now = DateTime.now();
      if (now.isBefore(_tokenExpiry!)) {
        print('🎫 TrendaHttpClient: Using cached token');
        return _cachedToken!;
      } else {
        print('⚠️ TrendaHttpClient: Cached token expired');
        _cachedToken = null;
        _tokenExpiry = null;
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ TrendaHttpClient: No current user');
      throw Exception('Not authenticated');
    }

    // Retry token retrieval with exponential backoff
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        print(
          '🎫 TrendaHttpClient: Getting token (attempt ${attempt + 1}/${retries + 1}, refresh: ${forceRefresh || attempt > 0})',
        );

        final token = await user
            .getIdToken(forceRefresh || attempt > 0)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                print('⏱️ TrendaHttpClient: Token retrieval timed out');
                return null;
              },
            );

        if (token == null || token.isEmpty) {
          print('⚠️ TrendaHttpClient: Token is null or empty');

          if (attempt == retries) {
            throw Exception('Failed to retrieve token');
          }

          await Future.delayed(Duration(milliseconds: 1000 * (attempt + 1)));
          continue;
        }

        // Cache the token (expires in 50 minutes)
        _cachedToken = token;
        _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));

        print('✅ TrendaHttpClient: Token retrieved (${token.length} chars)');
        return token;
      } catch (e) {
        print('❌ TrendaHttpClient: Token attempt ${attempt + 1} failed: $e');

        if (attempt == retries) {
          _cachedToken = null;
          _tokenExpiry = null;
          throw Exception('Failed to get token after ${retries + 1} attempts');
        }

        await Future.delayed(Duration(milliseconds: 1000 * (attempt + 1)));
      }
    }

    throw Exception('Failed to get token');
  }

  /// Public method to get token for multipart requests
  /// Use this ONLY for MultipartRequest that can't go through the normal flow
  static Future<String> getTokenForMultipart() async {
    return _getToken();
  }

  /// Check if response indicates a token error
  static bool _isTokenError(http.Response res) {
    if (res.statusCode != 401) return false;

    try {
      final body = jsonDecode(res.body);
      final code = body['code'] as String?;

      return code == 'TOKEN_BLACKLISTED' ||
          code == 'TOKEN_EXPIRED' ||
          code == 'TOKEN_REVOKED' ||
          code == 'INVALID_TOKEN_FORMAT' ||
          code == 'TOKEN_TOO_OLD' ||
          code == 'AUTH_FAILED';
    } catch (_) {
      return res.body.contains('TOKEN_BLACKLISTED') ||
          res.body.contains('TOKEN_EXPIRED') ||
          res.body.contains('TOKEN_REVOKED') ||
          res.body.contains('AUTH_FAILED');
    }
  }

  /// Check if response indicates a fatal account error
  static bool _isFatalAccountError(http.Response res) {
    if (res.statusCode != 401 && res.statusCode != 403) return false;

    try {
      final body = jsonDecode(res.body);
      final code = body['code'] as String?;

      return code == 'ACCOUNT_SUSPENDED' ||
          code == 'ACCOUNT_DELETED' ||
          code == 'USER_NOT_FOUND';
    } catch (_) {
      return false;
    }
  }

  /// Generate headers for HTTP requests
  static Map<String, String> _headers(String token, {bool json = true}) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    if (json) 'Content-Type': 'application/json',
  };

  /// Safe request wrapper with automatic token refresh and retry logic
  static Future<http.Response> _safeRequest(
    Future<http.Response> Function(String token) send, {
    int maxRetries = 3,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        print(
          '🔵 TrendaHttpClient: Request attempt ${attempt + 1}/${maxRetries + 1}',
        );

        // Get token (force refresh on retries)
        String token;
        try {
          token = await _getToken(forceRefresh: attempt > 0);
        } catch (e) {
          print('❌ TrendaHttpClient: Failed to get token: $e');

          if (attempt == maxRetries) {
            throw Exception('Authentication failed: Unable to get token');
          }

          // Clear cache and retry
          _cachedToken = null;
          _tokenExpiry = null;
          await Future.delayed(Duration(seconds: 2));
          continue;
        }

        // Execute the request
        http.Response res;
        try {
          res = await send(token).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('⏱️ TrendaHttpClient: Request timed out');
              throw Exception('Request timeout');
            },
          );
        } catch (e) {
          print('❌ TrendaHttpClient: Request failed: $e');

          if (attempt == maxRetries) {
            throw Exception('Network error: $e');
          }

          await Future.delayed(Duration(seconds: 1 + attempt));
          continue;
        }

        print('📥 TrendaHttpClient: Response ${res.statusCode}');

        // Handle fatal account errors (sign out immediately)
        if (_isFatalAccountError(res)) {
          print('❌ TrendaHttpClient: Fatal account error detected');

          try {
            final body = jsonDecode(res.body);
            final message = body['message'] as String?;

            await FirebaseAuth.instance.signOut();
            throw Exception(
              'Account error: ${message ?? "Please contact support"}',
            );
          } catch (e) {
            await FirebaseAuth.instance.signOut();
            throw Exception('Account error: Please contact support');
          }
        }

        // Handle token errors (retry with fresh token)
        if (_isTokenError(res)) {
          print('⚠️ TrendaHttpClient: Token error detected');

          // Clear cached token
          _cachedToken = null;
          _tokenExpiry = null;

          if (attempt < maxRetries) {
            print(
              '🔄 TrendaHttpClient: Retrying with fresh token ($attempt/$maxRetries)...',
            );
            await Future.delayed(Duration(seconds: 2));
            continue;
          }

          // Only sign out after exhausting all retries
          print(
            '❌ TrendaHttpClient: Token still invalid after $maxRetries retries',
          );
          await FirebaseAuth.instance.signOut();
          throw Exception('Session expired. Please log in again.');
        }

        // Success!
        print('✅ TrendaHttpClient: Request successful');
        return res;
      } catch (e) {
        print('⚠️ TrendaHttpClient: Attempt ${attempt + 1} failed: $e');

        // Don't retry for fatal errors
        if (e.toString().contains('Account error') ||
            (e.toString().contains('Session expired') &&
                attempt == maxRetries)) {
          rethrow;
        }

        if (attempt == maxRetries) {
          rethrow;
        }

        await Future.delayed(Duration(seconds: 1 + attempt));
      }
    }

    throw Exception('Request failed after $maxRetries retries');
  }

  /// GET request
  static Future<http.Response> get(String endpoint) async {
    print('🌐 TrendaHttpClient.GET: $endpoint');
    return _safeRequest((token) {
      final uri = Uri.parse('${AppConfig.backendBaseUrl}$endpoint');
      return http.get(uri, headers: _headers(token, json: false));
    });
  }

  /// POST request
  static Future<http.Response> post(
    String endpoint, {
    required Map<String, dynamic> body,
  }) async {
    print('🌐 TrendaHttpClient.POST: $endpoint');
    return _safeRequest((token) {
      final uri = Uri.parse('${AppConfig.backendBaseUrl}$endpoint');
      return http.post(uri, headers: _headers(token), body: jsonEncode(body));
    });
  }

  /// PUT request
  static Future<http.Response> put(
    String endpoint, {
    required Map<String, dynamic> body,
  }) async {
    print('🌐 TrendaHttpClient.PUT: $endpoint');
    return _safeRequest((token) {
      final uri = Uri.parse('${AppConfig.backendBaseUrl}$endpoint');
      return http.put(uri, headers: _headers(token), body: jsonEncode(body));
    });
  }

  /// DELETE request
  static Future<http.Response> delete(String endpoint) async {
    print('🌐 TrendaHttpClient.DELETE: $endpoint');
    return _safeRequest((token) {
      final uri = Uri.parse('${AppConfig.backendBaseUrl}$endpoint');
      return http.delete(uri, headers: _headers(token));
    });
  }

  /// Clear cached token (call this on manual logout)
  static void clearCache() {
    print('🧹 TrendaHttpClient: Clearing token cache');
    _cachedToken = null;
    _tokenExpiry = null;
  }
}
