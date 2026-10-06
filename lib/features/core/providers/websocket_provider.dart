// trenda_frontend/lib/features/core/providers/websocket_provider.dart
// WebSocket + FCM integration for real-time order updates

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:trenda_shared/services/websocket_service.dart';
import 'package:trenda_shared/services/fcm_service.dart';
import 'package:trenda_shared/core/logger.dart';
import 'package:trenda_shared/core/config.dart';
import 'package:trenda_shared/core/heartbeat_service.dart';
import '../../notifications/services/notification_service.dart';

/// Ban notification data for popup dialogs
class BanNotification {
  final String type; // 'banned' or 'unbanned'
  final String scope; // 'chat' or 'app'
  final String banType; // 'temporary' or 'permanent'
  final String reason;
  final String? expiresAt;
  final DateTime timestamp;

  BanNotification({
    required this.type,
    this.scope = 'chat',
    this.banType = 'temporary',
    this.reason = '',
    this.expiresAt,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isBanned => type == 'banned';
  String get scopeLabel => scope == 'app' ? 'the app' : 'chat';
  String get typeLabel => banType == 'permanent' ? 'permanently' : 'temporarily';
}

/// Provider for ban notifications — widgets listen to show popup dialogs
final banNotificationProvider = StateProvider<BanNotification?>((ref) => null);

/// Track if push notification callback has been setup
bool _pushNotificationCallbackSetup = false;

/// Provider that manages WebSocket + FCM based on auth state
final websocketInitProvider = Provider<void>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  final wsNotifier = ref.read(webSocketProvider.notifier);
  final backendUrl = AppConfig.backendBaseUrl;
  final fcmService = FcmService(baseUrl: backendUrl, dio: Dio());

  if (user != null) {
    // User is logged in - connect WebSocket with fresh token
    _connectWebSocketWithToken(user, wsNotifier, backendUrl);

    // Register FCM token
    _registerFcmToken(user, fcmService);

    // ✅ Start heartbeat for active user tracking
    HeartbeatService.start(appSource: 'customer');
  } else {
    // User logged out - disconnect
    wsNotifier.disconnect();
    HeartbeatService.stop();
  }

  // Listen for auth state changes
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      // ✅ Connect with fresh token on auth state change
      await _connectWebSocketWithToken(user, wsNotifier, backendUrl);

      // Register FCM token
      await _registerFcmToken(user, fcmService);

      // ✅ Start heartbeat for active user tracking
      HeartbeatService.start(appSource: 'customer');
    } else {
      wsNotifier.disconnect();
      HeartbeatService.stop();
    }
  });

  return;
});

