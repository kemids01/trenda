// lib/features/notifications/services/notification_service.dart
// Local notification service for Trenda Customer app

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trenda_shared/core/logger.dart';

// ============================================================================
// COMPLETE NOTIFICATION SERVICE WITH LOCAL & PUSH
// ============================================================================

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Initialize notifications
  static Future<void> initialize() async {
    // Local notifications setup
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Firebase Cloud Messaging setup
    await _setupFCM();
  }

  static Future<void> _setupFCM() async {
    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      AppLogger.info('Notification permission granted', 'FCM');

      // Get FCM token
      final token = await _messaging.getToken();
      if (token != null) {
        AppLogger.debug('FCM Token: $token', 'FCM');
        await _saveTokenToBackend(token);
      }

      // Handle token refresh
      _messaging.onTokenRefresh.listen(_saveTokenToBackend);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check for initial message (app opened from terminated state)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    }
  }

  static Future<void> _saveTokenToBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('fcm_token');

      // Skip if token hasn't changed
      if (storedToken == token) {
        AppLogger.debug('FCM token unchanged, skipping save', 'FCM');
        return;
      }

      // Store token locally
      await prefs.setString('fcm_token', token);
      AppLogger.info('FCM token saved locally', 'FCM');
    } catch (e) {
      AppLogger.error('Failed to save FCM token: $e', 'FCM');
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.debug(
        'Foreground message: ${message.notification?.title}', 'FCM');

    // ✅ FIX: On Android, FCM automatically displays notifications that have
    // a notification payload in foreground. Only show local notification
    // for data-only messages (no notification payload) to avoid duplicates.
    if (message.notification != null) {
      // FCM will handle display, just log it
      AppLogger.debug(
          'FCM notification payload present, skipping local display', 'FCM');
      return;
    }

    // Data-only message - show local notification manually
    final title = message.data['title'] ?? 'New Notification';
    final body = message.data['body'] ?? '';

    showNotification(
      title: title,
      body: body,
      payload: message.data.toString(),
    );
  }

  static void _handleNotificationTap(RemoteMessage message) {
    AppLogger.debug('Notification tapped: ${message.data}', 'FCM');
    // Navigation can be handled by parent widget state
  }

  static void _onNotificationTapped(NotificationResponse response) {
    AppLogger.debug(
        'Local notification tapped: ${response.payload}', 'Notification');
  }

  // Show local notification
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    NotificationType type = NotificationType.general,
  }) async {
    AndroidNotificationDetails androidDetails;

    // Use different channel for order notifications with enhanced sound/vibration
    if (type == NotificationType.order) {
      androidDetails = AndroidNotificationDetails(
        'trenda_customer_orders_channel',
        'Order Updates',
        channelDescription: 'Alerts for order status updates',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/launcher_icon',
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
        fullScreenIntent: true,
        category: AndroidNotificationCategory.status,
        audioAttributesUsage: AudioAttributesUsage.notificationEvent,
      );
    } else {
      androidDetails = const AndroidNotificationDetails(
        'trenda_customer_channel',
        'Trenda',
        channelDescription: 'Notifications for Trenda app',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
        playSound: true,
        enableVibration: true,
      );
    }

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond, // Unique ID for each notification
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Show notification for order status update
  static Future<void> showOrderStatusNotification(
      String orderNumber, String status, String message) async {
    await showNotification(
      title: 'Order #$orderNumber',
      body: message,
      type: NotificationType.order,
      payload: 'order:$orderNumber',
    );
  }

  // Show delivery notification
  static Future<void> showDeliveryNotification(String message) async {
    await showNotification(
      title: '🚀 Delivery Update',
      body: message,
      type: NotificationType.order,
    );
  }

  // Cancel all notifications
  static Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.debug('Background message: ${message.notification?.title}', 'FCM');
}

enum NotificationType {
  general(0),
  order(1),
  promotion(2);

  final int id;
  const NotificationType(this.id);
}

// ============================================================================
// IN-APP NOTIFICATION BANNER
// ============================================================================

class NotificationBanner extends StatelessWidget {
  final String title;
  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const NotificationBanner({
    super.key,
    required this.title,
    required this.message,
    this.color = Colors.blue,
    this.icon = Icons.notifications,
    this.onTap,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    Color color = Colors.blue,
    IconData icon = Icons.notifications,
    VoidCallback? onTap,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              entry.remove();
              onTap?.call();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => entry.remove(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
