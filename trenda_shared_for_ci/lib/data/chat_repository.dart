// trenda_shared/lib/data/chat_repository.dart
// Repository for vendor-customer messaging

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'base_repository.dart';
import '../models/chat_model.dart';

class ChatRepository extends BaseRepository {
  ChatRepository({super.baseUrl});

  /// Get all conversations
  Future<List<Conversation>> getMyConversations({
    String? status,
    int limit = 50,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse('$baseUrl/api/chat/conversations')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return (body['data'] as List)
          .map((c) => Conversation.fromJson(c))
          .toList();
    });
  }

  /// Start a new conversation
  Future<Conversation> startConversation({
    required String customerId,
    String? productId,
    String? orderId,
    String? initialMessage,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/chat/start');

      final data = <String, dynamic>{
        'vendorId': customerId, // The other party
        if (productId != null) 'productId': productId,
        if (orderId != null) 'orderId': orderId,
      };

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final conversation = Conversation.fromJson(body['data']);

      // Send initial message if provided
      if (initialMessage != null && initialMessage.isNotEmpty) {
        await sendMessage(conversation.id, initialMessage);
      }

      return conversation;
    });
  }

  /// Get conversation by ID
  Future<Conversation> getConversation(String conversationId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/chat/$conversationId');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return Conversation.fromJson(body['data']);
    });
  }

  /// Get messages for a conversation
  Future<MessagesFetchResult> getMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();

      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/chat/$conversationId/messages')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      final messages = (body['data'] as List)
          .map((m) => ChatMessage.fromJson(m))
          .toList();

      return MessagesFetchResult(
        messages: messages,
        total: body['pagination']?['total'] ?? messages.length,
        page: body['pagination']?['page'] ?? page,
        totalPages: body['pagination']?['totalPages'] ?? 1,
      );
    });
  }

  /// Upload a single chat image and return its hosted URL. The picker already
  /// downscales images (≤1600px, q85), and the UI allows only one image per
  /// message, keeping chat lightweight and spam-resistant.
  Future<String> uploadChatImage(Uint8List bytes, String mimeType) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/upload/image');
      final dataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';

      final response = await http
          .post(
            uri,
            headers: headers(token),
            body: jsonEncode({'image': dataUri, 'folder': 'chat'}),
          )
          .timeout(const Duration(seconds: 60));

      final body = parseResponse(response);
      final data = body['data'];
      final url =
          (data is Map ? (data['url'] ?? data['secure_url']) : null) as String?;
      if (url == null || url.isEmpty) {
        throw Exception('Image upload failed');
      }
      return url;
    });
  }

  /// Send a message
  Future<ChatMessage> sendMessage(
    String conversationId,
    String message, {
    List<MessageAttachment>? attachments,
  }) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/chat/$conversationId/message');

      final data = <String, dynamic>{
        'message': message,
        if (attachments != null && attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
      };

      final response = await http
          .post(uri, headers: headers(token), body: jsonEncode(data))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      return ChatMessage.fromJson(body['data']);
    });
  }

  /// Mark messages as read
  Future<void> markAsRead(String conversationId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/chat/$conversationId/read');

      await http
          .post(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);
    });
  }

  /// Close a conversation
  Future<void> closeConversation(String conversationId) async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/chat/$conversationId/close');

      final response = await http
          .post(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      parseResponse(response);
    });
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    return retryRequest(() async {
      final token = await getIdToken();
      final uri = Uri.parse('$baseUrl/api/chat/unread-count');

      final response = await http
          .get(uri, headers: headers(token, json: false))
          .timeout(AppConfig.connectTimeout);

      final body = parseResponse(response);
      // Backend returns data.unreadCount (older callers expected data.count).
      return body['data']?['unreadCount'] ?? body['data']?['count'] ?? 0;
    });
  }
}

class MessagesFetchResult {
  final List<ChatMessage> messages;
  final int total;
  final int page;
  final int totalPages;

  MessagesFetchResult({
    required this.messages,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}