/// ✅ Connect WebSocket with fresh auth token
Future<void> _connectWebSocketWithToken(
    User user, WebSocketNotifier wsNotifier, String backendUrl) async {
  try {
    // Force refresh token to ensure it's not expired
    final authToken = await user.getIdToken(true);

    // ✅ Set callback for future token refreshes
    wsNotifier.onTokenRefreshNeeded = () async {
      try {
        return await user.getIdToken(true);
      } catch (e) {
        AppLogger.error('Token refresh failed', e);
        return null;
      }
    };

    wsNotifier.connect(
      baseUrl: backendUrl,
      userId: user.uid,
      userRole: 'customer',
      authToken: authToken, // ✅ Pass fresh token
      appSource: 'customer',
    );

    // ✅ Add event callbacks for notifications - only once
    if (!_pushNotificationCallbackSetup) {
      _pushNotificationCallbackSetup = true;
      wsNotifier.addEventCallback((event, data) async {
        AppLogger.debug('📡 WebSocket event: $event', 'WebSocket');

        if (event == 'push:notification') {
          // Show local notification for push events
          final title = data['title']?.toString() ?? 'Trenda';
          final body = data['body']?.toString() ?? '';
          final orderNumber = data['orderNumber']?.toString() ?? '';
          final status = data['status']?.toString() ?? '';

          AppLogger.info(
              '📢 Push notification received: $title - $body', 'Notification');

          // Import and show local notification
          try {
            // Dynamic import to avoid circular dependency
            final notificationService = await _importNotificationService();
            if (notificationService != null && status.isNotEmpty) {
              await notificationService.showOrderStatusNotification(
                  orderNumber, status, body);
            } else if (notificationService != null) {
              await notificationService.showNotification(
                  title: title, body: body);
            }
          } catch (e) {
            AppLogger.error('Failed to show local notification', e);
          }
        } else if (event == 'order:status_changed') {
          AppLogger.info('📦 Order status changed via WebSocket', 'WebSocket');
        } else if (event == 'pasabay:batch_ready') {
          final title = '🚴 Pasabay Batch Ready!';
          final body = 'Your batch is full! A rider is preparing to pick up the orders.';
          try {
            final notificationService = await _importNotificationService();
            if (notificationService != null) {
              await notificationService.showNotification(title: title, body: body);
            }
          } catch (e) {
            AppLogger.error('Failed to show pasabay ready local notification', e);
          }
        } else if (event == 'pasabay:batch_dispatched') {
          final title = '🚴 Pasabay Dispatched!';
          final riderName = data['rider']?['name'] ?? 'A rider';
          final body = '$riderName is on the way to pick up your batch.';
          try {
            final notificationService = await _importNotificationService();
            if (notificationService != null) {
              await notificationService.showNotification(title: title, body: body);
            }
          } catch (e) {
            AppLogger.error('Failed to show pasabay dispatched local notification', e);
          }
        } else if (event == 'pasabay:batch_completed') {
          final title = '✅ Pasabay Completed!';
          final body = 'Your batch has been fully delivered.';
          try {
            final notificationService = await _importNotificationService();
            if (notificationService != null) {
              await notificationService.showNotification(title: title, body: body);
            }
          } catch (e) {
            AppLogger.error('Failed to show pasabay completed local notification', e);
          }
        }
      });
    }
  } catch (e) {
    AppLogger.error('WebSocket connection error', e);
  }
}

/// Helper to dynamically import NotificationService
Future<dynamic> _importNotificationService() async {
  try {
    // Use the notification service
    return _NotificationServiceProxy();
  } catch (e) {
    return null;
  }
}

/// Proxy class to call NotificationService static methods
class _NotificationServiceProxy {
  Future<void> showOrderStatusNotification(
      String orderNumber, String status, String message) async {
    await NotificationService.showOrderStatusNotification(
        orderNumber, status, message);
  }

  Future<void> showNotification(
      {required String title, required String body}) async {
    await NotificationService.showNotification(title: title, body: body);
  }
}

/// Register FCM token with backend
Future<void> _registerFcmToken(User user, FcmService fcmService) async {
  try {
    // Request notification permissions first
    await fcmService.requestPermissions();

    // Get Firebase ID token for authentication
    final idToken = await user.getIdToken();
    if (idToken != null) {
      await fcmService.registerToken(idToken);
    }
  } catch (e) {
    AppLogger.error('FCM registration error', e);
  }
}

/// Provider for WebSocket connection status
final wsStatusProvider = Provider<WebSocketStatus>((ref) {
  return ref.watch(webSocketProvider).status;
});

/// Provider to trigger order refresh on WebSocket updates
final orderRefreshTriggerProvider = StateProvider<int>((ref) => 0);

/// Provider to show in-app notifications for order status changes
/// Widgets can listen to this to show snackbars/dialogs
final orderStatusNotificationProvider =
    StateProvider<OrderStatusNotification?>((ref) => null);

/// Order status notification data
class OrderStatusNotification {
  final String orderNumber;
  final String status;
  final String message;
  final DateTime timestamp;

  OrderStatusNotification({
    required this.orderNumber,
    required this.status,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Get user-friendly message based on status
  static String getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Your order has been confirmed by the vendor! 🎉';
      case 'processing':
        return 'Your order is being prepared';
      case 'ready_to_ship':
        return 'Your order is ready and waiting for a rider';
      case 'shipped':
        return 'A rider has been assigned to your order';
      case 'pickup_started':
        return 'Rider is on the way to pick up your order 🏍️';
      case 'out_for_delivery':
        return 'Your order is on the way! 🚀';
      case 'arriving_at_customer':
        return 'Rider has arrived at your location! 📍';
      case 'delivered':
        return 'Your order has been delivered! ✅';
      case 'cancelled':
        return 'Your order has been cancelled';
      default:
        return 'Order status updated to $status';
    }
  }

