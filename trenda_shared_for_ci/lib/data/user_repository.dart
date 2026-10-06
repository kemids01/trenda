//trenda_shared/lib/data/user_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../core/config.dart';
import '../models/user_model.dart';

/// Custom exception for unauthorized requests
class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'Unauthorized']);
  @override
  String toString() => 'UnauthorizedException: $message';
}

class UserRepository {
  final String baseUrl;

  UserRepository({String? baseUrl})
    : baseUrl = baseUrl ?? AppConfig.backendBaseUrl;

  /// -------------------- GET FRESH ID TOKEN --------------------
  Future<String> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Failed to get ID token');
    }

    return token;
  }

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// -------------------- FETCH ALL USERS --------------------
  Future<List<UserModel>> fetchAllUsers() async {
    final token = await _getIdToken();

    final uri = Uri.parse('$baseUrl/api/users/admin/all-users');

    final res = await http.get(uri, headers: _headers(token));

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Failed to decode JSON response: ${res.body}');
    }

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception('Failed to fetch users: ${body['message'] ?? res.body}');
    }

    final list = (body['data'] ?? []) as List;
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  /// -------------------- UPDATE USER ROLE (Multiple Roles Support) --------------------
  Future<bool> updateUserRole({
    required String userId,
    required List<String> roles,
  }) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/users/$userId');

    final res = await http.put(
      uri,
      headers: _headers(token),
      body: jsonEncode({'userId': userId, 'roles': roles}),
    );

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Failed to decode JSON response: ${res.body}');
    }

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to update user role: ${body['message'] ?? res.body}',
      );
    }

    return true;
  }

  /// -------------------- ADD ROLE TO USER --------------------
  Future<UserModel> addRoleToUser({
    required String userId,
    required String role,
  }) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/users/add-role');

    final res = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'userId': userId, 'role': role}),
    );

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Failed to decode JSON response: ${res.body}');
    }

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception('Failed to add role: ${body['message'] ?? res.body}');
    }

    return UserModel.fromJson(body['data']);
  }

  /// -------------------- REMOVE ROLE FROM USER --------------------
  Future<UserModel> removeRoleFromUser({
    required String userId,
    required String role,
  }) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/users/remove-role');

    final res = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'userId': userId, 'role': role}),
    );

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Failed to decode JSON response: ${res.body}');
    }

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception('Failed to remove role: ${body['message'] ?? res.body}');
    }

    return UserModel.fromJson(body['data']);
  }

  /// -------------------- DELETE USER --------------------
  Future<bool> deleteUser({required String userId}) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/users/$userId');

    final res = await http.delete(uri, headers: _headers(token));

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Failed to decode JSON response: ${res.body}');
    }

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception('Failed to delete user: ${body['message'] ?? res.body}');
    }

    return true;
  }

  /// -------------------- CREATE USER --------------------
  Future<UserModel> createUser({
    required String name,
    required String email,
    required List<String> roles,
  }) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/users');

    final res = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'name': name, 'email': email, 'roles': roles}),
    );

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Failed to decode JSON response: ${res.body}');
    }

    if (res.statusCode != 201 || body['success'] != true) {
      throw Exception('Failed to create user: ${body['message'] ?? res.body}');
    }

    return UserModel.fromJson(body['data']);
  }

  /// -------------------- FETCH SINGLE USER --------------------
  Future<UserModel> fetchUserById(String userId) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/users/$userId');

    final res = await http.get(uri, headers: _headers(token));

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Failed to decode JSON response: ${res.body}');
    }

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception('Failed to fetch user: ${body['message'] ?? res.body}');
    }

    return UserModel.fromJson(body['data']);
  }

  /// -------------------- GET CURRENT USER PROFILE --------------------
  Future<UserModel> getCurrentUserProfile() async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/users/profile');

    final res = await http.get(uri, headers: _headers(token));

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Failed to decode JSON response: ${res.body}');
    }

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to fetch profile: ${body['message'] ?? res.body}',
      );
    }

    return UserModel.fromJson(body['data']);
  }

  /// -------------------- UPDATE USER PROFILE --------------------
  Future<UserModel> updateProfile({
    String? name,
    String? phone,
    DateTime? birthday,
    UserAddress? address,
  }) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/users/profile');

    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (birthday != null) data['birthday'] = birthday.toIso8601String();
    if (address != null) {
      data['address'] = {
        'street': address.street,
        'city': address.city,
        'province': address.province,
      };
    }

    final res = await http.put(
      uri,
      headers: _headers(token),
      body: jsonEncode(data),
    );

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Failed to decode JSON response: ${res.body}');
    }

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to update profile: ${body['message'] ?? res.body}',
      );
    }

    return UserModel.fromJson(body['data']);
  }

  /// -------------------- GET ACTIVE SESSIONS --------------------
  Future<List<SessionModel>> getActiveSessions() async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/users/sessions');

    final res = await http.get(uri, headers: _headers(token));

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Failed to decode JSON response: ${res.body}');
    }

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to fetch sessions: ${body['message'] ?? res.body}',
      );
    }

    final list = (body['data'] ?? []) as List;
    return list.map((e) => SessionModel.fromJson(e)).toList();
  }

  /// -------------------- REVOKE SESSION --------------------
  Future<bool> revokeSession(String sessionId) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/users/sessions/$sessionId');

    final res = await http.delete(uri, headers: _headers(token));

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Failed to decode JSON response: ${res.body}');
    }

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to revoke session: ${body['message'] ?? res.body}',
      );
    }

    return true;
  }

  /// -------------------- REVOKE ALL SESSIONS --------------------
  Future<bool> revokeAllSessions() async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl/api/users/sessions');

    final res = await http.delete(uri, headers: _headers(token));

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Failed to decode JSON response: ${res.body}');
    }

    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(
        'Failed to revoke sessions: ${body['message'] ?? res.body}',
      );
    }

    return true;
  }
}

/// Session model for active sessions
class SessionModel {
  final String id;
  final String device;
  final String ip;
  final String? userAgent;
  final DateTime? lastActive;
  final DateTime? createdAt;
  final bool isCurrent;

  SessionModel({
    required this.id,
    required this.device,
    required this.ip,
    this.userAgent,
    this.lastActive,
    this.createdAt,
    this.isCurrent = false,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      device: json['device']?.toString() ?? 'Unknown Device',
      ip: json['ip']?.toString() ?? 'Unknown IP',
      userAgent: json['userAgent']?.toString(),
      lastActive: json['lastActive'] != null
          ? DateTime.tryParse(json['lastActive'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      isCurrent: json['isCurrent'] == true,
    );
  }
}
