// trenda_shared/lib/chat/chat_alert.dart
// What an OPEN app shows when a `chat:message` socket event arrives. A closed app is
// told by the server's FCM push instead (utils/chatMessageNotification.js) — keep the
// two worded alike.

/// Title + body for an in-app chat alert.
class ChatAlert {
  final String conversationId;
  final String title;
  final String body;
  const ChatAlert(
      {required this.conversationId, required this.title, required this.body});
}

const int _kMaxBody = 120;

/// Reads a `chat:message` socket payload. Null when it names no conversation.
ChatAlert? chatAlertFromSocket(Map<String, dynamic> data) {
  final id = data['conversationId']?.toString();
  if (id == null || id.isEmpty) return null;

  final sender = data['sender'];
  String title = '';
  if (sender is Map) {
    title = (sender['displayName'] ?? sender['name'] ?? '').toString().trim();
  }
  if (title.isEmpty) title = 'New message';

  final message = data['message'];
  var text = '';
  var hasImage = false;
  if (message is Map) {
    text = (message['message'] ?? '').toString();
    final attachments = message['attachments'];
    hasImage = attachments is List &&
        attachments.any((a) => a is Map && a['type'] == 'image');
  }
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final String body;
  if (text.isEmpty) {
    body = hasImage ? '📷 Photo' : 'New message';
  } else if (text.length > _kMaxBody) {
    body = '${text.substring(0, _kMaxBody - 1)}…';
  } else {
    body = text;
  }
  return ChatAlert(conversationId: id, title: title, body: body);
}
