// trenda_shared/lib/core/heartbeat_service.dart
// Periodic heartbeat to track active users online across all Trenda apps.
// Usage: HeartbeatService.start(appSource: 'vendor') on login,
//        HeartbeatService.stop() on logout.

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'config.dart';

class HeartbeatService {
  static Timer? _timer;
  static String _appSource = 'unknown';
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.backendBaseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  /// Start sending heartbeats every 2 minutes.
  /// [appSource] identifies the app: 'vendor', 'customer', 'rider', 'admin',
  /// 'vendor_mode', or 'supplier'.
  static void start({required String appSource}) {
    _appSource = appSource;
    // Send an immediate heartbeat on start
    _sendHeartbeat();
    // Then every 2 minutes
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) {
      _sendHeartbeat();
    });
  }

  /// Stop sending heartbeats (call on logout).
  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Whether the heartbeat service is currently running.
  static bool get isRunning => _timer != null && _timer!.isActive;

  static Future<void> _sendHeartbeat() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        stop(); // No user, stop heartbeats
        return;
      }

      final token = await user.getIdToken();
      await _dio.post(
        '/api/users/heartbeat',
        data: {'appSource': _appSource},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      // Silently fail — heartbeat is non-critical
      debugPrint('[HeartbeatService] heartbeat failed: $e');
    }
  }
}
