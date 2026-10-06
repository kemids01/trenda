// lib/features/chat/providers/chat_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/trenda_shared.dart';
import '../utils/chat_errors.dart';

// ============================================================================
// REPOSITORY PROVIDER
// ============================================================================
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

// ============================================================================
// CONVERSATIONS LIST
// ============================================================================
final conversationsProvider =
    FutureProvider.autoDispose<List<Conversation>>((ref) async {
  final repo = ref.read(chatRepositoryProvider);
  return repo.getMyConversations();
});

// ============================================================================
// UNREAD COUNT
// ============================================================================
final unreadMessagesCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.read(chatRepositoryProvider);
  return repo.getUnreadCount();
});

// ============================================================================
// SINGLE CONVERSATION
// ============================================================================
final conversationProvider =
    FutureProvider.family.autoDispose<Conversation, String>((ref, id) async {
  final repo = ref.read(chatRepositoryProvider);
  return repo.getConversation(id);
});

// ============================================================================
// MESSAGES FOR CONVERSATION
// ============================================================================
final messagesProvider = FutureProvider.family
    .autoDispose<MessagesFetchResult, String>((ref, conversationId) async {
  final repo = ref.read(chatRepositoryProvider);
  return repo.getMessages(conversationId);
});

// ============================================================================
// CHAT CONTROLLER
// ============================================================================
final chatControllerProvider = Provider((ref) => ChatController(ref));

class ChatController {
  final Ref _ref;

  ChatController(this._ref);

  Future<Conversation> startConversation({
    required String vendorId,
    String? productId,
    String? orderId,
    String? initialMessage,
  }) async {
    final repo = _ref.read(chatRepositoryProvider);
    final conversation = await repo.startConversation(
      customerId: vendorId,
      productId: productId,
      orderId: orderId,
      initialMessage: initialMessage,
    );
    _ref.invalidate(conversationsProvider);
    return conversation;
  }

  Future<ChatMessage> sendMessage(String conversationId, String message,
      {List<MessageAttachment>? attachments}) async {
    final repo = _ref.read(chatRepositoryProvider);
    final msg = await repo.sendMessage(conversationId, message,
        attachments: attachments);
    _ref.invalidate(messagesProvider(conversationId));
    _ref.invalidate(conversationsProvider);
    return msg;
  }

  Future<void> markAsRead(String conversationId) async {
    final repo = _ref.read(chatRepositoryProvider);
    await repo.markAsRead(conversationId);
    _ref.invalidate(unreadMessagesCountProvider);
    _ref.invalidate(conversationsProvider);
  }

  Future<void> closeConversation(String conversationId) async {
    final repo = _ref.read(chatRepositoryProvider);
    await repo.closeConversation(conversationId);
    _ref.invalidate(conversationsProvider);
  }
}

// ============================================================================
// ACTIVE CHAT STATE (for chat screen)
// ============================================================================

enum PendingStatus { sending, failed }

/// A message the shopper sent that the server has not confirmed yet. It is drawn
/// in the thread straight away (optimistic), then removed once the refreshed
/// thread contains the real one — or kept, marked failed, with a Retry.
class PendingMessage {
  final String localId;
  final String text;
  final PickedImage? image;
  final DateTime createdAt;
  final PendingStatus status;
  final String? error;

  const PendingMessage({
    required this.localId,
    required this.text,
    this.image,
    required this.createdAt,
    this.status = PendingStatus.sending,
    this.error,
  });

  PendingMessage copyWith({PendingStatus? status, String? error}) =>
      PendingMessage(
        localId: localId,
        text: text,
        image: image,
        createdAt: createdAt,
        status: status ?? this.status,
        error: error,
      );
}

class ActiveChatState {
  final String conversationId;
  final List<PendingMessage> pending;

  const ActiveChatState({
    required this.conversationId,
    this.pending = const [],
  });

  bool get isSending => pending.any((p) => p.status == PendingStatus.sending);

  ActiveChatState copyWith({List<PendingMessage>? pending}) => ActiveChatState(
        conversationId: conversationId,
        pending: pending ?? this.pending,
      );
}

final activeChatProvider = StateNotifierProvider.family
    .autoDispose<ActiveChatNotifier, ActiveChatState, String>(
  (ref, conversationId) => ActiveChatNotifier(ref, conversationId),
);

class ActiveChatNotifier extends StateNotifier<ActiveChatState> {
  final Ref _ref;
  int _seq = 0;

  ActiveChatNotifier(this._ref, String conversationId)
      : super(ActiveChatState(conversationId: conversationId)) {
    _ref.read(chatControllerProvider).markAsRead(conversationId);
  }

  /// Queue a message and send it. Returns immediately; the thread shows it as
  /// "sending" until the server confirms.
  void send(String text, {PickedImage? image}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty && image == null) return;
    final pending = PendingMessage(
      localId: 'local-${DateTime.now().microsecondsSinceEpoch}-${_seq++}',
      text: trimmed,
      image: image,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(pending: [...state.pending, pending]);
    _deliver(pending);
  }

  void retry(String localId) {
    final p = _find(localId);
    if (p == null || p.status == PendingStatus.sending) return;
    _replace(p.copyWith(status: PendingStatus.sending));
    _deliver(p);
  }

  void discard(String localId) {
    state = state.copyWith(
        pending: state.pending.where((p) => p.localId != localId).toList());
  }

  PendingMessage? _find(String localId) {
    for (final p in state.pending) {
      if (p.localId == localId) return p;
    }
    return null;
  }

  void _replace(PendingMessage next) {
    state = state.copyWith(
      pending: [
        for (final p in state.pending) p.localId == next.localId ? next : p,
      ],
    );
  }

  Future<void> _deliver(PendingMessage p) async {
    try {
      List<MessageAttachment>? attachments;
      final image = p.image;
      if (image != null) {
        // One image per message: upload first, then send with the hosted URL
        // (the picker already downscaled it, ≤1600px / q85).
        final url = await _ref
            .read(chatRepositoryProvider)
            .uploadChatImage(image.bytes, image.mimeType);
        attachments = [
          MessageAttachment(
            type: 'image',
            url: url,
            name: image.filename,
            size: image.sizeBytes,
            mimeType: image.mimeType,
          ),
        ];
      }
      await _ref
          .read(chatControllerProvider)
          .sendMessage(state.conversationId, p.text, attachments: attachments);
      if (!mounted) return;
      // Wait for the refreshed thread before dropping the placeholder, so the
      // message never blinks out between the two.
      try {
        await _ref.read(messagesProvider(state.conversationId).future);
      } catch (_) {}
      if (mounted) discard(p.localId);
    } catch (e) {
      if (!mounted) return;
      _replace(p.copyWith(status: PendingStatus.failed, error: friendlyChatError(e)));
    }
  }
}
