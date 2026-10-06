// lib/features/chat/providers/chat_alerts_provider.dart (twin in trenda_vendor — change both or neither)
// One app-wide listener for new chat messages. It keeps the unread badges current
// and, while the app is on screen, shows a notification — the server's FCM push
// only reaches the phone's tray when the app is in the background or closed
// (an FCM notification that arrives in the foreground is not displayed).
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/services/websocket_service.dart';
import 'package:trenda_shared/trenda_shared.dart';

import '../../notifications/services/notification_service.dart';
import 'chat_provider.dart';

/// The conversation on screen. A message there is shown in the thread itself, so
/// it is not announced, and the chat page refreshes the badge after reading it.
final openChatConversationProvider = StateProvider<String?>((ref) => null);

final chatAlertsProvider = Provider<void>((ref) {
  final ws = ref.read(webSocketProvider.notifier);

  void refreshBadges() {
    ref.invalidate(unreadMessagesCountProvider);
    ref.invalidate(conversationsProvider);
  }

  void onEvent(String event, Map<String, dynamic> data) {
    if (event != 'chat:message') return;
    final alert = chatAlertFromSocket(data);
    if (alert == null) return;
    if (alert.conversationId == ref.read(openChatConversationProvider)) return;

    refreshBadges();
    // In the background the server's push is what the user sees.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    NotificationService.showNotification(
      title: alert.title,
      body: alert.body,
      payload: 'chat:${alert.conversationId}',
    );
  }

  ws.addEventCallback(onEvent);
  // Messages that arrived while the app was in the background.
  final lifecycle = AppLifecycleListener(onResume: refreshBadges);
  ref.onDispose(() {
    ws.removeEventCallback(onEvent);
    lifecycle.dispose();
  });
});
