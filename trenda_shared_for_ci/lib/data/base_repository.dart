import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../core/exceptions.dart';

/// Headers for a PUBLIC endpoint: always `Accept`, plus the signed-in user's token when
/// there is one. The token is optional on these routes (the backend's `optionalAuth`) —
/// it only tells the server WHO is looking, e.g. for a vendor's Visitors card. Uses the
/// cached token (no forced refresh) and never throws: a public page must load signed out.
Future<Map<String, String>> optionalAuthHeaders() async {
  const accept = {'Accept': 'application/json'};
  try {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null || token.isEmpty) return accept;
    return {...accept, 'Authorization': 'Bearer $token'};
  } catch (_) {
    return accept;
  }
}

abstract class BaseRepository {
  final String baseUrl;

  BaseRepository({String? baseUrl})
    : baseUrl = baseUrl ?? AppConfig.backendBaseUrl;

  // ✅ Centralized token retrieval
  Future<String> getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw AuthenticationException('User not logged in');
    }

    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw AuthenticationException('Failed to get ID token');
    }

    return token;
  }

  // ✅ Centralized headers
  Map<String, String> headers(String token, {bool json = true}) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
    if (json) 'Content-Type': 'application/json',
  };

  // ✅ Handle session expired - sign out user
  void _handleSessionExpired() {
    // Sign out to clear local state and trigger auth flow
    FirebaseAuth.instance.signOut();
  }

  // ✅ Enhanced error handling with auto-logout for 401
  Map<String, dynamic> parseResponse(http.Response response) {
    if (response.statusCode == 401) {
      // Trigger automatic logout for expired sessions
      _handleSessionExpired();
      throw AuthenticationException('Session expired. Please login again.');
    }

    if (response.statusCode >= 500) {
      print('🔥 Server Error [${response.statusCode}]: ${response.body}');
      throw NetworkException('Server error. Please try again later.');
    }

    late Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body);
    } catch (e) {
      print('❌ JSON Decode Error: ${response.body}');
      throw ApiException(
        'Invalid server response: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      print('⚠️ API Error [${response.statusCode}]: ${body['message']}');
      throw ApiException(
        body['message'] ?? 'Request failed',
        statusCode: response.statusCode,
        details: body['details']?.toString(),
      );
    }

    if (body['success'] != true) {
      print('⚠️ Operation Failed: ${body['message']}');
      throw ApiException(
        body['message'] ?? 'Operation failed',
        statusCode: response.statusCode,
      );
    }

    return body;
  }

  // ✅ Parse response for public endpoints (no authentication required)
  Map<String, dynamic> parsePublicResponse(http.Response response) {
    if (response.statusCode >= 500) {
      throw NetworkException('Server error. Please try again later.');
    }

    late Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body);
    } catch (e) {
      throw ApiException(
        'Invalid server response',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        body['message'] ?? 'Request failed',
        statusCode: response.statusCode,
        details: body['details']?.toString(),
      );
    }

    if (body['success'] != true) {
      throw ApiException(
        body['message'] ?? 'Operation failed',
        statusCode: response.statusCode,
      );
    }

    return body;
  }

  // ✅ Retry logic
  Future<T> retryRequest<T>(
    Future<T> Function() request, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await request();
      } catch (e) {
        attempts++;

        if (e is AuthenticationException || attempts >= maxRetries) {
          rethrow;
        }

        if (e is SocketException || e is HttpException) {
          await Future.delayed(delay * attempts);
          continue;
        }

        rethrow;
      }
    }

    throw NetworkException('Max retries exceeded');
  }
}