  /// Check if this status should trigger a prominent notification
  static bool shouldNotify(String status) {
    return [
      'confirmed',
      'pickup_started',
      'out_for_delivery',
      'arriving_at_customer',
      'delivered',
      'cancelled',
      'pasabay_ready',
      'pasabay_dispatched',
      'pasabay_completed'
    ].contains(status.toLowerCase());
  }
}

/// Track if order status listener has been setup
bool _orderStatusListenerSetup = false;

/// Setup order status listener - call this in your orders screen
/// Only registers the callback once to prevent duplicate notifications
void setupOrderStatusRefresh(WidgetRef ref) {
  if (_orderStatusListenerSetup) {
    AppLogger.debug(
        'Order status listener already setup, skipping', 'WebSocket');
    return;
  }
  _orderStatusListenerSetup = true;

  ref.read(webSocketProvider.notifier).addEventCallback((event, data) {
    if (event == 'order:status_changed') {
      // Increment trigger to refresh orders
      ref.read(orderRefreshTriggerProvider.notifier).state++;

      // Show in-app notification for key status changes
      final newStatus = data['newStatus']?.toString() ?? '';
      final orderNumber = data['orderNumber']?.toString() ?? '';

      if (OrderStatusNotification.shouldNotify(newStatus)) {
        ref.read(orderStatusNotificationProvider.notifier).state =
            OrderStatusNotification(
          orderNumber: orderNumber,
          status: newStatus,
          message: OrderStatusNotification.getStatusMessage(newStatus),
        );
      }
    } else if (event == 'pasabay:batch_ready') {
      ref.read(orderRefreshTriggerProvider.notifier).state++;
      final batchCode = data['batchCode']?.toString() ?? 'Batch';
      ref.read(orderStatusNotificationProvider.notifier).state =
          OrderStatusNotification(
        orderNumber: batchCode,
        status: 'pasabay_ready',
        message: 'Your Pasabay batch $batchCode is full! Rider coming soon 📦',
      );
    } else if (event == 'pasabay:batch_dispatched') {
      ref.read(orderRefreshTriggerProvider.notifier).state++;
      final batchCode = data['batchCode']?.toString() ?? 'Batch';
      final riderName = data['rider']?['name']?.toString() ?? 'Rider';
      ref.read(orderStatusNotificationProvider.notifier).state =
          OrderStatusNotification(
        orderNumber: batchCode,
        status: 'pasabay_dispatched',
        message: '$riderName is picking up your Pasabay batch $batchCode! 🚴',
      );
    } else if (event == 'pasabay:batch_completed') {
      ref.read(orderRefreshTriggerProvider.notifier).state++;
      final batchCode = data['batchCode']?.toString() ?? 'Batch';
      ref.read(orderStatusNotificationProvider.notifier).state =
          OrderStatusNotification(
        orderNumber: batchCode,
        status: 'pasabay_completed',
        message: 'Your Pasabay order from batch $batchCode has been delivered! ✅',
      );
    }
  });

  AppLogger.debug('Order status listener setup complete', 'WebSocket');
}

/// Track if ban notification listener has been setup
bool _banNotificationListenerSetup = false;

/// Setup ban notification listener — call once from your main shell/scaffold
/// Shows popup dialogs when user gets banned or unbanned
void setupBanNotificationListener(WidgetRef ref) {
  if (_banNotificationListenerSetup) return;
  _banNotificationListenerSetup = true;

  ref.read(webSocketProvider.notifier).addEventCallback((event, data) {
    if (event == 'user:banned') {
      AppLogger.info('🚫 Ban notification received', 'WebSocket');
      ref.read(banNotificationProvider.notifier).state = BanNotification(
        type: 'banned',
        scope: data['scope']?.toString() ?? 'chat',
        banType: data['type']?.toString() ?? 'temporary',
        reason: data['reason']?.toString() ?? 'Policy violation',
        expiresAt: data['expiresAt']?.toString(),
      );
    } else if (event == 'user:unbanned') {
      AppLogger.info('✅ Unban notification received', 'WebSocket');
      ref.read(banNotificationProvider.notifier).state = BanNotification(
        type: 'unbanned',
        scope: data['scope']?.toString() ?? 'chat',
      );
    }
  });

  AppLogger.debug('Ban notification listener setup complete', 'WebSocket');
}
