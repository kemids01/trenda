// lib/features/chat/presentation/conversations_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:trenda_shared/trenda_shared.dart';
import '../providers/chat_provider.dart';
import '../../core/providers/websocket_provider.dart';

class ConversationsPage extends ConsumerWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    // Setup ban notification listener (idempotent)
    setupBanNotificationListener(ref);

    // Listen for ban notifications and show popup dialog
    ref.listen<BanNotification?>(banNotificationProvider, (prev, next) {
      if (next != null && context.mounted) {
        showBanNotificationDialog(
          context,
          isBanned: next.isBanned,
          scope: next.scope,
          banType: next.banType,
          reason: next.reason,
          expiresAt: next.expiresAt,
        );
        // Clear after showing
        Future.microtask(() =>
            ref.read(banNotificationProvider.notifier).state = null);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(conversationsProvider),
          ),
        ],
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text('Could not load conversations',
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => ref.invalidate(conversationsProvider),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No conversations yet',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text(
                      'Start chatting by visiting a store\nand tapping the Chat button.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(conversationsProvider);
              await ref.read(conversationsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conversations.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final conv = conversations[index];
                return _ConversationTile(
                  conversation: conv,
                  onTap: () =>
                      context.push('/chat/${conv.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // This app is the customer; the other party is the vendor. Derive by role
    // (participant ids are Mongo _ids, not the Firebase uid the app holds).
    final scheme = Theme.of(context).colorScheme;
    final other = conversation.participantWithRole('vendor');
    final unread = conversation.unreadForRole('customer');
    final lastMsg = conversation.lastMessage;
    final name = other?.displayName ?? 'Shop';
    final photo = other?.displayPhoto;
    final preview = lastMsg?.message.isNotEmpty == true
        ? lastMsg!.message
        : (conversation.productName != null
            ? 'About: ${conversation.productName}'
            : 'No messages yet');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: scheme.primaryContainer,
        foregroundImage: photo != null ? NetworkImage(photo) : null,
        child: Text(
          name.isNotEmpty ? name.characters.first.toUpperCase() : 'S',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: scheme.onPrimaryContainer,
              fontSize: 18),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w500,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (lastMsg != null)
            Text(
              _formatTime(lastMsg.createdAt.toLocal()),
              style: TextStyle(
                fontSize: 12,
                color: unread > 0 ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              preview,
              style: TextStyle(
                fontSize: 13,
                color: unread > 0 ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (unread > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }

  String _formatTime(DateTime time) {
    final today = TrendaTimezone.today();
    final local = TrendaTimezone.toLocal(time);
    final messageDay = DateTime(local.year, local.month, local.day);

    if (messageDay == today) {
      return DateFormat('h:mm a').formatPh(time);
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').formatPh(time);
    }
  }
}
