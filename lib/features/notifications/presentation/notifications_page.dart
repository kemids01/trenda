// lib/features/notifications/presentation/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_frontend/features/auth/data/providers.dart' show currentUidProvider;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trenda_shared/core/logger.dart';
import 'dart:convert';
import '../../../design_system/design_system.dart';
import 'package:trenda_shared/core/timezone.dart';
import 'package:intl/intl.dart';

/// Notification model
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // order, promotion, system, chat
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? 'system',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      isRead: json['isRead'] ?? false,
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'data': data,
      };

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      data: data,
    );
  }
}

/// Notifications state notifier
class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  /// Stored PER ACCOUNT: one shared key showed the previous account's
  /// notifications to whoever signed in next on the same phone.
  final String _storageKey;

  NotificationsNotifier({String? uid})
      : _storageKey =
            uid == null ? 'app_notifications' : 'app_notifications_$uid',
        super([]) {
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json);
        state = decoded.map((e) => AppNotification.fromJson(e)).toList();
      }
    } catch (e) {
      AppLogger.error('Error loading notifications', e);
    }
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(state.map((n) => n.toJson()).toList()),
      );
    } catch (e) {
      AppLogger.error('Error saving notifications', e);
    }
  }

  void addNotification(AppNotification notification) {
    state = [notification, ...state];
    _saveNotifications();
  }

  void markAsRead(String id) {
    state =
        state.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
    _saveNotifications();
  }

  void markAllAsRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
    _saveNotifications();
  }

  void deleteNotification(String id) {
    state = state.where((n) => n.id != id).toList();
    _saveNotifications();
  }

  void clearAll() {
    state = [];
    _saveNotifications();
  }

  int get unreadCount => state.where((n) => !n.isRead).length;
}

/// Providers
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotification>>(
  (ref) => NotificationsNotifier(uid: ref.watch(currentUidProvider)),
);

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).where((n) => !n.isRead).length;
});

/// Notifications Page
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifications.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'read_all') {
                  notifier.markAllAsRead();
                } else if (value == 'clear_all') {
                  _confirmClearAll(context, notifier);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'read_all',
                  child: Text('Mark all as read'),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Text('Clear all'),
                ),
              ],
            ),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: AppSpacing.paddingSM,
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return NotificationCard(
                  notification: notification,
                  onTap: () {
                    notifier.markAsRead(notification.id);
                    _handleNotificationTap(context, notification);
                  },
                  onDismiss: () {
                    notifier.deleteNotification(notification.id);
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: AppColors.textTertiary,
          ),
          AppSpacing.verticalMD,
          Text(
            'No notifications',
            style: AppTypography.titleLarge,
          ),
          AppSpacing.verticalXS,
          Text(
            'You\'re all caught up!',
            style: AppTypography.asSecondary(AppTypography.bodyMedium),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, NotificationsNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All'),
        content: const Text('Delete all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.clearAll();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(
      BuildContext context, AppNotification notification) {
    // Handle navigation based on notification type
    switch (notification.type) {
      case 'order':
        final orderId = notification.data?['orderId'];
        if (orderId != null) {
          // Navigate to order details
          // context.push('/orders/$orderId');
        }
        break;
      case 'chat':
        final userId = notification.data?['userId'];
        if (userId != null) {
          // Navigate to chat
          // context.push('/chat', extra: userId);
        }
        break;
      default:
        // Show notification details
        break;
    }
  }
}

/// Notification card widget
class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: AppSpacing.paddingMD,
        color: AppColors.error,
        child: Icon(Icons.delete, color: AppColors.onError),
      ),
      onDismissed: (_) => onDismiss(),
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.borderRadiusMD,
          child: Container(
            padding: AppSpacing.paddingCard,
            decoration: BoxDecoration(
              border: notification.isRead
                  ? null
                  : Border(
                      left: BorderSide(
                        color: AppColors.primary,
                        width: 3,
                      ),
                    ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIcon(),
                AppSpacing.horizontalSM,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: notification.isRead
                            ? AppTypography.titleSmall
                            : AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                      ),
                      AppSpacing.verticalXXS,
                      Text(
                        notification.body,
                        style:
                            AppTypography.asSecondary(AppTypography.bodySmall),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      AppSpacing.verticalXS,
                      Text(
                        _formatTime(notification.timestamp),
                        style:
                            AppTypography.asTertiary(AppTypography.labelSmall),
                      ),
                    ],
                  ),
                ),
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;

    switch (notification.type) {
      case 'order':
        icon = Icons.shopping_bag;
        color = AppColors.info;
        break;
      case 'promotion':
        icon = Icons.local_offer;
        color = AppColors.warning;
        break;
      case 'chat':
        icon = Icons.chat;
        color = AppColors.success;
        break;
      default:
        icon = Icons.notifications;
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusMD,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d/M/y').formatPh(time);
  }
}
