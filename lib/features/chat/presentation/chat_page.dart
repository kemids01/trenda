// lib/features/chat/presentation/chat_page.dart
// Customer ↔ shop conversation. The thread is drawn newest-at-bottom from the
// pure rules in utils/chat_timeline.dart; sends are optimistic (PendingMessage)
// and new messages arrive live over the socket, with a slow poll as fallback.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:intl/intl.dart';
import 'package:trenda_shared/services/websocket_service.dart';
import 'package:trenda_shared/trenda_shared.dart';
import '../providers/chat_alerts_provider.dart';
import '../providers/chat_provider.dart';
import '../utils/chat_errors.dart';
import 'package:trenda_shared/core/taps/taps.dart';

/// Poll only when the socket is down; a connected socket delivers instantly.
const Duration _kFallbackPoll = Duration(seconds: 20);

/// This app is always the customer side of a thread.
const String _kMyRole = 'customer';

/// Picked image waiting in the composer (one per message).
final _composerImageProvider =
    StateProvider.autoDispose.family<PickedImage?, String>((ref, _) => null);

class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatPage({super.key, required this.conversationId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  late final WebSocketNotifier _ws;
  late final StateController<String?> _openChat;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _ws = ref.read(webSocketProvider.notifier);
    _ws.addEventCallback(_onSocketEvent);
    _poll = Timer.periodic(_kFallbackPoll, (_) {
      if (!mounted) return;
      if (!ref.read(webSocketProvider).isConnected) _refresh();
    });
    // Messages in this thread are not announced while it is on screen.
    _openChat = ref.read(openChatConversationProvider.notifier);
    Future.microtask(() => _openChat.state = widget.conversationId);
  }

  @override
  void dispose() {
    final id = widget.conversationId;
    Future.microtask(() {
      if (_openChat.state == id) _openChat.state = null;
    });
    _ws.removeEventCallback(_onSocketEvent);
    _poll?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSocketEvent(String event, Map<String, dynamic> data) {
    if (!mounted || event != 'chat:message') return;
    if (data['conversationId']?.toString() != widget.conversationId) return;
    _refresh();
  }

  /// Re-reads the thread. The server zeroes our unread count on every read, so the
  /// badges are refreshed by the listener in build once that read lands.
  void _refresh() {
    ref.invalidate(messagesProvider(widget.conversationId));
  }

  Future<void> _pickImage() async {
    final picked =
        await ImagePickerService().pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      ref.read(_composerImageProvider(widget.conversationId).notifier).state =
          picked;
    }
  }

  void _send() {
    final imageCtl =
        ref.read(_composerImageProvider(widget.conversationId).notifier);
    final text = _messageController.text.trim();
    final image = imageCtl.state;
    if (text.isEmpty && image == null) return;

    ref
        .read(activeChatProvider(widget.conversationId).notifier)
        .send(text, image: image);
    imageCtl.state = null;
    _messageController.clear();
    _focusNode.requestFocus();
    _scrollToLatest();
  }

  void _useQuickReply(String text) {
    _messageController
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
    _focusNode.requestFocus();
  }

  Widget _productCardFor(MessageAttachment card) => ChatProductCard(
        name: card.name ?? 'Product',
        imageUrl: card.url,
        price: card.price,
        onTap: card.productId == null
            ? null
            : () => context.push('/product/${card.productId}'),
      );

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversation =
        ref.watch(conversationProvider(widget.conversationId)).valueOrNull;
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    // Each read of the thread zeroes our unread count on the server: refresh the
    // badges only AFTER it lands, or they re-read the old count.
    ref.listen(messagesProvider(widget.conversationId), (_, next) {
      if (next is AsyncData) {
        ref.invalidate(unreadMessagesCountProvider);
        ref.invalidate(conversationsProvider);
      }
    });
    final chatState = ref.watch(activeChatProvider(widget.conversationId));
    final shop = conversation?.participantWithRole('vendor');
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: _ShopTitle(shop: shop),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'shop' && shop?.storeVendorId != null) {
                context.push('/vendor/${shop!.storeVendorId}');
              } else if (value == 'report') {
                TapGuard.run('chat.showReportDialog', () async => _showReportDialog(context));
              }
            },
            itemBuilder: (context) => [
              if (shop?.storeVendorId != null)
                const PopupMenuItem(
                  value: 'shop',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.storefront_outlined),
                    title: Text('Visit shop'),
                  ),
                ),
              PopupMenuItem(
                value: 'report',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.flag_outlined, color: scheme.error),
                  title: const Text('Report'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (conversation?.productName != null)
            ChatProductCard(
              pinned: true,
              label: 'ASKING ABOUT',
              name: conversation!.productName!,
              imageUrl: conversation.productImage,
              price: conversation.productPrice,
              onTap: conversation.productId == null
                  ? null
                  : () => context.push('/product/${conversation.productId}'),
            ),
          Expanded(
            child: messagesAsync.when(
              skipLoadingOnRefresh: true,
              data: (result) {
                final timeline = buildChatTimeline(result.messages,
                    myRole: _kMyRole);
                // Pending sends are the newest items, so they lead the
                // reversed list (newest pending first).
                final pending = chatState.pending.reversed.toList();
                if (timeline.isEmpty && pending.isEmpty) {
                  return _EmptyThread(
                    shop: shop,
                    askingAboutProduct: conversation?.productName != null,
                    onQuickReply: _useQuickReply,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                    await ref
                        .read(messagesProvider(widget.conversationId).future);
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: pending.length + timeline.length,
                    itemBuilder: (context, index) {
                      if (index < pending.length) {
                        final p = pending[index];
                        return _PendingBubble(
                          pending: p,
                          onRetry: () => ref
                              .read(activeChatProvider(widget.conversationId)
                                  .notifier)
                              .retry(p.localId),
                          onDiscard: () => ref
                              .read(activeChatProvider(widget.conversationId)
                                  .notifier)
                              .discard(p.localId),
                        );
                      }
                      final item = timeline[index - pending.length];
                      return switch (item) {
                        ChatDayHeader(:final label) => _DayPill(label: label),
                        ChatMessageItem(:final message)
                            when message.productCard != null =>
                          _productCardFor(message.productCard!),
                        ChatMessageItem() => _MessageBubble(
                            item: item,
                            shop: shop,
                          ),
                      };
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ThreadError(
                message: friendlyChatError(e),
                onRetry: _refresh,
              ),
            ),
          ),
          _Composer(
            conversationId: widget.conversationId,
            controller: _messageController,
            focusNode: _focusNode,
            onPickImage: _pickImage,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  static const _reasonMap = {
    'Spam or scam': 'spam_scam',
    'Harassment or abuse': 'harassment_abuse',
    'Inappropriate content': 'inappropriate_content',
    'Fraud or fake': 'fraud_fake',
    'Other': 'other',
  };

  void _showReportDialog(BuildContext context) {
    final reasons = _reasonMap.keys.toList();
    final selectedReason = ValueNotifier<String?>(null);
    final detailsController = TextEditingController();
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => ValueListenableBuilder<String?>(
        valueListenable: selectedReason,
        builder: (ctx, selected, _) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.flag, color: scheme.error),
              const SizedBox(width: 8),
              const Text('Report shop'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Why are you reporting this shop?',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                ...reasons.map((r) => RadioListTile<String>(
                      title: Text(r, style: const TextStyle(fontSize: 14)),
                      value: r,
                      groupValue: selected,
                      onChanged: (v) => selectedReason.value = v,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Additional details (optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => TapGuard.run('chat.submitReport', () async {
                      Navigator.pop(ctx);
                      await _submitReport(selected, detailsController.text.trim());
                    }),
              style: FilledButton.styleFrom(backgroundColor: scheme.error),
              child: const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport(String reason, String details) async {
    final messenger = ScaffoldMessenger.of(context);
    final reportedUserId = ref
        .read(conversationProvider(widget.conversationId))
        .valueOrNull
        ?.participantWithRole('vendor')
        ?.userId;
    if (reportedUserId == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not identify the shop to report.')));
      return;
    }
    try {
      await ReportRepository().submitReport(
        reportedUserId: reportedUserId,
        reason: _reasonMap[reason] ?? 'other',
        details: details,
        conversationId: widget.conversationId,
      );
      messenger.showSnackBar(const SnackBar(
          content: Text('Report submitted. We will review it shortly.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyChatError(e))));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _ShopAvatar extends StatelessWidget {
  final ConversationParticipant? shop;
  final double radius;
  const _ShopAvatar({required this.shop, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photo = shop?.displayPhoto;
    final name = shop?.displayName ?? 'Shop';
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: photo != null ? NetworkImage(photo) : null,
      child: Text(
        name.isNotEmpty ? name.characters.first.toUpperCase() : 'S',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.8,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _ShopTitle extends StatelessWidget {
  final ConversationParticipant? shop;
  const _ShopTitle({required this.shop});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canVisit = shop?.storeVendorId != null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap:
          canVisit ? () => context.push('/vendor/${shop!.storeVendorId}') : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            _ShopAvatar(shop: shop),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shop?.displayName ?? 'Shop',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (canVisit)
                    Text(
                      'VIEW SHOP',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Thread
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyThread extends StatelessWidget {
  final ConversationParticipant? shop;
  final bool askingAboutProduct;
  final ValueChanged<String> onQuickReply;

  const _EmptyThread({
    required this.shop,
    required this.askingAboutProduct,
    required this.onQuickReply,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final replies = [
      if (askingAboutProduct) 'Hi! Is this still available?',
      'Do you deliver to my area?',
      'How soon can you ship?',
      'Can I pick it up at the store?',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        Center(child: _ShopAvatar(shop: shop, radius: 34)),
        const SizedBox(height: 14),
        Text(
          'Message ${shop?.displayName ?? 'the shop'}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Ask about stock, delivery or pickup. Replies show up here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in replies)
              ActionChip(
                label: Text(r),
                avatar: Icon(Icons.bolt, size: 16, color: scheme.primary),
                onPressed: () => onQuickReply(r),
              ),
          ],
        ),
      ],
    );
  }
}

class _ThreadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ThreadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 44, color: scheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  final String label;
  const _DayPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bubble corners: on the sender's side the bottom corner is always tight (the
/// tail on the last bubble, the join on the others), and the top corner is tight
/// wherever the bubble joins the one above — so a group reads as one block.
BorderRadius _bubbleRadius({required bool isMe, required bool first}) {
  const big = Radius.circular(18);
  const small = Radius.circular(5);
  final senderTop = first ? big : small;
  return BorderRadius.only(
    topLeft: isMe ? big : senderTop,
    bottomLeft: isMe ? big : small,
    topRight: isMe ? senderTop : big,
    bottomRight: isMe ? small : big,
  );
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageItem item;
  final ConversationParticipant? shop;

  const _MessageBubble({required this.item, required this.shop});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = item.message;
    final isMe = item.isMe;
    final fg = isMe ? scheme.onPrimary : scheme.onSurface;

    return Padding(
      padding: EdgeInsets.only(top: item.isFirstInGroup ? 8 : 2),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            SizedBox(
              width: 36,
              child: item.isLastInGroup
                  ? _ShopAvatar(shop: shop, radius: 14)
                  : null,
            ),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.74),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isMe
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius: _bubbleRadius(
                          isMe: isMe, first: item.isFirstInGroup),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final a in message.attachments)
                          if (a.type == 'image')
                            _ChatImage(url: a.url, fg: fg),
                        if (message.message.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                            child: SelectableText(
                              message.message,
                              style:
                                  TextStyle(color: fg, fontSize: 15, height: 1.3),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (item.isLastInGroup)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
                      child: Text(
                        DateFormat('h:mm a')
                            .formatPh(message.createdAt.toLocal()),
                        style: TextStyle(
                            fontSize: 10.5, color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatImage extends StatelessWidget {
  final String url;
  final Color fg;
  const _ChatImage({required this.url, required this.fg});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openImage(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          url,
          width: 220,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : SizedBox(
                  width: 220,
                  height: 160,
                  child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: fg.withValues(alpha: 0.7)),
                  ),
                ),
          errorBuilder: (_, __, ___) => SizedBox(
            width: 120,
            height: 90,
            child: Icon(Icons.broken_image_outlined, color: fg),
          ),
        ),
      ),
    );
  }

  static void _openImage(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: InteractiveViewer(
            child: Image.network(url,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image,
                    size: 80, color: Colors.white54)),
          ),
        ),
      ),
    ));
  }
}

class _PendingBubble extends StatelessWidget {
  final PendingMessage pending;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  const _PendingBubble({
    required this.pending,
    required this.onRetry,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = pending.status == PendingStatus.failed;
    final image = pending.image;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Opacity(
            opacity: failed ? 1 : 0.6,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.74),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: failed ? scheme.errorContainer : scheme.primary,
                  borderRadius: _bubbleRadius(isMe: true, first: true),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (image != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(image.bytes,
                            width: 220, fit: BoxFit.cover),
                      ),
                    if (pending.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                        child: Text(
                          pending.text,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.3,
                            color: failed
                                ? scheme.onErrorContainer
                                : scheme.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
            child: failed
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 14, color: scheme.error),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          pending.error ?? 'Not sent',
                          style: TextStyle(fontSize: 11, color: scheme.error),
                        ),
                      ),
                      TextButton(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                        child: const Text('Retry'),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        onPressed: onDiscard,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule,
                          size: 12, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        image != null ? 'Uploading…' : 'Sending…',
                        style: TextStyle(
                            fontSize: 10.5, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Composer
// ─────────────────────────────────────────────────────────────────────────────

class _Composer extends ConsumerWidget {
  final String conversationId;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onPickImage;
  final VoidCallback onSend;

  const _Composer({
    required this.conversationId,
    required this.controller,
    required this.focusNode,
    required this.onPickImage,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final image = ref.watch(_composerImageProvider(conversationId));

    return Material(
      color: scheme.surface,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (image != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(image.bytes,
                              height: 84, width: 84, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => ref
                                .read(_composerImageProvider(conversationId)
                                    .notifier)
                                .state = null,
                            child: const CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Add a photo',
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    color: image != null ? scheme.primary : null,
                    onPressed: onPickImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Message the shop…',
                        counterText: '',
                        isDense: true,
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final canSend =
                          value.text.trim().isNotEmpty || image != null;
                      return IconButton.filled(
                        tooltip: 'Send',
                        onPressed: canSend ? onSend : null,
                        icon: const Icon(Icons.send_rounded),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
