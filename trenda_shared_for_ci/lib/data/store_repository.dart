// trenda_shared/lib/data/store_repository.dart
// Store repository for vendor store management

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../core/config.dart';
import '../core/images/picked_image.dart';
import 'base_repository.dart';
import '../models/store_model.dart';

class StoreRepository extends BaseRepository {
  StoreRepository({super.baseUrl});

  /// Get vendor's store
  Future<StoreModel?> getMyStore() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store/my-store');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      if (response.statusCode == 404) {
        return null; // Store not created yet
      }

      final body = parseResponse(response);
      return StoreModel.fromJson(body['data']);
    });
  }

  /// Create new store
  Future<StoreModel> createStore(Map<String, dynamic> data) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store');

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return StoreModel.fromJson(body['data']);
    });
  }

  /// Update store information
  Future<StoreModel> updateStore(Map<String, dynamic> data) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store');

      final response = await http
          .put(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return StoreModel.fromJson(body['data']);
    });
  }

  /// Update store settings
  Future<StoreModel> updateStoreSettings(Map<String, dynamic> settings) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store/settings');

      final response = await http
          .put(uri, headers: headers(token), body: jsonEncode(settings))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return StoreModel.fromJson(body['data']);
    });
  }

  /// Upload store logo
  Future<String> uploadStoreLogo(PickedImage image) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store/logo');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(
          http.MultipartFile.fromBytes(
            'logo',
            image.bytes,
            filename: image.filename,
            contentType: MediaType.parse(image.mimeType),
          ),
        );

      final streamedRes = await request.send();
      final response = await http.Response.fromStream(streamedRes);
      final body = parseResponse(response);

      return body['data']['logo'] ?? body['data']['url'] ?? '';
    });
  }

  /// Upload store banner
  Future<String> uploadStoreBanner(PickedImage image) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store/banner');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(
          http.MultipartFile.fromBytes(
            'banner',
            image.bytes,
            filename: image.filename,
            contentType: MediaType.parse(image.mimeType),
          ),
        );

      final streamedRes = await request.send();
      final response = await http.Response.fromStream(streamedRes);
      final body = parseResponse(response);

      return body['data']['banner'] ?? body['data']['url'] ?? '';
    });
  }

  /// Get store staff
  Future<List<StoreStaffMember>> getStoreStaff() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store/staff');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return (body['data'] as List)
          .map((e) => StoreStaffMember.fromJson(e))
          .toList();
    });
  }

  /// Add staff member
  Future<StoreStaffMember> addStaffMember({
    required String userId,
    required String role,
    required List<String> permissions,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store/staff');

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({
              'userId': userId,
              'role': role,
              'permissions': permissions,
            }),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return StoreStaffMember.fromJson(body['data']);
    });
  }

  /// Update staff member
  Future<StoreStaffMember> updateStaffMember({
    required String staffId,
    String? role,
    List<String>? permissions,
    String? status,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store/staff/$staffId');

      final data = <String, dynamic>{};
      if (role != null) data['role'] = role;
      if (permissions != null) data['permissions'] = permissions;
      if (status != null) data['status'] = status;

      final response = await http
          .put(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return StoreStaffMember.fromJson(body['data']);
    });
  }

  /// Remove staff member
  Future<bool> removeStaffMember(String staffId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store/staff/$staffId');

      final response = await http
          .delete(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
      return true;
    });
  }

  /// Invite staff member by email
  Future<bool> inviteStaffByEmail({
    required String email,
    required String role,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store/staff/invite');

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({'email': email, 'role': role}),
          )
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
      return true;
    });
  }

  /// Update store policies

  Future<StoreModel> updateStorePolicies(Map<String, dynamic> policies) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store/policies');

      final response = await http
          .put(uri, headers: headers(token), body: jsonEncode(policies))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return StoreModel.fromJson(body['data']);
    });
  }

  /// Get store analytics
  Future<Map<String, dynamic>> getStoreAnalytics() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store/analytics');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return body['data'] ?? {};
    });
  }

  /// Get store hours
  Future<List<StoreHours>> getStoreHours() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store-hours/my-hours');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final data = body['data'];

      // Backend returns single object with hours map {monday: {...}, tuesday: {...}}
      // Convert to List<StoreHours> for frontend
      final hoursMap = data['hours'] as Map<String, dynamic>? ?? {};
      final dayOrder = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ];

      return dayOrder.map((day) {
        final dayData = hoursMap[day] as Map<String, dynamic>?;
        if (dayData == null) {
          return StoreHours(dayOfWeek: day, isOpen: false);
        }
        return StoreHours(
          dayOfWeek: day,
          isOpen: dayData['isOpen'] ?? true,
          openTime: dayData['open']?.toString(),
          closeTime: dayData['close']?.toString(),
        );
      }).toList();
    });
  }

  /// Read the "accept orders while closed" (advance-order) setting from store hours.
  /// Defaults false when unset. Never throws — returns false on error.
  Future<bool> getAllowOrdersWhenClosed() async {
    try {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store-hours/my-hours');
      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);
      final body = parseResponse(response);
      final settings = body['data']?['settings'] as Map<String, dynamic>?;
      return settings?['allowOrdersWhenClosed'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Update the "accept orders while closed" (advance-order) setting. PUTs only the
  /// settings patch to the store-hours endpoint (which merges settings).
  Future<bool> updateAllowOrdersWhenClosed(bool allow) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store-hours/update');
      final response = await http
          .put(
            uri,
            headers: headers(token),
            body: jsonEncode({
              'settings': {'allowOrdersWhenClosed': allow},
            }),
          )
          .timeout(AppConfig.connectTimeout);
      final body = parseResponse(response);
      final settings = body['data']?['settings'] as Map<String, dynamic>?;
      return settings?['allowOrdersWhenClosed'] == true;
    });
  }

  /// Update store hours
  Future<List<StoreHours>> updateStoreHours(List<StoreHours> hours) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/vendor/store-hours/update');

      // Convert List<StoreHours> to hours map format expected by backend
      final hoursMap = <String, dynamic>{};
      for (final h in hours) {
        hoursMap[h.dayOfWeek.toLowerCase()] = {
          'open': h.openTime ?? '09:00',
          'close': h.closeTime ?? '18:00',
          'isOpen': h.isOpen,
        };
      }

      final response = await http
          .put(
            uri,
            headers: headers(token),
            body: jsonEncode({'hours': hoursMap}),
          )
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final data = body['data'];

      // Convert response back to List<StoreHours>
      final responseHoursMap = data['hours'] as Map<String, dynamic>? ?? {};
      final dayOrder = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ];

      return dayOrder.map((day) {
        final dayData = responseHoursMap[day] as Map<String, dynamic>?;
        if (dayData == null) {
          return StoreHours(dayOfWeek: day, isOpen: false);
        }
        return StoreHours(
          dayOfWeek: day,
          isOpen: dayData['isOpen'] ?? true,
          openTime: dayData['open']?.toString(),
          closeTime: dayData['close']?.toString(),
        );
      }).toList();
    });
  }
}
