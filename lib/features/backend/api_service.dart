// lib/backend/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:trenda_frontend/features/core/utils/network_utils.dart';
import 'package:trenda_shared/core/logger.dart';
import 'package:trenda_shared/core/images/picked_image.dart';
import '../home/utils/profile_photo.dart';

class ApiService {
  final String baseUrl;

  ApiService(this.baseUrl);

  /// ✅ FIXED: Safe JSON decode
  Map<String, dynamic> _decodeJson(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (e) {
      if (kDebugMode) AppLogger.debug('JSON decode error: $e', 'API');
      return {};
    }
  }

  /// ------------------------- SYNC USER -------------------------
  Future<bool> syncUser({
    required String uid,
    required String email,
    required String displayName,
    String? photoURL,
  }) async {
    try {
      final res = await NetworkUtils.authenticatedRequest(
        (token) => http.post(
          Uri.parse('$baseUrl/users/sync'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'uid': uid,
            'displayName': displayName,
            'email': email,
            'photoURL': photoURL,
          }),
        ),
      );

      return res != null && (res.statusCode == 200 || res.statusCode == 201);
    } catch (e) {
      if (kDebugMode) AppLogger.debug('syncUser error: $e', 'API');
      return false;
    }
  }

  /// ------------------------- GET USER -------------------------
  Future<Map<String, dynamic>?> getUser(String uid) async {
    try {
      final res = await NetworkUtils.authenticatedRequest(
        (token) => http.get(
          Uri.parse('$baseUrl/users/$uid'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (res != null && res.statusCode == 200) {
        final body = _decodeJson(res);
        return body['data'] ?? body;
      }
      return null;
    } catch (e) {
      if (kDebugMode) AppLogger.debug('getUser error: $e', 'API');
      return null;
    }
  }

  /// ------------------------- UPDATE USER -------------------------
  Future<bool> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      final res = await NetworkUtils.putJson(
        '$baseUrl/users/$uid',
        data,
      );
      return res != null && res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) AppLogger.debug('updateUser error: $e', 'API');
      return false;
    }
  }

  /// ------------------------- UPDATE EMAIL -------------------------
  Future<bool> updateEmail(String uid, String newEmail) async {
    try {
      final res = await NetworkUtils.putJson(
        '$baseUrl/users/$uid',
        {'email': newEmail},
      );
      return res != null && res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) AppLogger.debug('updateEmail error: $e', 'API');
      return false;
    }
  }

  /// ------------------------- UPDATE PREFERENCES -------------------------
  Future<bool> updatePreferences(String uid, Map<String, dynamic> prefs) async {
    try {
      final res = await NetworkUtils.putJson(
        '$baseUrl/users/$uid',
        {'preferences': prefs},
      );
      return res != null && res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) AppLogger.debug('updatePreferences error: $e', 'API');
      return false;
    }
  }

  /// ------------------------- UPLOAD PHOTO -------------------------
  Future<String?> uploadPhotoAndGetUrl(String uid, PickedImage picked) async {
    try {
      final uri = Uri.parse('$baseUrl/upload/users');

      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        picked.bytes,
        filename: picked.filename,
        contentType: MediaType.parse(picked.mimeType),
      ));

      // Add Firebase Auth ID token
      final idToken = await NetworkUtils.getIdToken();
      request.headers['Authorization'] = 'Bearer $idToken';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = _decodeJson(response);
        final url = data['url'] as String?;

        // Update user profile with new photo URL
        if (url != null && url.isNotEmpty) {
          await updateUser(uid, {kProfilePhotoField: url});
        }

        return url;
      } else {
        if (kDebugMode) {
          AppLogger.debug(
              'Upload failed: ${response.statusCode} ${response.body}', 'API');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) AppLogger.debug('uploadPhotoAndGetUrl error: $e', 'API');
      return null;
    }
  }

  /// ------------------------- ADDRESS CRUD -------------------------
  Future<bool> addOrUpdateAddress(
    String uid,
    Map<String, dynamic> addr, {
    bool isUpdate = false,
  }) async {
    try {
      final endpoint =
          isUpdate ? '$baseUrl/addresses/${addr["id"]}' : '$baseUrl/addresses';

      if (kDebugMode)
        AppLogger.debug(
            '${isUpdate ? "Updating" : "Adding"} address: $endpoint', 'API');
      if (kDebugMode) AppLogger.debug('Address data: $addr', 'API');

      final res = isUpdate
          ? await NetworkUtils.putJson(endpoint, addr)
          : await NetworkUtils.postJson(endpoint, addr);

      if (kDebugMode) {
        AppLogger.debug('Address save response: ${res?.statusCode}', 'API');
        AppLogger.debug('Response body: ${res?.body}', 'API');
      }

      return res != null && res.statusCode < 300;
    } catch (e) {
      if (kDebugMode) AppLogger.debug('addOrUpdateAddress error: $e', 'API');
      return false;
    }
  }

  Future<bool> deleteAddress(String uid, String addressId) async {
    try {
      final res = await NetworkUtils.deleteJson(
        '$baseUrl/addresses/$addressId',
      );
      return res != null && res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) AppLogger.debug('deleteAddress error: $e', 'API');
      return false;
    }
  }
}
