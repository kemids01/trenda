// trenda_shared/lib/services/fcm_service.dart
// FCM Token Registration Service
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

// ============================================================================
// FCM SERVICE
// ============================================================================

class FcmService {
  final Dio _dio;
  final String _baseUrl;

  FcmService({required String baseUrl, required Dio dio})
    : _baseUrl = baseUrl,
      _dio = dio;

  /// Get FCM token from Firebase Messaging
  Future<String?> getToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      print('📱 FCM Token: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Register FCM token with backend
  Future<bool> registerToken(String authToken) async {
    try {
      final fcmToken = await getToken();
      if (fcmToken == null) {
        print('⚠️ No FCM token available');
        return false;
      }

      final response = await _dio.post(
        '$_baseUrl/api/fcm/register',
        data: {'token': fcmToken},
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );

      if (response.statusCode == 200) {
        print('✅ FCM token registered with backend');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error registering FCM token: $e');
      return false;
    }
  }

  /// Unregister FCM token (on logout)
  Future<bool> unregisterToken(String authToken) async {
    try {
      final response = await _dio.delete(
        '$_baseUrl/api/fcm/unregister',
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );

      if (response.statusCode == 200) {
        print('✅ FCM token unregistered');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error unregistering FCM token: $e');
      return false;
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      print('📱 Notification permission: ${granted ? "granted" : "denied"}');
      return granted;
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      return false;
    }
  }

  /// Setup foreground message handler
  void setupForegroundHandler(void Function(RemoteMessage) onMessage) {
    FirebaseMessaging.onMessage.listen(onMessage);
  }

  /// Setup background message handler (call in main.dart before runApp)
  static void setupBackgroundHandler(
    Future<void> Function(RemoteMessage) handler,
  ) {
    FirebaseMessaging.onBackgroundMessage(handler);
  }

  /// Handle notification tap when app in background
  void setupNotificationTapHandler(void Function(RemoteMessage) onTap) {
    // When app is opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        onTap(message);
      }
    });

    // When app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(onTap);
  }
}

// ============================================================================
// PROVIDER
// ============================================================================

final fcmServiceProvider = Provider.family<FcmService, String>((ref, baseUrl) {
  return FcmService(baseUrl: baseUrl, dio: Dio());
});
